package middleware

import (
	"bytes"
	"compress/gzip"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type echoBody struct {
	Value string `json:"value"`
}

func TestDecodeJSONValid(t *testing.T) {
	body := strings.NewReader(`{"value":"hello"}`)
	req := httptest.NewRequest(http.MethodPost, "/", body)
	req.Header.Set("Content-Type", "application/json")

	var dst echoBody
	if err := DecodeJSON(req, &dst, DefaultDecoderLimits()); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if dst.Value != "hello" {
		t.Errorf("value = %q, want %q", dst.Value, "hello")
	}
}

func TestDecodeJSONTooLarge(t *testing.T) {
	limits := DefaultDecoderLimits()
	limits.MaxBodyBytes = 10

	body := strings.NewReader(`{"value":"this is far too long"}`)
	req := httptest.NewRequest(http.MethodPost, "/", body)

	var dst echoBody
	err := DecodeJSON(req, &dst, limits)
	if err == nil {
		t.Fatal("expected error for oversized body")
	}
	if !strings.Contains(err.Error(), "payload") {
		t.Errorf("error = %q, want payload-too-large", err.Error())
	}
}

func TestDecodeJSONDepthExceeded(t *testing.T) {
	limits := DefaultDecoderLimits()
	limits.MaxJSONDepth = 3

	body := strings.NewReader(`{"a":{"b":{"c":{"d":"deep"}}}}`)
	req := httptest.NewRequest(http.MethodPost, "/", body)

	var dst any
	err := DecodeJSON(req, &dst, limits)
	if err == nil {
		t.Fatal("expected error for excessive depth")
	}
}

func TestDecodeJSONStringTooLong(t *testing.T) {
	limits := DefaultDecoderLimits()
	limits.MaxStringFieldBytes = 4

	body := strings.NewReader(`{"value":"hello"}`)
	req := httptest.NewRequest(http.MethodPost, "/", body)

	var dst echoBody
	err := DecodeJSON(req, &dst, limits)
	if err == nil {
		t.Fatal("expected error for long string")
	}
}

func TestDecodeGzipValid(t *testing.T) {
	var buf bytes.Buffer
	gw := gzip.NewWriter(&buf)
	_, _ = gw.Write([]byte(`{"value":"gzipped"}`))
	gw.Close()

	req := httptest.NewRequest(http.MethodPost, "/", &buf)
	req.Header.Set("Content-Encoding", "gzip")

	var dst echoBody
	if err := DecodeJSON(req, &dst, DefaultDecoderLimits()); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if dst.Value != "gzipped" {
		t.Errorf("value = %q, want %q", dst.Value, "gzipped")
	}
}
