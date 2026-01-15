const { Resend } = require('resend');

let resend = null;

function getResend() {
    if (!resend) {
        resend = new Resend(process.env.RESEND_API_KEY);
    }
    return resend;
}

/**
 * Sends license key email to customer
 * @param {string} email - Customer email
 * @param {string} licenseKey - Generated license key
 * @param {string} customerName - Customer name (optional)
 */
async function sendLicenseEmail(email, licenseKey, customerName = 'Customer') {
    const client = getResend();

    const fromEmail = process.env.EMAIL_FROM || 'DashPane <onboarding@resend.dev>';

    const htmlContent = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { text-align: center; padding: 20px 0; }
        .logo { font-size: 28px; font-weight: bold; color: #007AFF; }
        .license-box { background: #f5f5f7; border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0; }
        .license-key { font-family: 'SF Mono', Monaco, monospace; font-size: 24px; font-weight: 600; color: #1d1d1f; letter-spacing: 2px; }
        .instructions { background: #fff; border: 1px solid #e5e5e5; border-radius: 8px; padding: 16px; margin: 20px 0; }
        .instructions h3 { margin-top: 0; color: #1d1d1f; }
        .instructions ol { margin: 0; padding-left: 20px; }
        .instructions li { margin: 8px 0; }
        .footer { text-align: center; color: #86868b; font-size: 12px; margin-top: 32px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">DashPane</div>
        </div>

        <p>Hi ${customerName},</p>

        <p>Thank you for purchasing DashPane! Here is your license key:</p>

        <div class="license-box">
            <div class="license-key">${licenseKey}</div>
        </div>

        <div class="instructions">
            <h3>How to activate:</h3>
            <ol>
                <li>Open DashPane on your Mac</li>
                <li>Go to Settings > License</li>
                <li>Enter your license key</li>
                <li>Click "Activate"</li>
            </ol>
        </div>

        <p>Your license allows activation on up to ${process.env.MAX_ACTIVATIONS_PER_LICENSE || 2} Mac computers.</p>

        <p>If you have any questions, please reply to this email.</p>

        <p>Best regards,<br>The DashPane Team</p>

        <div class="footer">
            <p>This email was sent to ${email} because you purchased DashPane.</p>
        </div>
    </div>
</body>
</html>
    `;

    const textContent = `
Hi ${customerName},

Thank you for purchasing DashPane! Here is your license key:

${licenseKey}

How to activate:
1. Open DashPane on your Mac
2. Go to Settings > License
3. Enter your license key
4. Click "Activate"

Your license allows activation on up to ${process.env.MAX_ACTIVATIONS_PER_LICENSE || 2} Mac computers.

If you have any questions, please reply to this email.

Best regards,
The DashPane Team
    `;

    try {
        const { data, error } = await client.emails.send({
            from: fromEmail,
            to: [email],
            subject: 'Your DashPane License Key',
            html: htmlContent,
            text: textContent
        });

        if (error) {
            console.error('Resend error:', error);
            throw new Error(error.message);
        }

        console.log(`License email sent to ${email}, id: ${data.id}`);
        return true;
    } catch (error) {
        console.error('Failed to send license email:', error);
        throw error;
    }
}

module.exports = {
    sendLicenseEmail
};
