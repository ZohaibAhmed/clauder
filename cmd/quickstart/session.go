package quickstart

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"math/big"
)

type Session struct {
	Passcode string
	Token    string
}

// Character set for passcode generation (uppercase letters and numbers, excluding ambiguous characters)
var passcodeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

func generateSession() Session {
	return Session{
		Passcode: generatePasscode(),
		Token:    generateToken(),
	}
}

func generatePasscode() string {
	// Generate a 6-character alphanumeric passcode
	passcode := make([]byte, 6)
	for i := range passcode {
		passcode[i] = passcodeChars[randInt(len(passcodeChars))]
	}
	return string(passcode)
}

func generateToken() string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		panic(fmt.Sprintf("failed to generate random token: %v", err))
	}
	return base64.URLEncoding.EncodeToString(b)
}

func randInt(max int) int {
	n, err := rand.Int(rand.Reader, big.NewInt(int64(max)))
	if err != nil {
		panic(fmt.Sprintf("failed to generate random number: %v", err))
	}
	return int(n.Int64())
}
