// Package api defines the versioned HTTP contract shared by the control plane
// and the 0.10 typed Dart client.
//
// The contract is additive-only: new fields may appear, but existing fields and
// response shapes remain stable so older clients degrade safely.
package api

import "net/http"

// Version is the current API version reported in the Psy-API-Version header.
const Version = "v1"

// VersionHeader is the request/response header carrying the API version.
const VersionHeader = "Psy-API-Version"

// CorrelationIDHeader carries the cross-stack correlation id.
const CorrelationIDHeader = "Psy-Correlation-ID"

// IdempotencyKeyHeader carries the idempotency key for mutating requests.
const IdempotencyKeyHeader = "Psy-Idempotency-Key"

// SetVersionHeader writes the API version header on an outgoing response.
func SetVersionHeader(h http.Header) {
	h.Set(VersionHeader, Version)
}
