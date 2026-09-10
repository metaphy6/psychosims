package middleware

import (
	"net/http"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/ctxutil"
)

// RequestContext extracts or generates correlation/request ids and attaches
// them to the request context. It is the server-side half of the 0.7
// identifier convention.
func RequestContext(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		correlationID := r.Header.Get(api.CorrelationIDHeader)
		if !validIdentifier(correlationID) || !validIdentifier(r.Header.Get(api.IdempotencyKeyHeader)) {
			api.SetVersionHeader(w.Header())
			api.NewUserError(api.CodeBadRequest, "invalid request identifier").Write(w, ctxutil.GenerateID())
			return
		}
		if correlationID == "" {
			correlationID = ctxutil.GenerateID()
		}
		requestID := ctxutil.GenerateID()

		ctx := r.Context()
		ctx = ctxutil.WithCorrelationID(ctx, correlationID)
		ctx = ctxutil.WithRequestID(ctx, requestID)
		ctx = ctxutil.WithIdempotencyKey(ctx, r.Header.Get(api.IdempotencyKeyHeader))

		w.Header().Set(api.CorrelationIDHeader, correlationID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// RequireIdempotencyKey rejects mutating requests that omit the idempotency
// header. It must be applied after RequestContext.
func RequireIdempotencyKey(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost || r.Method == http.MethodPut || r.Method == http.MethodPatch || r.Method == http.MethodDelete {
			if ctxutil.IdempotencyKey(r.Context()) == "" {
				api.NewUserError(api.CodeBadRequest, "missing "+api.IdempotencyKeyHeader+" header").Write(w, ctxutil.RequestID(r.Context()))
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}

// APIVersion validates or reports the API version header on every response.
func APIVersion(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		api.SetVersionHeader(w.Header())
		if version := r.Header.Get(api.VersionHeader); version != "" && version != api.Version {
			api.NewUserError(api.CodeBadRequest, "unsupported API version").Write(w, ctxutil.RequestID(r.Context()))
			return
		}
		next.ServeHTTP(w, r)
	})
}

func validIdentifier(s string) bool {
	if len(s) > 128 {
		return false
	}
	for _, c := range s {
		if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.' || c == ':') {
			return false
		}
	}
	return true
}
