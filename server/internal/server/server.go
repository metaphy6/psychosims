// Package server holds the HTTP control-plane wiring for Psychosims.
//
// This is the minimal health-check surface stood up in Phase 0.1; the
// authoritative endpoints (identity, receipts, ownership, signing, economy,
// moderation) land in Phase 3.
package server

import (
	"encoding/json"
	"net/http"
)

// Version is the server build version reported by the health endpoint.
const Version = "0.1.0"

// HealthResponse is the payload returned by the health endpoint.
type HealthResponse struct {
	Status  string `json:"status"`
	Version string `json:"version"`
}

// NewMux returns the HTTP handler for the control plane.
func NewMux() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", handleHealth)
	return mux
}

func handleHealth(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(HealthResponse{Status: "ok", Version: Version})
}
