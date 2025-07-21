# Clauder

Control [Claude Code](https://claude.ai/code) from your iPhone with secure remote access. Clauder provides an iOS app for remote coding sessions.

![agentapi-chat](https://github.com/user-attachments/assets/57032c9f-4146-4b66-b219-09e38ab7690d)

**Key Features:**
- **Remote iOS Access**: Control Claude Code from your iPhone using a simple passcode
- **Secure Tunneling**: Encrypted connection over the internet with zero configuration
- **Local Terminal Access**: Direct terminal attach for laptop usage
- **Real-time Sync**: Both local and remote interfaces stay synchronized
- **One-Command Setup**: Get started in seconds with `clauder quickstart`

## Quick Start

### Prerequisites

1. **Install Claude Code**: Follow the installation guide at [claude.ai/code](https://claude.ai/code)
2. **Install Go**: Version 1.21 or later for building from source

### Installation

#### Option 1: Build from Source

```bash
git clone https://github.com/zohaibahmed/clauder.git
cd clauder
make build
```

This will create the `clauder` binary in the `out/` directory.

#### Option 2: Download Binary

Download the latest binary from the [releases page](https://github.com/zohaibahmed/clauder/releases) and add it to your PATH.

### Configuration

Before running Clauder, you need to set up your configuration:

1. **Copy the example configuration:**
   ```bash
   cp .env.example .env
   ```

2. **Edit the `.env` file** with your settings:
   ```bash
   # Required for remote iOS access
   COORDINATOR_URL=https://claude-code-coordinator.team-ad9.workers.dev
   
   # Optional: Change the default port
   # PORT=3284
   ```

3. **Configuration Options:**
   - **COORDINATOR_URL**: Required for `clauder quickstart` remote access. This should point to your deployed coordinator service.
   - **PORT**: HTTP server port (default: 3284)

> **Note:** If you don't set `COORDINATOR_URL`, remote iOS access won't work, but local terminal access (`clauder attach`) will still function.

### Getting Started

Start Clauder with both local terminal and remote iOS access:

```bash
./out/clauder quickstart
```

This will:
- Start Claude Code
- Launch the HTTP server with authentication
- Create a secure tunnel for remote access
- Display a passcode like `ALPHA-TIGER-OCEAN-1234`

**For local access** (same machine):
```bash
# In a new terminal
./out/clauder attach --url localhost:3284
```

**For iOS access**:
1. Open the Xcode project in the `ios/` folder and build the app
2. Enter the passcode displayed by `clauder quickstart`
3. Start coding from your iPhone!


## CLI Commands

### `clauder quickstart`

Start Claude Code with both local and remote iOS access (recommended):

```bash
clauder quickstart [flags]
```

**Flags:**
- `-p, --port`: HTTP server port (default: 3284)
- `-h, --help`: Show help

This command will:
1. Start Claude Code
2. Launch authenticated HTTP server
3. Create secure tunnel for remote access
4. Display connection passcode

### `clauder server`

Start just the HTTP server (without tunnel):

```bash
clauder server [agent] [flags]
```

**Arguments:**
- `agent`: The coding agent to control (claude, goose, aider, codex)

**Flags:**
- `-p, --port`: HTTP server port (default: 3284)
- `--no-auth`: Disable authentication (not recommended for remote access)

### `clauder attach`

Attach to a running Claude Code session in your terminal:

```bash
clauder attach --url localhost:3284
```

Press `Ctrl+C` to detach from the session.

## Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/zohaibahmed/clauder.git
cd clauder

# Build the complete project (Go backend + Next.js frontend)
make build

# Or build just the Go binary
go build -o out/clauder main.go

# Run tests
go test ./...
```

### Frontend Development

```bash
cd chat
bun install
bun run dev
```

### Building the iOS app

To build the iOS app locally:

```bash
cd ios
open AgentCodeRemote.xcodeproj
```

**Requirements:**
- Xcode 15.0+
- iOS 16.0+ target device
- Apple Developer account for device installation

## API Reference

Clauder exposes a REST API for controlling coding agents:

### Endpoints

- `GET /messages` - Get all conversation messages
- `POST /message` - Send a message to the agent
- `GET /status` - Get current agent status
- `GET /events` - Server-sent events stream for real-time updates
- `GET /health` - Health check endpoint

### Authentication

When using `clauder quickstart`, all endpoints (except `/health`) require Bearer token authentication:

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" https://your-tunnel-url/messages
```

The token is automatically generated and displayed when starting quickstart mode.

## Security

Clauder uses several security measures for remote access:

- **End-to-end encryption**: All communication over HTTPS tunnels
- **Token-based authentication**: 256-bit random tokens with 24-hour expiration
- **Passcode system**: Human-readable codes that expire after use
- **No direct exposure**: Your Mac is never directly exposed to the internet
- **Keychain storage**: iOS app stores credentials securely

## Troubleshooting

**"Failed to start Claude Code"**
- Ensure Claude Code is installed: `which claude`
- Check your PATH: `echo $PATH`

**"Failed to establish tunnel"**
- Check firewall settings
- Verify internet connection: `curl -I https://claude.ai`

**"Invalid passcode" on iOS**
- Ensure correct capitalization
- Check if the passcode has expired (24 hours)
- Verify the Mac is still running Clauder

## Configuration

### Environment Variables

- `COORDINATOR_URL` - Override the default coordinator service URL
- `PORT` - Default port for HTTP server (default: 3284)

### Custom Coordinator Service

To use your own coordinator service, deploy the Cloudflare Worker in the `coordinator/` directory:

```bash
cd coordinator
# Update wrangler.toml with your KV namespace ID
wrangler kv:namespace create "SESSIONS"
wrangler deploy
```

Then set the environment variable:

```bash
export COORDINATOR_URL=https://your-coordinator.workers.dev
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

Inspired by the need for remote coding capabilities and built with modern web technologies.
