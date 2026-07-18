// Package ctxutil carries request-scoped metadata through context.Context.
//
// This is the server analog of the 0.7 identifier conventions: correlation id,
// idempotency key, and authenticated account id.
package ctxutil

import (
	"context"
	"crypto/rand"
	"encoding/hex"
)

type ctxKey int

const (
	correlationIDKey ctxKey = iota
	idempotencyKeyKey
	accountIDKey
	requestIDKey
)

// CorrelationID returns the correlation id from ctx, or "" if absent.
func CorrelationID(ctx context.Context) string {
	v, _ := ctx.Value(correlationIDKey).(string)
	return v
}

// WithCorrelationID returns ctx with the correlation id attached.
func WithCorrelationID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, correlationIDKey, id)
}

// IdempotencyKey returns the idempotency key from ctx, or "" if absent.
func IdempotencyKey(ctx context.Context) string {
	v, _ := ctx.Value(idempotencyKeyKey).(string)
	return v
}

// WithIdempotencyKey returns ctx with the idempotency key attached.
func WithIdempotencyKey(ctx context.Context, key string) context.Context {
	return context.WithValue(ctx, idempotencyKeyKey, key)
}

// AccountID returns the authenticated account id from ctx, or "" if absent.
func AccountID(ctx context.Context) string {
	v, _ := ctx.Value(accountIDKey).(string)
	return v
}

// WithAccountID returns ctx with the account id attached.
func WithAccountID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, accountIDKey, id)
}

// RequestID returns the server-generated request id from ctx, or "" if absent.
func RequestID(ctx context.Context) string {
	v, _ := ctx.Value(requestIDKey).(string)
	return v
}

// WithRequestID returns ctx with the request id attached.
func WithRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, requestIDKey, id)
}

// GenerateID creates a short random hex id for request idempotency keys or
// request ids.
func GenerateID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
