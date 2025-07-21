package tunnel

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os/exec"
	"regexp"
	"strings"
	"time"

	"github.com/zohaibahmed/clauder/lib/logctx"
)

const (
	MaxRetries     = 10
	RetryDelay     = 2 * time.Second
	StartupTimeout = 30 * time.Second
)

// TunnelProvider represents different tunnel service providers
type TunnelProvider string

const (
	ProviderNgrok TunnelProvider = "ngrok"
	ProviderBore  TunnelProvider = "bore"
	ProviderLocal TunnelProvider = "localhost.run"
)

// TunnelClient manages the tunnel connection
type TunnelClient struct {
	provider  TunnelProvider
	localPort int
	logger    *slog.Logger
	ctx       context.Context
	cancel    context.CancelFunc
	cmd       *exec.Cmd
	publicURL string
}

// TunnelInfo contains the tunnel connection details
type TunnelInfo struct {
	PublicURL string `json:"public_url"`
	Provider  string `json:"provider"`
	LocalPort int    `json:"local_port"`
}

// Connect establishes a tunnel connection and returns the public URL
func Connect(ctx context.Context, localPort int) (string, error) {
	logger := logctx.From(ctx)

	// Try tunnel providers in order of preference (localhost.run first - no signup required)
	providers := []TunnelProvider{ProviderLocal, ProviderBore, ProviderNgrok}

	for _, provider := range providers {
		logger.Info("Attempting tunnel connection", "provider", provider)

		client, err := connectWithProvider(ctx, provider, localPort)
		if err != nil {
			logger.Warn("Tunnel provider failed", "provider", provider, "error", err)
			continue
		}

		logger.Info("Tunnel connected successfully", "provider", provider, "url", client.publicURL)
		return client.publicURL, nil
	}

	return "", fmt.Errorf("all tunnel providers failed")
}

// connectWithProvider attempts to connect using a specific tunnel provider
func connectWithProvider(ctx context.Context, provider TunnelProvider, localPort int) (*TunnelClient, error) {
	logger := logctx.From(ctx)

	tunnelCtx, cancel := context.WithCancel(ctx)

	client := &TunnelClient{
		provider:  provider,
		localPort: localPort,
		logger:    logger,
		ctx:       tunnelCtx,
		cancel:    cancel,
	}

	switch provider {
	case ProviderNgrok:
		return client.connectNgrok()
	case ProviderBore:
		return client.connectBore()
	case ProviderLocal:
		return client.connectLocalhost()
	default:
		cancel()
		return nil, fmt.Errorf("unsupported tunnel provider: %s", provider)
	}
}

// connectNgrok connects using ngrok
func (c *TunnelClient) connectNgrok() (*TunnelClient, error) {
	// Check if ngrok is available
	if _, err := exec.LookPath("ngrok"); err != nil {
		return nil, fmt.Errorf("ngrok not found in PATH")
	}

	// Start ngrok
	cmd := exec.CommandContext(c.ctx, "ngrok", "http", fmt.Sprintf("%d", c.localPort), "--log", "stdout")
	c.cmd = cmd

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, fmt.Errorf("failed to get stdout pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start ngrok: %w", err)
	}

	// Parse ngrok output to get public URL
	publicURL, err := c.parseNgrokOutput(stdout)
	if err != nil {
		c.cmd.Process.Kill()
		return nil, err
	}

	c.publicURL = publicURL
	return c, nil
}

// connectBore connects using bore
func (c *TunnelClient) connectBore() (*TunnelClient, error) {
	// Check if bore is available
	if _, err := exec.LookPath("bore"); err != nil {
		return nil, fmt.Errorf("bore not found in PATH")
	}

	// Start bore
	cmd := exec.CommandContext(c.ctx, "bore", "local", fmt.Sprintf("%d", c.localPort), "--to", "bore.pub")
	c.cmd = cmd

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, fmt.Errorf("failed to get stdout pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start bore: %w", err)
	}

	// Parse bore output to get public URL
	publicURL, err := c.parseBoreOutput(stdout)
	if err != nil {
		c.cmd.Process.Kill()
		return nil, err
	}

	c.publicURL = publicURL
	return c, nil
}

// connectLocalhost connects using localhost.run
func (c *TunnelClient) connectLocalhost() (*TunnelClient, error) {
	// Check if ssh is available
	if _, err := exec.LookPath("ssh"); err != nil {
		return nil, fmt.Errorf("ssh not found in PATH")
	}

	// Start localhost.run tunnel
	cmd := exec.CommandContext(c.ctx, "ssh", "-o", "StrictHostKeyChecking=no", "-o", "ServerAliveInterval=60", "-R", fmt.Sprintf("80:localhost:%d", c.localPort), "localhost.run")
	c.cmd = cmd

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, fmt.Errorf("failed to get stdout pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start localhost.run: %w", err)
	}

	// Parse localhost.run output to get public URL
	publicURL, err := c.parseLocalhostOutput(stdout)
	if err != nil {
		c.cmd.Process.Kill()
		return nil, err
	}

	c.publicURL = publicURL
	return c, nil
}

// parseNgrokOutput parses ngrok output to extract the public URL
func (c *TunnelClient) parseNgrokOutput(stdout io.Reader) (string, error) {
	scanner := bufio.NewScanner(stdout)
	timeout := time.NewTimer(StartupTimeout)
	defer timeout.Stop()

	urlRegex := regexp.MustCompile(`url=https://[a-zA-Z0-9\-]+\.ngrok\.io`)

	for {
		select {
		case <-timeout.C:
			return "", fmt.Errorf("timeout waiting for ngrok URL")
		case <-c.ctx.Done():
			return "", c.ctx.Err()
		default:
			if !scanner.Scan() {
				if err := scanner.Err(); err != nil {
					return "", fmt.Errorf("error reading ngrok output: %w", err)
				}
				continue
			}

			line := scanner.Text()
			if match := urlRegex.FindString(line); match != "" {
				// Extract URL from "url=https://..."
				url := strings.TrimPrefix(match, "url=")
				return url, nil
			}
		}
	}
}

