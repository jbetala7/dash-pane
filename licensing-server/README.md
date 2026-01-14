# DashPane Licensing Server

A simple license management server for DashPane that integrates with Razorpay.

## Features

- Razorpay webhook integration for automatic license generation
- Hardware-bound license activation
- Multi-machine support (configurable limit)
- License validation API
- SQLite database (zero configuration)

## Setup

1. Install dependencies:
```bash
npm install
```

2. Copy environment file and configure:
```bash
cp .env.example .env
```

3. Edit `.env` with your credentials:
- Razorpay API keys
- SMTP settings for email delivery
- Server configuration

4. Start the server:
```bash
npm start
```

For development with auto-reload:
```bash
npm run dev
```

## API Endpoints

### Webhooks

#### `POST /webhook/razorpay`
Receives Razorpay payment webhooks. Automatically creates a license when payment is captured.

#### `POST /webhook/test` (development only)
Create a test license without payment.

```bash
curl -X POST http://localhost:3000/webhook/test \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'
```

### License Management

#### `POST /api/license/activate`
Activate a license on a machine.

```json
{
  "license_key": "DASH-XXXX-XXXX-XXXX",
  "hardware_id": "unique-machine-identifier",
  "machine_name": "John's MacBook Pro"
}
```

#### `POST /api/license/validate`
Check if a license is valid on a machine.

```json
{
  "license_key": "DASH-XXXX-XXXX-XXXX",
  "hardware_id": "unique-machine-identifier"
}
```

#### `POST /api/license/deactivate`
Deactivate a license from a machine.

```json
{
  "license_key": "DASH-XXXX-XXXX-XXXX",
  "hardware_id": "unique-machine-identifier"
}
```

#### `GET /api/license/info/:key`
Get license information and activation status.

## Razorpay Webhook Setup

1. Go to Razorpay Dashboard > Settings > Webhooks
2. Add new webhook with URL: `https://your-server.com/webhook/razorpay`
3. Select event: `payment.captured`
4. Copy the webhook secret to your `.env` file

## Deployment

The server can be deployed to:
- Railway
- Render
- Fly.io
- Any Node.js hosting platform

Ensure your `.env` variables are configured in your hosting platform's environment settings.
