# Tunnel Implementation

A robust tunnel client that automatically detects and uses available tunnel providers to expose the local Clauder server to the internet.

## Supported Tunnel Providers

### 1. **ngrok** (Recommended)
- **Installation**: `brew install ngrok` or download from https://ngrok.com/download
- **Pros**: Reliable, fast, good free tier, HTTPS by default
- **Cons**: Requires account for persistent URLs
- **Usage**: Automatically detected if `ngrok` command is available

### 2. **bore** (Free Alternative)  
- **Installation**: `cargo install bore-cli` or download from https://github.com/ekzhang/bore
- **Pros**: Completely free, no account required, simple
- **Cons**: Less reliable than ngrok, beta software
- **Usage**: Automatically detected if `bore` command is available

### 3. **localhost.run** (SSH-based)
- **Installation**: Uses system SSH (pre-installed on macOS/Linux)
- **Pros**: No installation required, free
- **Cons**: Can be slow, less reliable
- **Usage**: Automatically detected if `ssh` command is available

## How It Works

The tunnel client uses a **fallback strategy**:

1. **Detection**: Checks which tunnel providers are installed
2. **Priority Order**: Tries providers in order: ngrok → bore → localhost.run
3. **Auto-Retry**: If one provider fails, automatically tries the next
4. **Output Parsing**: Monitors each provider's output to extract the public URL
5. **Health Check**: Verifies the tunnel is working by testing the `/health` endpoint

## Implementation Details

### Provider Detection
```go
func CheckAvailableProviders() []TunnelProvider {
    var available []TunnelProvider
    
    if _, err := exec.LookPath("ngrok"); err == nil {
        available = append(available, ProviderNgrok)
    }
    
    if _, err := exec.LookPath("bore"); err == nil {
        available = append(available, ProviderBore)
    }
    
    if _, err := exec.LookPath("ssh"); err == nil {
        available = append(available, ProviderLocal)
    }
    
    return available
}
```

### Connection Flow
```go
func Connect(ctx context.Context, localPort int) (string, error) {
    providers := []TunnelProvider{ProviderNgrok, ProviderBore, ProviderLocal}
    
    for _, provider := range providers {
        client, err := connectWithProvider(ctx, provider, localPort)
        if err != nil {
            continue // Try next provider
        }
        
        return client.publicURL, nil
    }
    
    return "", fmt.Errorf("all tunnel providers failed")
}
```

### Output Parsing

Each provider uses different output formats:

**ngrok**: 
```
url=https://abc123.ngrok.io
```

**bore**:
```
listening at https://abc123.bore.pub
```

**localhost.run**:
```
https://abc123.localhost.run
```

The client uses regex patterns to extract URLs from the command output.

## Usage

### Basic Usage
```go
import "github.com/claudeai/clauder/lib/tunnel"

// Establish tunnel for local port 3284
publicURL, err := tunnel.Connect(ctx, 3284)
if err != nil {
    log.Fatal("Failed to establish tunnel:", err)
}

fmt.Printf("Tunnel available at: %s\n", publicURL)
```

### Check Available Providers
```go
providers := tunnel.CheckAvailableProviders()
if len(providers) == 0 {
    fmt.Println("No tunnel providers found!")
    for provider, instruction := range tunnel.InstallInstructions() {
        fmt.Printf("%s: %s\n", provider, instruction)
    }
}
```

### Verify Connection
```go
err := tunnel.VerifyConnection(publicURL)
if err != nil {
    log.Printf("Tunnel verification failed: %v", err)
}
```

## Error Handling

The implementation handles various error scenarios:

- **No providers available**: Shows installation instructions
- **Provider startup failure**: Tries next provider in list
- **Timeout waiting for URL**: 30-second timeout per provider
- **Connection verification failure**: Tests health endpoint through tunnel

## Installation Guide

### Install ngrok (Recommended)
```bash
# macOS
brew install ngrok

# Manual install
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install ngrok

# Sign up and authenticate
ngrok authtoken YOUR_TOKEN
```

### Install bore (Free Alternative)
```bash
# With Rust/Cargo
cargo install bore-cli

# Manual download (Linux/macOS)
curl -L https://github.com/ekzhang/bore/releases/latest/download/bore-linux-x86_64 -o bore
chmod +x bore
sudo mv bore /usr/local/bin/
```

### localhost.run (No Install Required)
Uses system SSH - available by default on macOS and most Linux distributions.

## Troubleshooting

### Common Issues

1. **"No tunnel providers found"**
   - Install at least one tunnel provider
   - Ensure the binary is in your PATH

2. **"Timeout waiting for tunnel URL"**
   - Check internet connection
   - Try running the tunnel command manually
   - Some providers may be temporarily unavailable

3. **"Tunnel health check failed"**
   - Ensure Clauder server is running on the specified port
   - Check firewall settings
   - Verify tunnel URL is accessible

### Manual Testing

Test each provider manually:

```bash
# ngrok
ngrok http 3284

# bore  
bore local 3284 --to bore.pub

# localhost.run
ssh -R 80:localhost:3284 localhost.run
```

## Security Considerations

- **HTTPS by Default**: All providers use HTTPS tunnels
- **Temporary URLs**: URLs are ephemeral and change on restart
- **No Persistent Exposure**: Tunnel only exists while process runs
- **Token-based Auth**: Clauder uses Bearer tokens for additional security

## Integration with Clauder

The tunnel client is integrated into the quickstart command:

```bash
clauder quickstart
```

This automatically:
1. Detects available tunnel providers
2. Starts the tunnel
3. Configures Clauder with authentication
4. Registers the session for iOS app connection

The iOS app can then connect using the generated passcode to access Claude Code remotely.