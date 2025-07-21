package main

import (
	"log"

	"github.com/joho/godotenv"
	"github.com/zohaibahmed/clauder/cmd"
)

func main() {
	// Load .env file if it exists (fail silently if it doesn't)
	if err := godotenv.Load(); err != nil {
		// Only log if it's not a "file not found" error
		if !isFileNotFoundError(err) {
			log.Printf("Warning: Error loading .env file: %v", err)
		}
	}

	cmd.Execute()
}

// isFileNotFoundError checks if the error is due to .env file not existing
func isFileNotFoundError(err error) bool {
	return err != nil && (err.Error() == "open .env: no such file or directory" || 
		err.Error() == "open .env: The system cannot find the file specified.")
}
