package server

import (
	"bytes"
	"encoding/json"
	"os"
	"strings"
	"testing"

	"psychosims.dev/server/internal/offline"
)

func TestReconciliationWireFixture(t *testing.T) {
	accepted := offline.ItemResult{ID: "session_fixture_v1", IdempotencyKey: "rcp_fixture_v1", Status: "accepted", ProfileVersion: 2, RewardStatus: "held_unproven"}
	value := struct {
		Receipt    offline.ItemResult    `json:"receipt"`
		Batch      offline.BatchResponse `json:"batch"`
		Certified  offline.ItemResult    `json:"certified"`
		Unrewarded offline.ItemResult    `json:"certified_unrewarded"`
	}{
		Receipt:    accepted,
		Batch:      offline.BatchResponse{Results: []offline.ItemResult{accepted, {ID: "session_retry_v1", IdempotencyKey: "rcp_retry_v1", Status: "retryable", Retryable: true, Code: "service_unavailable", Message: "temporary failure"}, {ID: "session_later_v1", IdempotencyKey: "rcp_later_v1", Status: "accepted", ProfileVersion: 3, RewardStatus: "held_unproven"}}, QueueDepthHint: 1, Cursor: "rcp_fixture_v1"},
		Certified:  offline.ItemResult{ID: "session_certified_v1", IdempotencyKey: "rcp_fixture_v1", Status: "accepted", ProfileVersion: 4, RewardStatus: "certified", CertificateID: strings.Repeat("c", 64), XPAwarded: 100, StudyAwarded: 3, CashAwarded: 2_500_000},
		Unrewarded: offline.ItemResult{ID: "session_unrewarded_v1", IdempotencyKey: "rcp_fixture_v1", Status: "accepted", ProfileVersion: 5, RewardStatus: "certified_unrewarded", RewardReason: "window_budget", CertificateID: strings.Repeat("c", 64)},
	}
	body, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	body = append(body, '\n')
	path := "testdata/reconciliation.json"
	if os.Getenv("PSY_UPDATE_WIRE_FIXTURES") == "1" {
		if err := os.MkdirAll("testdata", 0755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, body, 0644); err != nil {
			t.Fatal(err)
		}
	}
	want, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(body, want) {
		t.Fatal("reconciliation wire fixture differs from Go output")
	}
}
