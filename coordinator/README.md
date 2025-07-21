# Claude Code Remote Coordinator Service

This Cloudflare Worker manages passcode-based session coordination between Mac and iOS devices.

## Setup

1. **Install Wrangler CLI**:
   ```bash
   npm install -g wrangler
   ```

2. **Login to Cloudflare**:
   ```bash
   wrangler login
   ```

3. **Create KV Namespace**:
   ```bash
   wrangler kv:namespace create SESSIONS
   wrangler kv:namespace create SESSIONS --preview
   ```

4. **Update wrangler.toml**:
   - Replace `your-kv-namespace-id-here` with the production namespace ID
   - Replace `your-preview-kv-namespace-id-here` with the preview namespace ID

## Development

1. **Start local development**:
   ```bash
   wrangler dev
   ```

2. **Test endpoints**:
   ```bash
   # Health check
   curl http://localhost:8787/health
   
   # Register session
   curl -X POST http://localhost:8787/register \
     -H "Content-Type: application/json" \
     -d '{
       "passcode": "ABC123",
       "tunnel_url": "https://abc123.lhr.life",
       "token": "your-jwt-token-here"
     }'
   
   # Lookup session
   curl http://localhost:8787/lookup/ABC123
   ```

## Deployment

1. **Deploy to production**:
   ```bash
   wrangler deploy --env production
   ```

2. **Verify deployment**:
   ```bash
   curl https://coordinator.example.com/health
   ```

## API Reference

### POST /register
Register a new session with passcode, tunnel URL, and authentication token.

**Request Body**:
```json
{
  "passcode": "ABC123",
  "tunnel_url": "https://abc123.lhr.life",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response**:
```json
{
  "success": true,
  "passcode": "ABC123",
  "expires_in": 86400,
  "message": "Session registered successfully"
}
```

### GET /lookup/:passcode
Get session details for a given passcode.

**Response**:
```json
{
  "tunnel_url": "https://abc123.lhr.life",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "created_at": 1640995200000,
  "expires_at": 1641081600000
}
```

### GET /health
Health check endpoint.

**Response**:
```json
{
  "status": "ok",
  "timestamp": 1640995200000,
  "version": "1.0.0"
}
```

## Security Features

- **Passcode validation**: Enforces 6-character alphanumeric format
- **Automatic expiration**: Sessions expire after 24 hours
- **Rate limiting**: 10 requests per minute per IP
- **CORS support**: Allows cross-origin requests from iOS app
- **Input validation**: Validates all required fields

## Monitoring

Monitor the worker through the Cloudflare dashboard:
- Request volume and latency
- Error rates and logs
- KV namespace usage
- Rate limiting metrics