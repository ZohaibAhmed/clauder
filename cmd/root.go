package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/zohaibahmed/clauder/cmd/attach"
	"github.com/zohaibahmed/clauder/cmd/quickstart"
	"github.com/zohaibahmed/clauder/cmd/server"
)

var rootCmd = &cobra.Command{
	Use:     "clauder",
	Short:   "Clauder CLI",
	Long:    `Clauder - HTTP API for Claude Code, Goose, Aider, and Codex`,
	Version: "0.2.3",
}

func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.AddCommand(server.ServerCmd)
	rootCmd.AddCommand(attach.AttachCmd)
	rootCmd.AddCommand(quickstart.QuickstartCmd)
}
