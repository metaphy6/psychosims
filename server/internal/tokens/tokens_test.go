package tokens

import (
	"testing"
	"time"
)

func testManager() *Manager {
	secret := make([]byte, 32)
	for i := range secret {
		secret[i] = byte(i)
	}
	return NewManager(secret, time.Minute, time.Hour)
}

func TestIssueAndVerifyAccess(t *testing.T) {
	m := testManager()
	access, _, err := m.IssuePair("acc-1", "player")
	if err != nil {
		t.Fatalf("issue: %v", err)
	}
	claims, err := m.Verify(access)
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if claims.AccountID != "acc-1" {
		t.Errorf("account = %q, want acc-1", claims.AccountID)
	}
	if claims.Role != "player" {
		t.Errorf("role = %q, want player", claims.Role)
	}
	if claims.Kind != KindAccess {
		t.Errorf("kind = %q, want access", claims.Kind)
	}
}

func TestVerifyRejectsRefreshAsAccess(t *testing.T) {
	m := testManager()
	_, refresh, err := m.IssuePair("acc-1", "player")
	if err != nil {
		t.Fatalf("issue: %v", err)
	}
	_, err = m.Verify(refresh)
	if err != ErrInvalidToken {
		t.Errorf("expected invalid token, got %v", err)
	}
}

func TestExpiredAccessRejected(t *testing.T) {
	secret := make([]byte, 32)
	m := NewManager(secret, -time.Hour, time.Hour)
	access, _, err := m.IssuePair("acc-1", "player")
	if err != nil {
		t.Fatalf("issue: %v", err)
	}
	_, err = m.Verify(access)
	if err != ErrTokenExpired {
		t.Errorf("expected expired, got %v", err)
	}
}

func TestRotateRejectsReplay(t *testing.T) {
	m := testManager()
	_, refresh, err := m.IssuePair("acc-1", "player")
	if err != nil {
		t.Fatalf("issue: %v", err)
	}
	_, _, err = m.Rotate(refresh)
	if err != nil {
		t.Fatalf("first rotate: %v", err)
	}
	_, _, err = m.Rotate(refresh)
	if err != ErrTokenRevoked {
		t.Errorf("expected revoked on replay, got %v", err)
	}
}

func TestRevoke(t *testing.T) {
	m := testManager()
	access, _, err := m.IssuePair("acc-1", "player")
	if err != nil {
		t.Fatalf("issue: %v", err)
	}
	claims, _ := m.Verify(access)
	m.Revoke(claims.TokenID)
	_, err = m.Verify(access)
	if err != ErrTokenRevoked {
		t.Errorf("expected revoked, got %v", err)
	}
}
