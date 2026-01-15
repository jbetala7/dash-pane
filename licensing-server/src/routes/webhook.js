const express = require('express');
const crypto = require('crypto');
const Razorpay = require('razorpay');
const { prepare } = require('../database');
const { generateLicenseKey } = require('../licenseGenerator');
const { sendLicenseEmail } = require('../emailService');

const router = express.Router();

// Initialize Razorpay instance
const razorpay = new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID,
    key_secret: process.env.RAZORPAY_KEY_SECRET
});

/**
 * Verify Razorpay webhook signature
 */
function verifyRazorpaySignature(body, signature) {
    const expectedSignature = crypto
        .createHmac('sha256', process.env.RAZORPAY_WEBHOOK_SECRET)
        .update(JSON.stringify(body))
        .digest('hex');

    return crypto.timingSafeEqual(
        Buffer.from(signature),
        Buffer.from(expectedSignature)
    );
}

/**
 * POST /webhook/razorpay
 * Handles Razorpay payment webhooks
 */
router.post('/razorpay', express.json(), async (req, res) => {
    try {
        const signature = req.headers['x-razorpay-signature'];

        // Verify webhook signature in production
        if (process.env.NODE_ENV === 'production') {
            if (!signature || !verifyRazorpaySignature(req.body, signature)) {
                console.error('Invalid Razorpay webhook signature');
                return res.status(401).json({ error: 'Invalid signature' });
            }
        }

        const event = req.body.event;
        console.log(`Received Razorpay event: ${event}`);

        // Handle payment.authorized - capture immediately
        if (event === 'payment.authorized') {
            const payment = req.body.payload.payment.entity;
            const paymentId = payment.id;
            const amount = payment.amount;

            console.log(`Payment authorized: ${paymentId}, capturing immediately...`);

            try {
                // Capture the payment immediately via Razorpay API
                await razorpay.payments.capture(paymentId, amount, payment.currency || 'INR');
                console.log(`Payment ${paymentId} captured successfully`);

                // The payment.captured webhook will be triggered automatically
                // and will handle license creation
                return res.status(200).json({ message: 'Payment captured' });
            } catch (captureError) {
                console.error(`Failed to capture payment ${paymentId}:`, captureError);
                // Don't fail - auto-capture will eventually capture it
                return res.status(200).json({ message: 'Capture attempted' });
            }
        }

        if (event === 'payment.captured') {
            const payment = req.body.payload.payment.entity;

            const email = payment.email;
            const phone = payment.contact;
            const amount = payment.amount;
            const currency = payment.currency || 'INR';
            const paymentId = payment.id;
            const orderId = payment.order_id;

            console.log(`Payment captured: ${paymentId} from ${email}`);

            // Check if license already exists for this payment
            const existingLicense = prepare(
                'SELECT * FROM licenses WHERE razorpay_payment_id = ?'
            ).get(paymentId);

            if (existingLicense) {
                console.log(`License already exists for payment ${paymentId}`);
                return res.status(200).json({ message: 'Already processed' });
            }

            // Generate unique license key
            let licenseKey;
            let attempts = 0;
            const maxAttempts = 10;

            do {
                licenseKey = generateLicenseKey(process.env.LICENSE_PREFIX || 'DASH');
                const existing = prepare('SELECT id FROM licenses WHERE license_key = ?').get(licenseKey);
                if (!existing) break;
                attempts++;
            } while (attempts < maxAttempts);

            if (attempts >= maxAttempts) {
                console.error('Failed to generate unique license key');
                return res.status(500).json({ error: 'Failed to generate license' });
            }

            // Save license to database
            const result = prepare(`
                INSERT INTO licenses (license_key, email, phone, razorpay_payment_id, razorpay_order_id, amount, currency)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            `).run(licenseKey, email, phone, paymentId, orderId, amount, currency);

            console.log(`License created: ${licenseKey} for ${email}`);

            // Send license email
            try {
                await sendLicenseEmail(email, licenseKey);
            } catch (emailError) {
                console.error('Failed to send license email:', emailError);
                // Don't fail the webhook, license is still created
            }

            return res.status(200).json({
                message: 'License created',
                license_key: licenseKey
            });
        }

        // Handle other events if needed
        res.status(200).json({ message: 'Event received' });

    } catch (error) {
        console.error('Webhook error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /webhook/test
 * Test endpoint to manually create a license (development only)
 */
router.post('/test', express.json(), async (req, res) => {
    if (process.env.NODE_ENV === 'production') {
        return res.status(403).json({ error: 'Not available in production' });
    }

    try {
        const { email, phone } = req.body;

        if (!email) {
            return res.status(400).json({ error: 'Email is required' });
        }

        const licenseKey = generateLicenseKey(process.env.LICENSE_PREFIX || 'DASH');

        prepare(`
            INSERT INTO licenses (license_key, email, phone, razorpay_payment_id, amount, currency)
            VALUES (?, ?, ?, ?, ?, ?)
        `).run(licenseKey, email, phone || null, `test_${Date.now()}`, 0, 'INR');

        console.log(`Test license created: ${licenseKey} for ${email}`);

        res.status(200).json({
            message: 'Test license created',
            license_key: licenseKey,
            email: email
        });

    } catch (error) {
        console.error('Test webhook error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
