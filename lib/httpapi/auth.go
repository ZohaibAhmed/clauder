package httpapi

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"strings"
)

// AuthMiddleware creates a middleware that requires Bearer token authentication
func AuthMiddleware(token string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Skip auth for certain endpoints
			if r.URL.Path == "/health" || strings.HasPrefix(r.URL.Path, "/internal/") {
				next.ServeHTTP(w, r)
				return
			}

			// Skip auth for raw message types (used by attach command)
			if r.URL.Path == "/message" && r.Method == "POST" {
				if isRawMessage(r) {
					next.ServeHTTP(w, r)
					return
				}
			}

			auth := r.Header.Get("Authorization")
			if auth == "" {
				w.Header().Set("WWW-Authenticate", "Bearer")
				http.Error(w, "Authorization required", http.StatusUnauthorized)
				return
			}

			const prefix = "Bearer "
			if !strings.HasPrefix(auth, prefix) {
				http.Error(w, "Invalid authorization format", http.StatusUnauthorized)
				return
			}

			providedToken := auth[len(prefix):]
			if providedToken != token {
				http.Error(w, "Invalid token", http.StatusUnauthorized)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// isRawMessage checks if the request contains a raw message type
func isRawMessage(r *http.Request) bool {
	// Read the body
	body, err := io.ReadAll(r.Body)
	if err != nil {
		return false
	}

	// Restore the body for the next handler
	r.Body = io.NopCloser(bytes.NewBuffer(body))

	// Parse the JSON to check message type
	var msg struct {
		Type string `json:"type"`
	}

	if err := json.Unmarshal(body, &msg); err != nil {
		return false
	}

	return msg.Type == "raw"
}
