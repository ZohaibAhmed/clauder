package quickstart

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/spf13/cobra"
	"github.com/zohaibahmed/clauder/lib/coordinator"
	"github.com/zohaibahmed/clauder/lib/httpapi"
	"github.com/zohaibahmed/clauder/lib/logctx"
	mf "github.com/zohaibahmed/clauder/lib/msgfmt"
	"github.com/zohaibahmed/clauder/lib/termexec"
	"github.com/zohaibahmed/clauder/lib/tunnel"
)

var QuickstartCmd = &cobra.Command{
	Use:   "quickstart",
	Short: "Start Claude Code with local and remote access",
	Long:  "Starts Claude Code with dual access: terminal attach for laptop use and secure tunnel for mobile app access",
	Run:   runQuickstart,
}

func init() {
	QuickstartCmd.Flags().IntP("port", "p", 3284, "Port to run the server on")
}

func runQuickstart(cmd *cobra.Command, args []string) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Setup logging
	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	ctx = logctx.WithLogger(ctx, logger)

	port, _ := cmd.Flags().GetInt("port")

	// Step 1: Generate session credentials
	session := generateSession()
	logger.Info("🔐 Generated session credentials", "passcode", session.Passcode)

	// Step 2: Start Claude Code
	fmt.Println("🚀 Starting Claude Code...")
	claudeProcess, err := startClaudeCode(ctx)
	if err != nil {
		fmt.Printf("❌ Failed to start Claude Code: %v\n", err)
		os.Exit(1)
	}
	defer claudeProcess.Close(logger, 10*time.Second)

	// Step 3: Start Clauder server with authentication
	fmt.Println("🌐 Starting Clauder server with authentication...")
	server := startAuthenticatedServer(ctx, session.Token, claudeProcess, port)

	// Start the server in a goroutine
	go func() {
		if err := server.Start(); err != nil {
			logger.Error("Server failed", "error", err)
			cancel()
		}
	}()

	// Wait a moment for server to start
	time.Sleep(1 * time.Second)

	// Step 4: Check available tunnel providers
	fmt.Println("🔍 Checking available tunnel providers...")
	availableProviders := tunnel.CheckAvailableProviders()
	if len(availableProviders) == 0 {
		fmt.Println("❌ No tunnel providers found!")
		fmt.Println("\n📦 Install a tunnel provider:")
		for provider, instruction := range tunnel.InstallInstructions() {
			fmt.Printf("   %s: %s\n", provider, instruction)
		}
		os.Exit(1)
	}

	fmt.Printf("✅ Found tunnel providers: %v\n", availableProviders)

	// Step 5: Establish tunnel
	fmt.Println("🔗 Establishing secure tunnel...")
	tunnelURL, err := establishTunnel(ctx, port)
	if err != nil {
		fmt.Printf("❌ Failed to establish tunnel: %v\n", err)
		fmt.Println("\n💡 Troubleshooting:")
		fmt.Println("   - Ensure your tunnel provider is properly configured")
		fmt.Println("   - Check your internet connection")
		fmt.Println("   - Try running the tunnel manually to test")
		os.Exit(1)
	}

	// Step 6: Register with coordinator
	fmt.Println("📋 Registering session with coordinator...")
	err = registerWithCoordinator(session.Passcode, tunnelURL, session.Token)
	if err != nil {
		fmt.Printf("❌ Failed to register session: %v\n", err)
		os.Exit(1)
	}

	// Step 7: Display connection info
	displayConnectionInfo(session.Passcode, tunnelURL, port)

	// Step 8: Start snapshot loop
	server.StartSnapshotLoop(ctx)

	// Step 9: Wait for interrupt
	waitForInterrupt(ctx, cancel, server)
}

func startClaudeCode(ctx context.Context) (*termexec.Process, error) {
	// Check if claude is available
	if _, err := exec.LookPath("claude"); err != nil {
		return nil, fmt.Errorf("claude command not found in PATH. Please install Claude Code first")
	}

	// Start Claude Code
	process, err := termexec.StartProcess(ctx, termexec.StartProcessConfig{
		Program:        "claude",
		Args:           []string{},
		TerminalWidth:  120,
		TerminalHeight: 30,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to start Claude Code: %w", err)
	}

	// Wait a moment for Claude to initialize
	time.Sleep(2 * time.Second)

	return process, nil
}

func startAuthenticatedServer(ctx context.Context, token string, process *termexec.Process, port int) *httpapi.Server {
	// Create server with authentication
	server := httpapi.NewServerWithAuth(ctx, mf.AgentTypeClaude, process, port, "/magic-base-path-placeholder", token)
	return server
}

func establishTunnel(ctx context.Context, localPort int) (string, error) {
	return tunnel.Connect(ctx, localPort)
}

func registerWithCoordinator(passcode, tunnelURL, token string) error {
	return coordinator.Register(passcode, tunnelURL, token)
}

func displayConnectionInfo(passcode, tunnelURL string, port int) {
	fmt.Println("\n" + strings.Repeat("=", 70))
	fmt.Println("🎉 Claude Coder is Ready!")
	fmt.Println(strings.Repeat("=", 70))
	fmt.Printf("📱 Mobile Passcode: %s\n", passcode)
	fmt.Printf("🌐 Tunnel URL: %s\n", tunnelURL)
	fmt.Printf("💻 Local Port: %d\n", port)
	fmt.Println(strings.Repeat("-", 70))
	fmt.Println("📋 Usage Options:")
	fmt.Println("  📱 MOBILE: Open Claude Coder app and enter passcode: " + passcode)
	fmt.Println("  🖥️  LAPTOP: In a new terminal, run:")
	fmt.Printf("             ./out/clauder attach --url localhost:%d\n", port)
	fmt.Println(strings.Repeat("-", 70))
	fmt.Println("💡 You can now use Claude Code from both your laptop and phone!")
	fmt.Println("💡 The attach command gives you direct terminal access on your laptop.")
	fmt.Println("⏰ Mobile session expires in 24 hours")
	fmt.Println("🛑 Press Ctrl+C to stop")
	fmt.Println(strings.Repeat("=", 70) + "\n")
}

func waitForInterrupt(ctx context.Context, cancel context.CancelFunc, server *httpapi.Server) {
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	select {
	case <-sigCh:
		fmt.Println("\n🛑 Received interrupt signal, shutting down...")
	case <-ctx.Done():
		fmt.Println("\n🛑 Context cancelled, shutting down...")
	}

	// Graceful shutdown
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	if err := server.Stop(shutdownCtx); err != nil {
		fmt.Printf("❌ Error during server shutdown: %v\n", err)
	} else {
		fmt.Println("✅ Server stopped gracefully")
	}

	cancel()
}
