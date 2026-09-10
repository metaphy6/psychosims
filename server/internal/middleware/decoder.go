// Package middleware holds HTTP middleware for the control plane: request
// context, idempotency, defensive decoding, rate limiting, and tracing.
package middleware

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"psychosims.dev/server/internal/api"
)

// DecoderLimits bounds untrusted request bodies at the trust boundary.
type DecoderLimits struct {
	MaxBodyBytes        int64
	MaxJSONDepth        int
	MaxStringFieldBytes int64
	MaxArrayLength      int
	MaxObjectKeys       int
	AllowGzip           bool
}

// DefaultDecoderLimits returns the production limits used by receipt endpoints.
func DefaultDecoderLimits() DecoderLimits {
	return DecoderLimits{
		MaxBodyBytes:        1 << 20, // 1 MiB
		MaxJSONDepth:        32,
		MaxStringFieldBytes: 1024,
		MaxArrayLength:      1024,
		MaxObjectKeys:       256,
		AllowGzip:           true,
	}
}

// DecodeJSON reads and validates a request body, then decodes it into dst.
// It applies size, depth, string-length, and array/object-count caps before
// full parsing so a hostile payload fails closed.
func DecodeJSON(r *http.Request, dst any, limits DecoderLimits) error {
	if r.Body == nil {
		return api.NewUserError(api.CodeBadRequest, "missing request body")
	}

	// Decompress if gzipped.
	if encoding := r.Header.Get("Content-Encoding"); encoding != "" && encoding != "identity" && encoding != "gzip" {
		return api.NewMalformedPayload("unsupported content encoding")
	}
	var bodyReader io.Reader = io.LimitReader(r.Body, limits.MaxBodyBytes+1)
	if r.Header.Get("Content-Encoding") == "gzip" {
		if !limits.AllowGzip {
			return api.NewUserError(api.CodeMalformedPayload, "gzip not accepted")
		}
		gr, err := gzip.NewReader(bodyReader)
		if err != nil {
			return api.NewMalformedPayload("invalid gzip body: " + err.Error())
		}
		defer gr.Close()
		bodyReader = io.LimitReader(gr, limits.MaxBodyBytes+1)
	}

	body, err := io.ReadAll(bodyReader)
	if err != nil {
		return api.NewMalformedPayload("cannot read body: " + err.Error())
	}
	if int64(len(body)) > limits.MaxBodyBytes {
		return api.NewPayloadTooLarge(limits.MaxBodyBytes)
	}

	// Validate structure and bounds before unmarshalling into dst.
	if err := checkObjectKeys(json.NewDecoder(bytes.NewReader(body)), 1, limits); err != nil {
		return err
	}
	var raw any
	if err := json.Unmarshal(body, &raw); err != nil {
		return api.NewMalformedPayload("invalid json: " + err.Error())
	}
	if _, ok := raw.(map[string]any); !ok {
		return api.NewMalformedPayload("JSON object required")
	}
	if err := validateJSONGraph(raw, 1, limits); err != nil {
		return err
	}

	// Decode into the typed destination.
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		return api.NewMalformedPayload("decode error: " + err.Error())
	}
	return nil
}

func checkObjectKeys(dec *json.Decoder, depth int, limits DecoderLimits) error {
	if depth > limits.MaxJSONDepth {
		return api.NewMalformedPayload("JSON nesting exceeds limit")
	}
	tok, err := dec.Token()
	if err != nil {
		return api.NewMalformedPayload("invalid JSON")
	}
	delim, ok := tok.(json.Delim)
	if !ok {
		return nil
	}
	switch delim {
	case '{':
		seen := map[string]bool{}
		for dec.More() {
			key, err := dec.Token()
			if err != nil {
				return api.NewMalformedPayload("invalid object key")
			}
			name, ok := key.(string)
			if !ok || seen[name] || int64(len(name)) > limits.MaxStringFieldBytes {
				return api.NewMalformedPayload("duplicate or invalid object key")
			}
			seen[name] = true
			if len(seen) > limits.MaxObjectKeys {
				return api.NewMalformedPayload("too many object keys")
			}
			if err := checkObjectKeys(dec, depth+1, limits); err != nil {
				return err
			}
		}
	case '[':
		count := 0
		for dec.More() {
			count++
			if count > limits.MaxArrayLength {
				return api.NewMalformedPayload("too many array entries")
			}
			if err := checkObjectKeys(dec, depth+1, limits); err != nil {
				return err
			}
		}
	default:
		return api.NewMalformedPayload("invalid JSON delimiter")
	}
	if _, err := dec.Token(); err != nil {
		return api.NewMalformedPayload("invalid JSON terminator")
	}
	return nil
}

func validateJSONGraph(v any, depth int, limits DecoderLimits) error {
	if depth > limits.MaxJSONDepth {
		return api.NewMalformedPayload(fmt.Sprintf("json depth exceeds %d", limits.MaxJSONDepth))
	}

	switch val := v.(type) {
	case string:
		if int64(len(val)) > limits.MaxStringFieldBytes {
			return api.NewMalformedPayload(fmt.Sprintf("string field exceeds %d bytes", limits.MaxStringFieldBytes))
		}
	case map[string]any:
		if len(val) > limits.MaxObjectKeys {
			return api.NewMalformedPayload(fmt.Sprintf("object has more than %d keys", limits.MaxObjectKeys))
		}
		for _, child := range val {
			if err := validateJSONGraph(child, depth+1, limits); err != nil {
				return err
			}
		}
	case []any:
		if len(val) > limits.MaxArrayLength {
			return api.NewMalformedPayload(fmt.Sprintf("array has more than %d elements", limits.MaxArrayLength))
		}
		for _, child := range val {
			if err := validateJSONGraph(child, depth+1, limits); err != nil {
				return err
			}
		}
	case float64, bool, nil:
		// OK
	default:
		return api.NewMalformedPayload("unsupported json value type")
	}
	return nil
}
