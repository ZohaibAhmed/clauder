# Claude Code Remote - iOS App

A beautifully crafted iOS app that allows you to control Claude Code running on your Mac remotely using a simple passcode. Built with modern SwiftUI, featuring sleek animations and intuitive design.

## ✨ Features

### 🎨 **Modern Design**
- **Sleek Interface**: Contemporary iOS design with smooth gradients and glass effects
- **Beautiful Animations**: Fluid spring animations and micro-interactions throughout
- **Dark/Light Mode**: Automatic adaptation to system appearance preferences
- **Haptic Feedback**: Responsive tactile feedback for enhanced user experience

### 🔐 **Simple & Secure Connection**
- **One-Tap Setup**: Enter a passcode from your Mac to connect instantly
- **Secure Tunnel**: All communication encrypted via HTTPS with Bearer token authentication
- **Auto-Reconnection**: App remembers your session and reconnects automatically
- **Session Management**: Secure storage in iOS Keychain with biometric protection

### 💬 **Advanced Chat Experience**
- **Real-time Messaging**: Send messages and receive responses with live updates
- **Smart Message Types**: Automatic detection and formatting of code blocks
- **Copy Functionality**: Long-press any message to copy to clipboard
- **Typing Indicators**: Visual feedback when composing messages
- **Message Animations**: Messages appear with smooth slide-in animations

### 🚀 **Performance & Polish**
- **Optimized Scrolling**: Smooth message list with lazy loading
- **Keyboard Handling**: Intelligent keyboard avoidance and input field positioning
- **Error States**: Beautiful error animations with clear recovery instructions
- **Loading States**: Elegant loading animations with pulsing dots and indicators
- **Status Awareness**: Real-time connection status with visual and haptic feedback

## 📱 Requirements

- **iOS 16.0** or later
- **iPhone** (optimized for iPhone, compatible with iPad)
- **Mac** with Claude Code and Clauder installed
- **Internet connection** on both devices

## 🚀 Getting Started

### 1. **Mac Setup**
```bash
# Build and install Clauder
make build

# Start Claude Code with remote access
./out/clauder quickstart
```
You'll see output like:
```
🎉 Claude Code Remote Access Ready!
📱 Passcode: TIGER-MOON-ALPHA-7429
```

### 2. **iOS Connection**
1. **Launch** the Claude Code Remote app
2. **Enter** the passcode from your Mac
3. **Tap** "Connect" with beautiful haptic feedback
4. **Start** coding remotely with real-time sync!

## Architecture

The iOS app follows MVVM architecture with the following components:

### Models
- **Session**: Stores connection details and authentication token
- **Message**: Represents chat messages between user and agent
- **AgentStatus**: Tracks the current state of Claude Code

### Services
- **ClauderAPIClient**: Main service for communicating with Claude Code
- **EventSourceClient**: Handles real-time updates via Server-Sent Events
- **KeychainService**: Securely stores session data in iOS Keychain

### Views
- **ConnectionView**: Passcode entry and connection flow
- **ChatView**: Main chat interface with message history
- **MessageRow**: Individual message display component

## Security Features

- **Keychain Storage**: Session tokens stored securely in iOS Keychain
- **HTTPS Only**: All communication over encrypted HTTPS tunnel
- **Token Authentication**: Bearer token authentication for all API calls
- **Session Expiration**: Sessions automatically expire after 24 hours
- **Biometric Protection**: Keychain items protected by device biometrics

## Development

### Building from Xcode
1. Open `AgentCodeRemote.xcodeproj` in Xcode
2. Select your development team in project settings
3. Build and run on device or simulator

### Key Components

#### Connection Flow
1. User enters passcode
2. App queries coordinator service to get tunnel URL and token
3. App tests connection to Claude Code via tunnel
4. Session saved to Keychain for future use
5. Event stream connected for real-time updates

#### Message Flow
1. User types message in chat interface
2. Message sent to Claude Code via tunnel API
3. Claude Code processes message and updates terminal
4. Clauder detects changes and broadcasts via Server-Sent Events
5. iOS app receives update and displays new message

## API Integration

The app integrates with:

1. **Coordinator Service** (`https://coordinator.example.com`)
   - `POST /register` - Register new session (used by Mac)
   - `GET /lookup/:passcode` - Get session details (used by iOS)

2. **Clauder** (via tunnel)
   - `GET /health` - Health check
   - `GET /status` - Get agent status
   - `GET /messages` - Get message history
   - `POST /message` - Send message to agent
   - `GET /events` - Server-Sent Events stream

## Error Handling

The app handles various error scenarios:

- **Invalid Passcode**: Clear error message with retry option
- **Network Errors**: Automatic retry with exponential backoff
- **Session Expiration**: Automatic redirect to connection screen
- **Authentication Failures**: Clear session and require re-connection
- **Connection Loss**: Attempt to reconnect automatically

## Privacy

- No personal data is collected or transmitted
- Passcodes are temporary (24-hour expiration)
- All communication is encrypted end-to-end
- Session tokens stored only in device Keychain
- No analytics or tracking

## Support

For issues or questions:
1. Check that Claude Code is running on your Mac
2. Verify the passcode is entered correctly
3. Ensure both devices have internet connectivity
4. Try generating a new passcode with `clauder quickstart`