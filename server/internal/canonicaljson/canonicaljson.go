// Package canonicaljson mirrors Dart's packages/psychemas CanonicalJson encoder.
//
// It produces byte-identical output: deterministic key sorting (lexicographic),
// snake_case keys preserved, no extra whitespace, stable number/string/bool/null
// encoding. This is the byte format signatures are computed over, so the Go
// server can verify Dart-signed receipts without re-canonicalization.
package canonicaljson

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strconv"
	"strings"
)

// Encode marshals v to canonical UTF-8 bytes.
func Encode(v any) ([]byte, error) {
	var buf bytes.Buffer
	if err := encode(&buf, v); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

// EncodeString marshals v to a canonical JSON string.
func EncodeString(v any) (string, error) {
	b, err := Encode(v)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

func encode(w *bytes.Buffer, v any) error {
	switch val := v.(type) {
	case nil:
		w.WriteString("null")
	case string:
		encodeString(w, val)
	case bool:
		if val {
			w.WriteString("true")
		} else {
			w.WriteString("false")
		}
	case float32:
		if err := encodeFloat(w, float64(val)); err != nil {
			return err
		}
	case float64:
		if err := encodeFloat(w, val); err != nil {
			return err
		}
	case int:
		w.WriteString(strconv.FormatInt(int64(val), 10))
	case int8:
		w.WriteString(strconv.FormatInt(int64(val), 10))
	case int16:
		w.WriteString(strconv.FormatInt(int64(val), 10))
	case int32:
		w.WriteString(strconv.FormatInt(int64(val), 10))
	case int64:
		w.WriteString(strconv.FormatInt(val, 10))
	case uint:
		w.WriteString(strconv.FormatUint(uint64(val), 10))
	case uint8:
		w.WriteString(strconv.FormatUint(uint64(val), 10))
	case uint16:
		w.WriteString(strconv.FormatUint(uint64(val), 10))
	case uint32:
		w.WriteString(strconv.FormatUint(uint64(val), 10))
	case uint64:
		w.WriteString(strconv.FormatUint(val, 10))
	case []any:
		w.WriteByte('[')
		for i, item := range val {
			if i > 0 {
				w.WriteByte(',')
			}
			if err := encode(w, item); err != nil {
				return err
			}
		}
		w.WriteByte(']')
	case map[string]any:
		keys := make([]string, 0, len(val))
		for k := range val {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		w.WriteByte('{')
		for i, k := range keys {
			if i > 0 {
				w.WriteByte(',')
			}
			encodeString(w, k)
			w.WriteByte(':')
			if err := encode(w, val[k]); err != nil {
				return err
			}
		}
		w.WriteByte('}')
	default:
		return fmt.Errorf("canonical json cannot encode %T", v)
	}
	return nil
}

func encodeString(w *bytes.Buffer, s string) {
	b, _ := json.Marshal(s)
	w.Write(b)
}

func encodeFloat(w *bytes.Buffer, v float64) error {
	if v != v || v > 1.7976931348623157e+308 || v < -1.7976931348623157e+308 {
		return errors.New("canonical json rejects non-finite doubles")
	}
	s := strconv.FormatFloat(v, 'f', -1, 64)
	// Trim trailing zeros after decimal if any, matching Dart behavior.
	if strings.Contains(s, ".") {
		s = strings.TrimRight(s, "0")
		if strings.HasSuffix(s, ".") {
			s = s[:len(s)-1]
		}
	}
	w.WriteString(s)
	return nil
}

// Marshal converts a typed Go value to its canonical JSON bytes by first
// marshalling with encoding/json to a generic graph, then canonicalizing.
func Marshal(v any) ([]byte, error) {
	std, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	var graph any
	if err := json.Unmarshal(std, &graph); err != nil {
		return nil, err
	}
	return Encode(graph)
}

// Decode parses canonical UTF-8 bytes back to a generic JSON graph.
func Decode(data []byte) (any, error) {
	var v any
	if err := json.Unmarshal(data, &v); err != nil {
		return nil, err
	}
	return v, nil
}

// DecodeInto parses canonical UTF-8 bytes into a typed value.
func DecodeInto(data []byte, dst any) error {
	return json.Unmarshal(data, dst)
}
