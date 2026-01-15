require('dotenv').config();

const express = require('express');
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');

const { initDatabase } = require('./database');
const webhookRoutes = require('./routes/webhook');
const licenseRoutes = require('./routes/license');
const { sendLicenseEmail } = require('./emailService');

const app = express();
const PORT = process.env.PORT || 3000;

// Serve static files from public directory (before helmet for images)
app.use(express.static(path.join(__dirname, '..', 'public')));

// Security middleware
app.use(helmet());

// CORS configuration
app.use(cors({
    origin: process.env.NODE_ENV === 'production'
        ? ['https://dashpane.com', 'https://www.dashpane.com']
        : '*',
    methods: ['GET', 'POST'],
    allowedHeaders: ['Content-Type', 'Authorization', 'x-razorpay-signature']
}));

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'ok',
        timestamp: new Date().toISOString()
    });
});

// Test email endpoint (temporary - remove after testing)
app.post('/test-email', express.json(), async (req, res) => {
    const { email, secret } = req.body;

    // Simple security check
    if (secret !== process.env.RAZORPAY_WEBHOOK_SECRET) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        const result = await sendLicenseEmail(email || 'jayesh.betala7@gmail.com', 'DASH-TEST-1234-ABCD', 'Test User');
        res.json({ success: true, message: 'Test email sent', result });
    } catch (error) {
        console.error('Test email error:', error);
        res.status(500).json({ error: error.message, stack: error.stack });
    }
});

// Dev license generation endpoint (secured with webhook secret)
app.post('/dev-license', express.json(), async (req, res) => {
    const { email, secret } = req.body;

    // Security check with webhook secret
    if (secret !== process.env.RAZORPAY_WEBHOOK_SECRET) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        const { generateLicenseKey } = require('./licenseGenerator');
        const { prepare } = require('./database');

        const licenseKey = generateLicenseKey(process.env.LICENSE_PREFIX || 'DASH');

        prepare(`
            INSERT INTO licenses (license_key, email, phone, razorpay_payment_id, amount, currency)
            VALUES (?, ?, ?, ?, ?, ?)
        `).run(licenseKey, email || 'dev@dashpane.local', null, `dev_${Date.now()}`, 0, 'INR');

        console.log(`Dev license created: ${licenseKey}`);

        // Send the license email
        const customerName = req.body.name || 'Customer';
        try {
            await sendLicenseEmail(email, licenseKey, customerName);
            console.log(`License email sent to ${email}`);
        } catch (emailError) {
            console.error('Failed to send license email:', emailError);
        }

        res.json({
            success: true,
            license_key: licenseKey,
            email: email || 'dev@dashpane.local'
        });
    } catch (error) {
        console.error('Dev license error:', error);
        res.status(500).json({ error: error.message });
    }
});

// Routes
app.use('/webhook', webhookRoutes);
app.use('/api/license', licenseRoutes);

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err, req, res, next) => {
    console.error('Server error:', err);
    res.status(500).json({ error: 'Internal server error' });
});

// Initialize database and start server
async function start() {
    try {
        await initDatabase();

        app.listen(PORT, () => {
            console.log(`DashPane Licensing Server running on port ${PORT}`);
            console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
            console.log(`Health check: http://localhost:${PORT}/health`);
        });
    } catch (error) {
        console.error('Failed to start server:', error);
        process.exit(1);
    }
}

start();

module.exports = app;
