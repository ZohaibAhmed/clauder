# Deploy Coordinator Service to Cloudflare Workers

## Prerequisites

1. **Cloudflare Account**: Sign up at https://cloudflare.com
2. **Wrangler CLI**: Install Cloudflare's CLI tool
   ```bash
   npm install -g wrangler
   ```

## Setup Steps

### 1. Login to Cloudflare
```bash
wrangler login
```

### 2. Create wrangler.toml
Create `coordinator/wrangler.toml`:
```toml
name = "claude-code-coordinator"
main = "worker.js"
compatibility_date = "2024-01-01"

[env.production]
name = "claude-code-coordinator"
kv_namespaces = [
  { binding = "SESSIONS", id = "YOUR_KV_NAMESPACE_ID" }
]

[env.development]
name = "claude-code-coordinator-dev"
kv_namespaces = [
  { binding = "SESSIONS", id = "YOUR_DEV_KV_NAMESPACE_ID" }
]
```

### 3. Create KV Namespace
```bash
# Production namespace
wrangler kv:namespace create "SESSIONS" --env production

# Development namespace  
wrangler kv:namespace create "SESSIONS" --env development
```

Copy the namespace IDs from the output and update your `wrangler.toml`.

### 4. Deploy to Production
```bash
cd coordinator
wrangler deploy --env production
```

### 5. Update Coordinator URL
After deployment, update the coordinator URL in:

**Go client** (`lib/coordinator/client.go`):
```go
CoordinatorURL = "https://claude-code-coordinator.YOUR_SUBDOMAIN.workers.dev"
```

**iOS app** (`ios/AgentCodeRemote/AgentCodeRemoteApp.swift`):
```swift
private let coordinatorURL = "https://claude-code-coordinator.YOUR_SUBDOMAIN.workers.dev"
```

Replace `YOUR_SUBDOMAIN` with your actual Cloudflare Workers subdomain.

## Testing

Test the deployed coordinator:
```bash
# Health check
curl https://claude-code-coordinator.YOUR_SUBDOMAIN.workers.dev/health

# Test registration (will fail without valid data, but should return 400 not 404)
curl -X POST https://claude-code-coordinator.YOUR_SUBDOMAIN.workers.dev/register \
  -H "Content-Type: application/json" \
  -d '{}'
```

## Usage

The coordinator service provides:
- `POST /register` - Register new sessions (used by Mac)
- `GET /lookup/:passcode` - Lookup sessions (used by iOS)
- `GET /health` - Health check
- `GET /` - API documentation