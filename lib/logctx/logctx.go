package logctx

import (
	"context"
	"log/slog"
)

type contextKey int

const (
	loggerKey contextKey = iota
)

// WithLogger returns a new context with the provided logger
func WithLogger(ctx context.Context, logger *slog.Logger) context.Context {
	return context.WithValue(ctx, loggerKey, logger)
}

// From retrieves the logger from the context or panics if no logger is found
func From(ctx context.Context) *slog.Logger {
	if logger, ok := ctx.Value(loggerKey).(*slog.Logger); ok {
		return logger
	}
	panic("no logger found in context")
}
