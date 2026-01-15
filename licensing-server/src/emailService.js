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
    const maxActivations = process.env.MAX_ACTIVATIONS_PER_LICENSE || 1;
    const macText = maxActivations == 1 ? '1 Mac' : `${macText}`;

    const htmlContent = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Your DashPane License Key</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; background-color: #f5f5f7;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
        <tr>
            <td align="center" style="padding: 40px 20px;">
                <table role="presentation" width="600" cellspacing="0" cellpadding="0" border="0" style="max-width: 600px; width: 100%;">

                    <!-- Logo Header -->
                    <tr>
                        <td align="center" style="padding-bottom: 32px;">
                            <table role="presentation" cellspacing="0" cellpadding="0" border="0">
                                <tr>
                                    <td style="background: linear-gradient(135deg, #1d1d2e 0%, #2d2d3e 100%); border-radius: 16px; padding: 16px 24px;">
                                        <table role="presentation" cellspacing="0" cellpadding="0" border="0">
                                            <tr>
                                                <td>
                                                    <!-- SVG Icon representation of app logo -->
                                                    <svg width="32" height="32" viewBox="0 0 32 32" style="vertical-align: middle;">
                                                        <rect x="4" y="12" width="12" height="6" rx="3" fill="#00D4FF"/>
                                                        <rect x="18" y="6" width="10" height="20" rx="3" fill="url(#panelGradient)"/>
                                                        <defs>
                                                            <linearGradient id="panelGradient" x1="18" y1="6" x2="28" y2="26" gradientUnits="userSpaceOnUse">
                                                                <stop offset="0%" stop-color="#00D4FF"/>
                                                                <stop offset="100%" stop-color="#007AFF"/>
                                                            </linearGradient>
                                                        </defs>
                                                    </svg>
                                                </td>
                                                <td style="padding-left: 12px;">
                                                    <span style="font-size: 24px; font-weight: 700; color: #ffffff; letter-spacing: -0.5px;">DashPane</span>
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                    <!-- Main Content Card -->
                    <tr>
                        <td style="background: #ffffff; border-radius: 16px; box-shadow: 0 4px 24px rgba(0, 0, 0, 0.08);">

                            <!-- Welcome Section -->
                            <tr>
                                <td style="padding: 40px 40px 24px 40px;">
                                    <h1 style="margin: 0 0 8px 0; font-size: 28px; font-weight: 700; color: #1d1d1f;">Welcome aboard! 🎉</h1>
                                    <p style="margin: 0; font-size: 16px; color: #6e6e73;">Hi ${customerName}, thank you for purchasing DashPane.</p>
                                </td>
                            </tr>

                            <!-- License Key Box -->
                            <tr>
                                <td style="padding: 0 40px;">
                                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background: linear-gradient(135deg, #1d1d2e 0%, #2d2d3e 100%); border-radius: 12px;">
                                        <tr>
                                            <td style="padding: 24px; text-align: center;">
                                                <p style="margin: 0 0 8px 0; font-size: 12px; font-weight: 600; color: #8e8e93; text-transform: uppercase; letter-spacing: 1px;">Your License Key</p>
                                                <p style="margin: 0; font-family: 'SF Mono', Monaco, 'Courier New', monospace; font-size: 22px; font-weight: 600; color: #00D4FF; letter-spacing: 2px;">${licenseKey}</p>
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                            </tr>

                            <!-- Quick Start Guide -->
                            <tr>
                                <td style="padding: 32px 40px 24px 40px;">
                                    <h2 style="margin: 0 0 20px 0; font-size: 18px; font-weight: 700; color: #1d1d1f;">Quick Start Guide</h2>

                                    <!-- Step 1 -->
                                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin-bottom: 16px;">
                                        <tr>
                                            <td width="40" valign="top">
                                                <div style="width: 28px; height: 28px; background: #007AFF; border-radius: 50%; text-align: center; line-height: 28px; font-size: 14px; font-weight: 600; color: #ffffff;">1</div>
                                            </td>
                                            <td style="padding-left: 12px;">
                                                <p style="margin: 0; font-size: 15px; font-weight: 600; color: #1d1d1f;">Open DashPane</p>
                                                <p style="margin: 4px 0 0 0; font-size: 14px; color: #6e6e73;">Launch the app from your Applications folder or menu bar</p>
                                            </td>
                                        </tr>
                                    </table>

                                    <!-- Step 2 -->
                                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin-bottom: 16px;">
                                        <tr>
                                            <td width="40" valign="top">
                                                <div style="width: 28px; height: 28px; background: #007AFF; border-radius: 50%; text-align: center; line-height: 28px; font-size: 14px; font-weight: 600; color: #ffffff;">2</div>
                                            </td>
                                            <td style="padding-left: 12px;">
                                                <p style="margin: 0; font-size: 15px; font-weight: 600; color: #1d1d1f;">Go to Settings → License</p>
                                                <p style="margin: 4px 0 0 0; font-size: 14px; color: #6e6e73;">Click the gear icon or use <span style="font-family: 'SF Mono', Monaco, monospace; font-size: 13px; background: #f5f5f7; padding: 2px 6px; border-radius: 4px;">⌘,</span></p>
                                            </td>
                                        </tr>
                                    </table>

                                    <!-- Step 3 -->
                                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin-bottom: 16px;">
                                        <tr>
                                            <td width="40" valign="top">
                                                <div style="width: 28px; height: 28px; background: #007AFF; border-radius: 50%; text-align: center; line-height: 28px; font-size: 14px; font-weight: 600; color: #ffffff;">3</div>
                                            </td>
                                            <td style="padding-left: 12px;">
                                                <p style="margin: 0; font-size: 15px; font-weight: 600; color: #1d1d1f;">Enter your license key</p>
                                                <p style="margin: 4px 0 0 0; font-size: 14px; color: #6e6e73;">Paste or type the key exactly as shown above</p>
                                            </td>
                                        </tr>
                                    </table>

                                    <!-- Step 4 -->
                                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                                        <tr>
                                            <td width="40" valign="top">
                                                <div style="width: 28px; height: 28px; background: #34C759; border-radius: 50%; text-align: center; line-height: 28px; font-size: 14px; font-weight: 600; color: #ffffff;">✓</div>
                                            </td>
                                            <td style="padding-left: 12px;">
                                                <p style="margin: 0; font-size: 15px; font-weight: 600; color: #1d1d1f;">Click "Activate"</p>
                                                <p style="margin: 4px 0 0 0; font-size: 14px; color: #6e6e73;">You're all set! DashPane is now fully unlocked</p>
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                            </tr>

                            <!-- Info Box -->
                            <tr>
                                <td style="padding: 0 40px 32px 40px;">
                                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background: #f5f5f7; border-radius: 12px;">
                                        <tr>
                                            <td style="padding: 20px;">
                                                <table role="presentation" cellspacing="0" cellpadding="0" border="0">
                                                    <tr>
                                                        <td style="padding-right: 24px; border-right: 1px solid #e5e5e5;">
                                                            <p style="margin: 0; font-size: 12px; color: #6e6e73; text-transform: uppercase; letter-spacing: 0.5px;">Activations</p>
                                                            <p style="margin: 4px 0 0 0; font-size: 20px; font-weight: 700; color: #1d1d1f;">${macText}</p>
                                                        </td>
                                                        <td style="padding-left: 24px;">
                                                            <p style="margin: 0; font-size: 12px; color: #6e6e73; text-transform: uppercase; letter-spacing: 0.5px;">Support</p>
                                                            <p style="margin: 4px 0 0 0; font-size: 20px; font-weight: 700; color: #1d1d1f;">Lifetime</p>
                                                        </td>
                                                    </tr>
                                                </table>
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                            </tr>

                            <!-- Tips Section -->
                            <tr>
                                <td style="padding: 0 40px 40px 40px; border-top: 1px solid #e5e5e5;">
                                    <h3 style="margin: 24px 0 16px 0; font-size: 16px; font-weight: 600; color: #1d1d1f;">💡 Pro Tips</h3>
                                    <ul style="margin: 0; padding-left: 20px; color: #6e6e73; font-size: 14px;">
                                        <li style="margin-bottom: 8px;">Use <span style="font-family: 'SF Mono', Monaco, monospace; font-size: 13px; background: #f5f5f7; padding: 2px 6px; border-radius: 4px;">⌥Tab</span> to quickly switch between windows</li>
                                        <li style="margin-bottom: 8px;">Keep this email safe - you'll need the license key if you reinstall</li>
                                        <li>Deactivate your license before selling or wiping your Mac</li>
                                    </ul>
                                </td>
                            </tr>

                        </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                        <td style="padding: 32px 40px; text-align: center;">
                            <p style="margin: 0 0 8px 0; font-size: 14px; color: #6e6e73;">Need help? Just reply to this email.</p>
                            <p style="margin: 0; font-size: 12px; color: #8e8e93;">
                                <a href="https://dashpane.com" style="color: #007AFF; text-decoration: none;">dashpane.com</a>
                            </p>
                            <p style="margin: 16px 0 0 0; font-size: 11px; color: #aeaeb2;">
                                This email was sent to ${email} because you purchased DashPane.
                            </p>
                        </td>
                    </tr>

                </table>
            </td>
        </tr>
    </table>
</body>
</html>
    `;

    const textContent = `
═══════════════════════════════════════════════
              DASHPANE LICENSE
═══════════════════════════════════════════════

Welcome aboard! 🎉

Hi ${customerName}, thank you for purchasing DashPane.

YOUR LICENSE KEY
────────────────
${licenseKey}

Keep this key safe - you'll need it if you reinstall.

═══════════════════════════════════════════════
              QUICK START GUIDE
═══════════════════════════════════════════════

1. OPEN DASHPANE
   Launch the app from your Applications folder or menu bar

2. GO TO SETTINGS → LICENSE
   Click the gear icon or use ⌘,

3. ENTER YOUR LICENSE KEY
   Paste or type the key exactly as shown above

4. CLICK "ACTIVATE"
   You're all set! DashPane is now fully unlocked

═══════════════════════════════════════════════
              LICENSE DETAILS
═══════════════════════════════════════════════

• Activations: ${macText}
• Support: Lifetime updates included

═══════════════════════════════════════════════
              PRO TIPS
═══════════════════════════════════════════════

• Use ⌥Tab to quickly switch between windows
• Keep this email safe for future reference
• Deactivate your license before selling your Mac

───────────────────────────────────────────────

Need help? Just reply to this email.
Visit us at dashpane.com

This email was sent to ${email} because you purchased DashPane.
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