// parseBoreOutput parses bore output to extract the public URL
func (c *TunnelClient) parseBoreOutput(stdout io.Reader) (string, error) {
	scanner := bufio.NewScanner(stdout)
	timeout := time.NewTimer(StartupTimeout)
	defer timeout.Stop()

	urlRegex := regexp.MustCompile(`listening at https://[a-zA-Z0-9\-]+\.bore\.pub`)

	for {
		select {
		case <-timeout.C:
			return "", fmt.Errorf("timeout waiting for bore URL")
		case <-c.ctx.Done():
			return "", c.ctx.Err()
		default:
			if !scanner.Scan() {
				if err := scanner.Err(); err != nil {
					return "", fmt.Errorf("error reading bore output: %w", err)
				}
				continue
			}

			line := scanner.Text()
			if match := urlRegex.FindString(line); match != "" {
				// Extract URL from "listening at https://..."
				url := strings.TrimPrefix(match, "listening at ")
				return url, nil
			}
		}
	}
}

// parseLocalhostOutput parses localhost.run output to extract the public URL
func (c *TunnelClient) parseLocalhostOutput(stdout io.Reader) (string, error) {
	scanner := bufio.NewScanner(stdout)
	timeout := time.NewTimer(StartupTimeout)
	defer timeout.Stop()

	// localhost.run shows the URL in various formats, be flexible
	urlRegexes := []*regexp.Regexp{
		regexp.MustCompile(`https://[a-zA-Z0-9\-]+\.lhr\.life`),      // new format: .lhr.life
		regexp.MustCompile(`https://[a-zA-Z0-9\-]+\.localhost\.run`), // old format: .localhost.run
		regexp.MustCompile(`tunneled with tls termination, (https://[a-zA-Z0-9\-]+\.lhr\.life)`),
		regexp.MustCompile(`tunneled with tls termination, (https://[a-zA-Z0-9\-]+\.localhost\.run)`),
		regexp.MustCompile(`your url is: (https://[a-zA-Z0-9\-]+\.(?:lhr\.life|localhost\.run))`),
	}

	for {
		select {
		case <-timeout.C:
			return "", fmt.Errorf("timeout waiting for localhost.run URL")
		case <-c.ctx.Done():
			return "", c.ctx.Err()
		default:
			if !scanner.Scan() {
				if err := scanner.Err(); err != nil {
					return "", fmt.Errorf("error reading localhost.run output: %w", err)
				}
				continue
			}

			line := scanner.Text()
			c.logger.Info("localhost.run output", "line", line)

			// Try all regex patterns
			for _, regex := range urlRegexes {
				if matches := regex.FindStringSubmatch(line); matches != nil {
					if len(matches) > 1 {
						return matches[1], nil // captured group
					} else {
						return matches[0], nil // full match
					}
				}
			}
		}
	}
}

// isConnected checks if the tunnel is working
func (c *TunnelClient) isConnected(publicURL string) bool {
	// Check if the tunnel is working by making a health check request
	// to our local server through the tunnel
	healthURL, err := url.JoinPath(publicURL, "/health")
	if err != nil {
		return false
	}

	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	resp, err := client.Get(healthURL)
	if err != nil {
		return false
	}
	defer resp.Body.Close()

	return resp.StatusCode == http.StatusOK
}

// Close terminates the tunnel connection
func (c *TunnelClient) Close() error {
	c.cancel()

	if c.cmd != nil && c.cmd.Process != nil {
		if err := c.cmd.Process.Kill(); err != nil {
			c.logger.Warn("Failed to kill tunnel process", "error", err)
		}

		// Wait for process to exit
		c.cmd.Wait()
	}

	return nil
}

// GetTunnelInfo returns information about the current tunnel
func (c *TunnelClient) GetTunnelInfo() TunnelInfo {
	return TunnelInfo{
		PublicURL: c.publicURL,
		Provider:  string(c.provider),
		LocalPort: c.localPort,
	}
}

// VerifyConnection tests the tunnel connection
func VerifyConnection(publicURL string) error {
	healthURL, err := url.JoinPath(publicURL, "/health")
	if err != nil {
		return fmt.Errorf("invalid public URL: %w", err)
	}

	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	resp, err := client.Get(healthURL)
	if err != nil {
		return fmt.Errorf("tunnel connection failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("tunnel health check failed: status %d", resp.StatusCode)
	}

	return nil
}

// InstallInstructions provides installation instructions for tunnel providers
func InstallInstructions() map[TunnelProvider]string {
	return map[TunnelProvider]string{
		ProviderLocal: "localhost.run uses SSH (pre-installed - no setup required!) ⭐ RECOMMENDED",
		ProviderBore:  "Install bore: 'cargo install bore-cli' or download from https://github.com/ekzhang/bore",
		ProviderNgrok: "Install ngrok: https://ngrok.com/download (requires domain registration for free accounts)",
	}
}

// CheckAvailableProviders returns which tunnel providers are available
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

func generateSubdomain() string {
	// Generate random 8-char subdomain
	b := make([]byte, 4)
	if _, err := rand.Read(b); err != nil {
		// Fallback to timestamp-based subdomain
		return fmt.Sprintf("tunnel-%d", time.Now().Unix())
	}
	return fmt.Sprintf("tunnel-%s", hex.EncodeToString(b))
}
