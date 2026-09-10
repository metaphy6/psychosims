// Package api defines the structured error taxonomy for the control plane.
//
// Every endpoint failure is rendered as an ErrorResponse so the Dart client can
// map it to actionable, localized states without parsing ad-hoc strings.
package api

import (
	"encoding/json"
	"fmt"
	"net/http"
)

// ErrorKind classifies errors on the 0.7 taxonomy.
type ErrorKind string

const (
	// ErrUser covers request mistakes the user can correct.
	ErrUser ErrorKind = "user"
	// ErrSystem covers internal server failures.
	ErrSystem ErrorKind = "system"
	// ErrExternal covers dependency failures.
	ErrExternal ErrorKind = "external"
	// ErrOffline covers transient offline / recoverable conditions.
	ErrOffline ErrorKind = "offline"
)

// ErrorCode is a stable machine-readable error code.
type ErrorCode string

const (
	CodeBadRequest         ErrorCode = "bad_request"
	CodeUnauthorized       ErrorCode = "unauthorized"
	CodeForbidden          ErrorCode = "forbidden"
	CodeNotFound           ErrorCode = "not_found"
	CodeConflict           ErrorCode = "conflict"
	CodeRateLimited        ErrorCode = "rate_limited"
	CodeIdempotentReplay   ErrorCode = "idempotent_replay"
	CodeInvalidSignature   ErrorCode = "invalid_signature"
	CodeUnknownRuleset     ErrorCode = "unknown_ruleset"
	CodeSunsetRuleset      ErrorCode = "sunset_ruleset"
	CodeInvalidLedger      ErrorCode = "invalid_ledger"
	CodeOutOfBounds        ErrorCode = "out_of_bounds"
	CodeAnomalyDetected    ErrorCode = "anomaly_detected"
	CodeIllegalTransition  ErrorCode = "illegal_transition"
	CodeLeaseExpired       ErrorCode = "lease_expired"
	CodePayloadTooLarge    ErrorCode = "payload_too_large"
	CodeMalformedPayload   ErrorCode = "malformed_payload"
	CodeInternalError      ErrorCode = "internal_error"
	CodeServiceUnavailable ErrorCode = "service_unavailable"
)

// ErrorResponse is the stable error envelope returned by every endpoint.
type ErrorResponse struct {
	Kind       ErrorKind `json:"kind"`
	Code       ErrorCode `json:"code"`
	Message    string    `json:"message"`
	RetryAfter *int      `json:"retry_after_seconds,omitempty"`
	RequestID  string    `json:"request_id,omitempty"`
}

// Error implements the error interface.
func (e ErrorResponse) Error() string {
	return fmt.Sprintf("%s/%s: %s", e.Kind, e.Code, e.Message)
}

// HTTPError pairs a response with its HTTP status code.
type HTTPError struct {
	Status int
	Body   ErrorResponse
}

// Error implements the error interface.
func (e HTTPError) Error() string {
	return fmt.Sprintf("HTTP %d %s", e.Status, e.Body.Error())
}

// Write writes the error as JSON with the matching status code.
func (e HTTPError) Write(w http.ResponseWriter, requestID string) {
	body := e.Body
	body.RequestID = requestID
	w.Header().Set("Content-Type", "application/json")
	if body.RetryAfter != nil {
		w.Header().Set("Retry-After", fmt.Sprint(*body.RetryAfter))
	}
	w.WriteHeader(e.Status)
	_ = json.NewEncoder(w).Encode(body)
}

// NewError builds an HTTPError for a code/status pair.
func NewError(status int, kind ErrorKind, code ErrorCode, message string) HTTPError {
	return HTTPError{Status: status, Body: ErrorResponse{Kind: kind, Code: code, Message: message}}
}

// NewUserError builds a 400-class user error.
func NewUserError(code ErrorCode, message string) HTTPError {
	return NewError(http.StatusBadRequest, ErrUser, code, message)
}

// NewUnauthorized builds a 401 unauthorized error.
func NewUnauthorized(message string) HTTPError {
	return NewError(http.StatusUnauthorized, ErrUser, CodeUnauthorized, message)
}

// NewForbidden builds a 403 forbidden error.
func NewForbidden(message string) HTTPError {
	return NewError(http.StatusForbidden, ErrUser, CodeForbidden, message)
}

// NewNotFound builds a 404 not-found error.
func NewNotFound(message string) HTTPError {
	return NewError(http.StatusNotFound, ErrUser, CodeNotFound, message)
}

// NewConflict builds a 409 conflict error.
func NewConflict(code ErrorCode, message string) HTTPError {
	return NewError(http.StatusConflict, ErrUser, code, message)
}

// NewRateLimited builds a 429 with Retry-After.
func NewRateLimited(retryAfterSeconds int) HTTPError {
	return HTTPError{
		Status: http.StatusTooManyRequests,
		Body: ErrorResponse{
			Kind:       ErrUser,
			Code:       CodeRateLimited,
			Message:    "rate limit exceeded; retry after the indicated interval",
			RetryAfter: &retryAfterSeconds,
		},
	}
}

// NewPayloadTooLarge builds a 413 payload-too-large error.
func NewPayloadTooLarge(maxBytes int64) HTTPError {
	return NewError(http.StatusRequestEntityTooLarge, ErrUser, CodePayloadTooLarge,
		fmt.Sprintf("request body exceeds %d bytes", maxBytes))
}

// NewMalformedPayload builds a 400 malformed-payload error.
func NewMalformedPayload(message string) HTTPError {
	return NewUserError(CodeMalformedPayload, message)
}

// NewInternalError builds a 500 system error.
func NewInternalError(message string) HTTPError {
	return NewError(http.StatusInternalServerError, ErrSystem, CodeInternalError, message)
}

// NewServiceUnavailable builds a 503 external/offline error.
func NewServiceUnavailable(message string) HTTPError {
	return NewError(http.StatusServiceUnavailable, ErrExternal, CodeServiceUnavailable, message)
}
