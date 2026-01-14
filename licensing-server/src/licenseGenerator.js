const crypto = require('crypto');

const LICENSE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excludes 0, O, 1, I for clarity

/**
 * Generates a license key in format: PREFIX-XXXX-XXXX-XXXX
 * @param {string} prefix - The prefix for the license key (default: DASH)
 * @returns {string} Generated license key
 */
function generateLicenseKey(prefix = 'DASH') {
    const segments = [];

    for (let i = 0; i < 3; i++) {
        let segment = '';
        for (let j = 0; j < 4; j++) {
            const randomIndex = crypto.randomInt(LICENSE_CHARS.length);
            segment += LICENSE_CHARS[randomIndex];
        }
        segments.push(segment);
    }

    return `${prefix}-${segments.join('-')}`;
}

/**
 * Validates license key format
 * @param {string} key - License key to validate
 * @returns {boolean} Whether the format is valid
 */
function isValidLicenseFormat(key) {
    const pattern = /^[A-Z]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/;
    return pattern.test(key);
}

module.exports = {
    generateLicenseKey,
    isValidLicenseFormat
};
