const express = require('express');
const crypto = require('crypto');
const { prepare } = require('../database');
const { isValidLicenseFormat } = require('../licenseGenerator');

const router = express.Router();

/**
 * Hash hardware ID for privacy
 */
function hashHardwareId(hardwareId) {
    return crypto.createHash('sha256').update(hardwareId).digest('hex');
}

/**
 * POST /api/license/activate
 * Activates a license on a specific machine
 */
router.post('/activate', express.json(), (req, res) => {
    try {
        const { license_key, hardware_id, machine_name } = req.body;

        // Validate input
        if (!license_key || !hardware_id) {
            return res.status(400).json({
                success: false,
                error: 'License key and hardware ID are required'
            });
        }

        if (!isValidLicenseFormat(license_key)) {
            return res.status(400).json({
                success: false,
                error: 'Invalid license key format'
            });
        }

        // Find the license
        const license = prepare(
            'SELECT * FROM licenses WHERE license_key = ? AND is_active = 1'
        ).get(license_key);

        if (!license) {
            return res.status(404).json({
                success: false,
                error: 'License not found or inactive'
            });
        }

        // Hash the hardware ID for storage
        const hashedHardwareId = hashHardwareId(hardware_id);

        // Check existing activations
        const existingActivation = prepare(
            'SELECT * FROM activations WHERE license_id = ? AND hardware_id = ?'
        ).get(license.id, hashedHardwareId);

        if (existingActivation) {
            // Already activated on this machine
            if (existingActivation.is_active) {
                // Update last validated timestamp
                prepare(
                    'UPDATE activations SET last_validated_at = CURRENT_TIMESTAMP WHERE id = ?'
                ).run(existingActivation.id);

                return res.status(200).json({
                    success: true,
                    message: 'License already activated on this machine',
                    activation_id: existingActivation.id
                });
            } else {
                // Reactivate
                prepare(
                    'UPDATE activations SET is_active = 1, last_validated_at = CURRENT_TIMESTAMP WHERE id = ?'
                ).run(existingActivation.id);

                return res.status(200).json({
                    success: true,
                    message: 'License reactivated on this machine',
                    activation_id: existingActivation.id
                });
            }
        }

        // Check activation limit
        const maxActivations = parseInt(process.env.MAX_ACTIVATIONS_PER_LICENSE) || 2;
        const activeCount = prepare(
            'SELECT COUNT(*) as count FROM activations WHERE license_id = ? AND is_active = 1'
        ).get(license.id);

        if (activeCount && activeCount.count >= maxActivations) {
            return res.status(403).json({
                success: false,
                error: `License already activated on ${maxActivations} machines. Please deactivate one first.`,
                max_activations: maxActivations,
                current_activations: activeCount.count
            });
        }

        // Create new activation
        const result = prepare(`
            INSERT INTO activations (license_id, hardware_id, machine_name)
            VALUES (?, ?, ?)
        `).run(license.id, hashedHardwareId, machine_name || 'Unknown Mac');

        console.log(`License ${license_key} activated on machine ${machine_name || 'Unknown'}`);

        res.status(200).json({
            success: true,
            message: 'License activated successfully',
            activation_id: result.lastInsertRowid,
            activations_used: (activeCount?.count || 0) + 1,
            max_activations: maxActivations
        });

    } catch (error) {
        console.error('Activation error:', error);
        res.status(500).json({
            success: false,
            error: 'Internal server error'
        });
    }
});

/**
 * POST /api/license/validate
 * Validates if a license is active on a specific machine
 */
router.post('/validate', express.json(), (req, res) => {
    try {
        const { license_key, hardware_id } = req.body;

        // Validate input
        if (!license_key || !hardware_id) {
            return res.status(400).json({
                valid: false,
                error: 'License key and hardware ID are required'
            });
        }

        if (!isValidLicenseFormat(license_key)) {
            return res.status(400).json({
                valid: false,
                error: 'Invalid license key format'
            });
        }

        // Find the license
        const license = prepare(
            'SELECT * FROM licenses WHERE license_key = ? AND is_active = 1'
        ).get(license_key);

        if (!license) {
            return res.status(200).json({
                valid: false,
                error: 'License not found or inactive'
            });
        }

        // Hash the hardware ID
        const hashedHardwareId = hashHardwareId(hardware_id);

        // Check activation
        const activation = prepare(
            'SELECT * FROM activations WHERE license_id = ? AND hardware_id = ? AND is_active = 1'
        ).get(license.id, hashedHardwareId);

        if (!activation) {
            return res.status(200).json({
                valid: false,
                error: 'License not activated on this machine'
            });
        }

        // Update last validated timestamp
        prepare(
            'UPDATE activations SET last_validated_at = CURRENT_TIMESTAMP WHERE id = ?'
        ).run(activation.id);

        res.status(200).json({
            valid: true,
            license_key: license_key,
            email: license.email,
            activated_at: activation.activated_at
        });

    } catch (error) {
        console.error('Validation error:', error);
        res.status(500).json({
            valid: false,
            error: 'Internal server error'
        });
    }
});

/**
 * POST /api/license/deactivate
 * Deactivates a license on a specific machine
 */
router.post('/deactivate', express.json(), (req, res) => {
    try {
        const { license_key, hardware_id } = req.body;

        if (!license_key || !hardware_id) {
            return res.status(400).json({
                success: false,
                error: 'License key and hardware ID are required'
            });
        }

        const license = prepare(
            'SELECT * FROM licenses WHERE license_key = ?'
        ).get(license_key);

        if (!license) {
            return res.status(404).json({
                success: false,
                error: 'License not found'
            });
        }

        const hashedHardwareId = hashHardwareId(hardware_id);

        const result = prepare(
            'UPDATE activations SET is_active = 0 WHERE license_id = ? AND hardware_id = ?'
        ).run(license.id, hashedHardwareId);

        if (result.changes === 0) {
            return res.status(404).json({
                success: false,
                error: 'No activation found for this machine'
            });
        }

        console.log(`License ${license_key} deactivated`);

        res.status(200).json({
            success: true,
            message: 'License deactivated successfully'
        });

    } catch (error) {
        console.error('Deactivation error:', error);
        res.status(500).json({
            success: false,
            error: 'Internal server error'
        });
    }
});

/**
 * GET /api/license/info/:key
 * Get license information (for admin/support)
 */
router.get('/info/:key', (req, res) => {
    try {
        const license = prepare(
            'SELECT id, license_key, email, created_at, is_active FROM licenses WHERE license_key = ?'
        ).get(req.params.key);

        if (!license) {
            return res.status(404).json({ error: 'License not found' });
        }

        const activations = prepare(
            'SELECT machine_name, activated_at, last_validated_at, is_active FROM activations WHERE license_id = ?'
        ).all(license.id);

        res.status(200).json({
            license_key: license.license_key,
            email: license.email,
            created_at: license.created_at,
            is_active: license.is_active === 1,
            activations: activations.map(a => ({
                machine_name: a.machine_name,
                activated_at: a.activated_at,
                last_validated_at: a.last_validated_at,
                is_active: a.is_active === 1
            }))
        });

    } catch (error) {
        console.error('Info error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
