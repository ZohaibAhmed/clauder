// Package clauder provides HTTP API control for coding agents including Claude Code, Goose, Aider, and Codex.
//
// Clauder enables remote access to terminal-based coding agents through a REST API and includes:
//
//   - HTTP server with REST endpoints for sending messages and receiving responses
//   - Terminal process management with pseudoterminal (PTY) integration
//   - Real-time message streaming via Server-Sent Events (SSE)
//   - Authentication support for secure remote access
//   - iOS app support through secure tunneling and passcode coordination
//   - Message formatting and cleanup for different agent types
//
// # Basic Usage
//
// Start a local server for Claude Code:
//
//	clauder server claude
//
// Start with remote iOS access:
//
//	clauder quickstart
//
// Attach to a running session from terminal:
//
//	clauder attach --url localhost:3284
//
// # Architecture
//
// The system consists of several key components:
//
//   - cmd/: CLI commands and application entry points
//   - lib/httpapi/: HTTP server and API endpoints
//   - lib/termexec/: Terminal process management
//   - lib/screentracker/: Terminal output monitoring and parsing
//   - lib/msgfmt/: Message formatting for different agents
//   - lib/coordinator/: Session coordination service client
//   - lib/tunnel/: Secure tunneling for remote access
//
// # Security
//
// When using remote access features:
//
//   - All communication is encrypted over HTTPS
//   - Bearer token authentication for API endpoints
//   - Time-limited session passcodes (24 hour expiration)
//   - No direct internet exposure of local machine
//
// For more information, see https://github.com/zohaibahmed/clauder
package main
