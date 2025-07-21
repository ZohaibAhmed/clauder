package coordinator

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

const (
	// Default coordinator service URL (can be overridden with COORDINATOR_URL env var)
	DefaultCoordinatorURL = "https://coordinator.claudecode.app"
	ClientTimeout         = 10 * time.Second
)

// getCoordinatorURL returns the coordinator URL from environment or default
func getCoordinatorURL() string {
	if url := os.Getenv("COORDINATOR_URL"); url != "" {
		return url
	}
	return DefaultCoordinatorURL
}

type RegisterRequest struct {
	Passcode  string `json:"passcode"`
	TunnelURL string `json:"tunnel_url"`
	Token     string `json:"token"`
}

type RegisterResponse struct {
	Success   bool   `json:"success"`
	Passcode  string `json:"passcode"`
	ExpiresIn int    `json:"expires_in"`
	Error     string `json:"error,omitempty"`
}

type LookupResponse struct {
	TunnelURL string `json:"tunnel_url"`
	Token     string `json:"token"`
	Error     string `json:"error,omitempty"`
}

// Register registers a new session with the coordinator service
func Register(passcode, tunnelURL, token string) error {
	client := &http.Client{
		Timeout: ClientTimeout,
	}

	reqBody := RegisterRequest{
		Passcode:  passcode,
		TunnelURL: tunnelURL,
		Token:     token,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return fmt.Errorf("failed to marshal request: %w", err)
	}

	url := fmt.Sprintf("%s/register", getCoordinatorURL())
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to make request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read response: %w", err)
	}

	var registerResp RegisterResponse
	if err := json.Unmarshal(body, &registerResp); err != nil {
		return fmt.Errorf("failed to unmarshal response: %w", err)
	}

	if !registerResp.Success {
		return fmt.Errorf("registration failed: %s", registerResp.Error)
	}

	fmt.Printf("✅ Session registered with coordinator: %s\n", passcode)
	return nil
}

// Lookup retrieves session details for a given passcode
func Lookup(passcode string) (*LookupResponse, error) {
	client := &http.Client{
		Timeout: ClientTimeout,
	}

	url := fmt.Sprintf("%s/lookup/%s", getCoordinatorURL(), passcode)
	resp, err := client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to make request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	var lookupResp LookupResponse
	if err := json.Unmarshal(body, &lookupResp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("lookup failed: %s", lookupResp.Error)
	}

	return &lookupResp, nil
}
