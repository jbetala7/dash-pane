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
    const macText = maxActivations == 1 ? '1 Mac' : `${maxActivations} Macs`;

    const htmlContent = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Your DashPane License Key</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; background: linear-gradient(180deg, #0a0a0f 0%, #12121a 100%); min-height: 100vh;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
        <tr>
            <td align="center" style="padding: 40px 20px;">
                <table role="presentation" width="600" cellspacing="0" cellpadding="0" border="0" style="max-width: 600px; width: 100%;">

                    <!-- Hero Header with Metallic Glass Effect -->
                    <tr>
                        <td style="background: linear-gradient(135deg, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0.05) 100%); backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); border: 1px solid rgba(255,255,255,0.18); border-radius: 24px 24px 0 0; padding: 48px 40px 36px 40px; text-align: center;">
                            <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center">
                                <tr>
                                    <td>
                                        <!-- Logo Icon with Metallic Effect -->
                                        <div style="display: inline-block; width: 64px; height: 64px; background: linear-gradient(135deg, #00D4FF 0%, #0066FF 50%, #00D4FF 100%); border-radius: 16px; margin-bottom: 20px; text-align: center; line-height: 64px; box-shadow: 0 8px 32px rgba(0, 212, 255, 0.4), inset 0 1px 0 rgba(255,255,255,0.3);">
                                            <span style="font-size: 32px; color: #ffffff; font-weight: 700; text-shadow: 0 2px 4px rgba(0,0,0,0.3);">D</span>
                                        </div>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="text-align: center;">
                                        <h1 style="margin: 0 0 8px 0; font-size: 36px; font-weight: 700; color: #ffffff; letter-spacing: -0.5px; text-shadow: 0 2px 8px rgba(0,0,0,0.3);">DashPane</h1>
                                        <p style="margin: 0; font-size: 16px; color: rgba(255,255,255,0.6); font-weight: 500;">Window Management for Mac</p>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                    <!-- Main Content Card with Glass Effect -->
                    <tr>
                        <td style="background: linear-gradient(180deg, rgba(255,255,255,0.08) 0%, rgba(255,255,255,0.04) 100%); border: 1px solid rgba(255,255,255,0.1); border-top: none; border-radius: 0 0 24px 24px; box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);">

                            <!-- Welcome Section -->
                            <tr>
                                <td style="padding: 40px 40px 28px 40px; text-align: center;">
                                    <div style="display: inline-block; background: linear-gradient(135deg, rgba(52, 199, 89, 0.2) 0%, rgba(52, 199, 89, 0.1) 100%); border: 1px solid rgba(52, 199, 89, 0.3); border-radius: 20px; padding: 6px 16px; margin-bottom: 16px;">
                                        <p style="margin: 0; font-size: 12px; font-weight: 600; color: #34C759; text-transform: uppercase; letter-spacing: 1.5px;">Purchase Confirmed</p>
                                    </div>
                                    <h2 style="margin: 0 0 12px 0; font-size: 28px; font-weight: 700; color: #ffffff;">Welcome aboard, ${customerName}!</h2>
                                    <p style="margin: 0; font-size: 16px; color: rgba(255,255,255,0.7);">Thank you for purchasing DashPane. Your license key is ready.</p>
                                </td>
                            </tr>

                            <!-- License Key Box with Metallic Glass -->
                            <tr>
                                <td style="padding: 0 40px;">
                                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background: linear-gradient(135deg, rgba(0, 212, 255, 0.15) 0%, rgba(0, 102, 255, 0.1) 100%); border-radius: 16px; border: 1px solid rgba(0, 212, 255, 0.3); box-shadow: 0 4px 24px rgba(0, 212, 255, 0.2), inset 0 1px 0 rgba(255,255,255,0.1);">
                                        <tr>
                                            <td style="padding: 32px; text-align: center;">
                                                <p style="margin: 0 0 14px 0; font-size: 11px; font-weight: 600; color: rgba(255,255,255,0.5); text-transform: uppercase; letter-spacing: 2px;">Your License Key</p>
                                                <p style="margin: 0 0 14px 0; font-family: 'SF Mono', Monaco, 'Courier New', monospace; font-size: 26px; font-weight: 700; color: #00D4FF; letter-spacing: 4px; text-shadow: 0 0 20px rgba(0, 212, 255, 0.5);">${licenseKey}</p>
                                                <p style="margin: 0; font-size: 12px; color: rgba(255,255,255,0.5);">Save this key in a safe place</p>
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                            </tr>

                            <!-- What's Included Section -->
                            <tr>
                                <td style="padding: 36px 40px 28px 40px;">
                                    <h3 style="margin: 0 0 24px 0; font-size: 18px; font-weight: 600; color: #ffffff; text-align: center;">What's Included</h3>
                                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                                        <tr>
                                            <td width="33%" style="text-align: center; padding: 0 6px;">
                                                <div style="background: linear-gradient(180deg, rgba(255,255,255,0.08) 0%, rgba(255,255,255,0.04) 100%); border: 1px solid rgba(255,255,255,0.1); border-radius: 16px; padding: 24px 12px;">
                                                    <div style="font-size: 28px; margin-bottom: 10px;">💻</div>
                                                    <p style="margin: 0; font-size: 15px; font-weight: 600; color: #ffffff;">${macText}</p>
                                                    <p style="margin: 6px 0 0 0; font-size: 12px; color: rgba(255,255,255,0.5);">Activation</p>
                                                </div>
                                            </td>
                                            <td width="33%" style="text-align: center; padding: 0 6px;">
                                                <div style="background: linear-gradient(180deg, rgba(255,255,255,0.08) 0%, rgba(255,255,255,0.04) 100%); border: 1px solid rgba(255,255,255,0.1); border-radius: 16px; padding: 24px 12px;">
                                                    <div style="font-size: 28px; margin-bottom: 10px;">🔄</div>
                                                    <p style="margin: 0; font-size: 15px; font-weight: 600; color: #ffffff;">Lifetime</p>
                                                    <p style="margin: 6px 0 0 0; font-size: 12px; color: rgba(255,255,255,0.5);">Free Updates</p>
                                                </div>
                                            </td>
                                            <td width="33%" style="text-align: center; padding: 0 6px;">
                                                <div style="background: linear-gradient(180deg, rgba(255,255,255,0.08) 0%, rgba(255,255,255,0.04) 100%); border: 1px solid rgba(255,255,255,0.1); border-radius: 16px; padding: 24px 12px;">
                                                    <div style="font-size: 28px; margin-bottom: 10px;">💬</div>
                                                    <p style="margin: 0; font-size: 15px; font-weight: 600; color: #ffffff;">Priority</p>
                                                    <p style="margin: 6px 0 0 0; font-size: 12px; color: rgba(255,255,255,0.5);">Support</p>
                                                </div>
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                            </tr>

                            <!-- Pro Tips Section with Glass Cards -->
                            <tr>
                                <td style="padding: 8px 40px 32px 40px;">
                                    <h3 style="margin: 0 0 20px 0; font-size: 18px; font-weight: 600; color: #ffffff; text-align: center;">Pro Tips</h3>

                                    <!-- Tip 1: Window Switching -->
                                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background: linear-gradient(135deg, rgba(0, 122, 255, 0.2) 0%, rgba(0, 212, 255, 0.1) 100%); border: 1px solid rgba(0, 212, 255, 0.25); border-radius: 14px; margin-bottom: 12px;">
                                        <tr>
                                            <td style="padding: 20px 24px;">
                                                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                                                    <tr>
                                                        <td width="48" valign="top">
                                                            <div style="width: 40px; height: 40px; background: linear-gradient(135deg, #007AFF 0%, #00D4FF 100%); border-radius: 10px; text-align: center; line-height: 40px; font-size: 18px; box-shadow: 0 4px 12px rgba(0, 122, 255, 0.4);">⌨️</div>
                                                        </td>
                                                        <td style="padding-left: 16px;">
                                                            <p style="margin: 0 0 4px 0; font-size: 14px; font-weight: 600; color: #ffffff;">Quick Window Switching</p>
                                                            <p style="margin: 0; font-size: 13px; color: rgba(255,255,255,0.7);">Press <span style="font-family: 'SF Mono', Monaco, monospace; background: rgba(255,255,255,0.15); padding: 3px 8px; border-radius: 6px; font-weight: 600; color: #00D4FF;">⌘ Tab</span> to instantly switch between windows</p>
                                                        </td>
                                                    </tr>
                                                </table>
                                            </td>
                                        </tr>
                                    </table>

                                    <!-- Tip 2: Fuzzy Search -->
                                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background: linear-gradient(135deg, rgba(88, 86, 214, 0.2) 0%, rgba(175, 82, 222, 0.1) 100%); border: 1px solid rgba(175, 82, 222, 0.25); border-radius: 14px; margin-bottom: 12px;">
                                        <tr>
                                            <td style="padding: 20px 24px;">
                                                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                                                    <tr>
                                                        <td width="48" valign="top">
                                                            <div style="width: 40px; height: 40px; background: linear-gradient(135deg, #5856D6 0%, #AF52DE 100%); border-radius: 10px; text-align: center; line-height: 40px; font-size: 18px; box-shadow: 0 4px 12px rgba(88, 86, 214, 0.4);">🔍</div>
                                                        </td>
                                                        <td style="padding-left: 16px;">
                                                            <p style="margin: 0 0 4px 0; font-size: 14px; font-weight: 600; color: #ffffff;">Fuzzy Window Search</p>
                                                            <p style="margin: 0; font-size: 13px; color: rgba(255,255,255,0.7);">Press <span style="font-family: 'SF Mono', Monaco, monospace; background: rgba(255,255,255,0.15); padding: 3px 8px; border-radius: 6px; font-weight: 600; color: #AF52DE;">⌃ Space</span> to search and jump to any open window</p>
                                                        </td>
                                                    </tr>
                                                </table>
                                            </td>
                                        </tr>
                                    </table>

                                    <!-- Tip 3: Sidebar Gesture -->
                                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background: linear-gradient(135deg, rgba(52, 199, 89, 0.2) 0%, rgba(48, 209, 88, 0.1) 100%); border: 1px solid rgba(52, 199, 89, 0.25); border-radius: 14px;">
                                        <tr>
                                            <td style="padding: 20px 24px;">
                                                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                                                    <tr>
                                                        <td width="48" valign="top">
                                                            <div style="width: 40px; height: 40px; background: linear-gradient(135deg, #34C759 0%, #30D158 100%); border-radius: 10px; text-align: center; line-height: 40px; font-size: 18px; box-shadow: 0 4px 12px rgba(52, 199, 89, 0.4);">👆</div>
                                                        </td>
                                                        <td style="padding-left: 16px;">
                                                            <p style="margin: 0 0 4px 0; font-size: 14px; font-weight: 600; color: #ffffff;">Quick Sidebar Access</p>
                                                            <p style="margin: 0; font-size: 13px; color: rgba(255,255,255,0.7);">Two-finger scroll on the left or right edge of your screen to open the sidebar</p>
                                                        </td>
                                                    </tr>
                                                </table>
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                            </tr>

                            <!-- Important Reminders with Glass Effect -->
                            <tr>
                                <td style="padding: 0 40px 40px 40px;">
                                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background: linear-gradient(135deg, rgba(255, 159, 10, 0.15) 0%, rgba(255, 204, 0, 0.08) 100%); border-radius: 14px; border: 1px solid rgba(255, 204, 0, 0.25);">
                                        <tr>
                                            <td style="padding: 24px;">
                                                <p style="margin: 0 0 14px 0; font-size: 14px; font-weight: 600; color: #FFCC00;">📌 Important Reminders</p>
                                                <ul style="margin: 0; padding-left: 18px; color: rgba(255,255,255,0.8); font-size: 13px; line-height: 1.7;">
                                                    <li style="margin-bottom: 8px;">Keep this email safe — you'll need the license key if you reinstall macOS</li>
                                                    <li style="margin-bottom: 8px;">Deactivate your license before selling or wiping your Mac</li>
                                                    <li>Your license works offline after initial activation</li>
                                                </ul>
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                            </tr>

                        </td>
                    </tr>

                    <!-- Footer with Glass Effect -->
                    <tr>
                        <td style="padding: 36px 40px; text-align: center;">
                            <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" style="margin-bottom: 24px;">
                                <tr>
                                    <td>
                                        <div style="display: inline-block; width: 40px; height: 40px; background: linear-gradient(135deg, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0.05) 100%); border: 1px solid rgba(255,255,255,0.15); border-radius: 12px; text-align: center; line-height: 40px;">
                                            <span style="font-size: 18px; color: #00D4FF; font-weight: 700;">D</span>
                                        </div>
                                    </td>
                                </tr>
                            </table>
                            <p style="margin: 0 0 12px 0; font-size: 15px; color: rgba(255,255,255,0.7);">Questions? <a href="mailto:jayesh.betala7@gmail.com" style="color: #00D4FF; text-decoration: none; font-weight: 600;">Just reply</a></p>
                            <p style="margin: 0; font-size: 14px;">
                                <a href="https://dashpane.pro" style="color: rgba(255,255,255,0.5); text-decoration: none;">dashpane.pro</a>
                            </p>
                            <p style="margin: 28px 0 0 0; font-size: 11px; color: rgba(255,255,255,0.35);">
                                This email was sent to ${email} because you purchased DashPane.<br>
                                © ${new Date().getFullYear()} DashPane. All rights reserved.
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
════════════════════════════════════════════════════════════════
                        DASHPANE
                  Window Management for Mac
════════════════════════════════════════════════════════════════

✓ PURCHASE CONFIRMED

Welcome aboard, ${customerName}!

Thank you for purchasing DashPane. Your license key is ready.

────────────────────────────────────────────────────────────────
                    YOUR LICENSE KEY
────────────────────────────────────────────────────────────────

    ${licenseKey}

    ⚠️  Save this key in a safe place — you'll need it
        if you reinstall macOS.

────────────────────────────────────────────────────────────────
                    WHAT'S INCLUDED
────────────────────────────────────────────────────────────────

  💻  ${macText} Activation
  🔄  Lifetime Free Updates
  💬  Priority Support

────────────────────────────────────────────────────────────────
                    PRO TIPS
────────────────────────────────────────────────────────────────

  ⌨️  Quick Window Switching
      Press ⌘Tab to instantly switch between windows

  🔍  Fuzzy Window Search
      Press ⌃Space to search and jump to any open window

  👆  Quick Sidebar Access
      Two-finger scroll on the left or right edge of your
      screen to open the sidebar

────────────────────────────────────────────────────────────────
                    IMPORTANT REMINDERS
────────────────────────────────────────────────────────────────

  • Keep this email safe — you'll need the license key
    if you reinstall macOS
  • Deactivate your license before selling or wiping your Mac
  • Your license works offline after initial activation

════════════════════════════════════════════════════════════════

Questions? Just reply to this email.

  🌐  https://dashpane.pro

────────────────────────────────────────────────────────────────

This email was sent to ${email} because you purchased DashPane.
© ${new Date().getFullYear()} DashPane. All rights reserved.
    `;

    try {
        const { data, error } = await client.emails.send({
            from: fromEmail,
            to: [email],
            replyTo: 'jayesh.betala7@gmail.com',
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
