// Package devicekeys revocation list (Phase 3.5).
package devicekeys

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/ctxutil"
)

// RevocationEntry is one revoked key.
type RevocationEntry struct {
	KeyID     string    `json:"key_id"`
	RevokedAt time.Time `json:"revoked_at"`
	Reason    string    `json:"reason,omitempty"`
}

// RevocationList is the published revocation set.
type RevocationList struct {
	ETag      string            `json:"etag"`
	UpdatedAt time.Time         `json:"updated_at"`
	Entries   []RevocationEntry `json:"entries"`
	TTL       time.Duration     `json:"ttl_seconds"`
}

// ListRepository abstracts revocation-list persistence.
type ListRepository interface {
	Get(ctx context.Context) (*RevocationList, error)
	Put(ctx context.Context, list *RevocationList) error
}

// MemoryListRepository is a test revocation-list store.
type MemoryListRepository struct {
	list *RevocationList
}

// NewMemoryListRepository creates a test revocation-list store.
func NewMemoryListRepository() *MemoryListRepository {
	return &MemoryListRepository{list: &RevocationList{Entries: []RevocationEntry{}, UpdatedAt: time.Now().UTC()}}
}

// Get implements ListRepository.
func (r *MemoryListRepository) Get(ctx context.Context) (*RevocationList, error) {
	return r.list, nil
}

// Put implements ListRepository.
func (r *MemoryListRepository) Put(ctx context.Context, list *RevocationList) error {
	r.list = list
	return nil
}

// BuildRevocationList assembles the current list of revoked device keys.
func (s *Service) BuildRevocationList(ctx context.Context, ttl time.Duration) (*RevocationList, error) {
	// In-memory scan: production queries revoked rows directly.
	entries, err := s.repo.ListRevoked(ctx)
	if err != nil {
		return nil, err
	}
	list := &RevocationList{
		Entries:   entries,
		UpdatedAt: time.Now().UTC(),
		TTL:       ttl,
	}
	list.ETag = revocationETag(list)
	return list, nil
}

func revocationETag(list *RevocationList) string {
	h := sha256.New()
	fmt.Fprintf(h, "%d|%d", list.UpdatedAt.Unix(), len(list.Entries))
	return "\"" + hex.EncodeToString(h.Sum(nil)[:8]) + "\""
}

// RevocationHandler serves the revocation list with ETag / TTL caching.
func RevocationHandler(svc *Service, ttl time.Duration) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		list, err := svc.BuildRevocationList(r.Context(), ttl)
		if err != nil {
			api.NewInternalError("revocation list failed: " + err.Error()).Write(w, ctxutil.RequestID(r.Context()))
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("ETag", list.ETag)
		w.Header().Set("Cache-Control", fmt.Sprintf("max-age=%d", int(ttl.Seconds())))
		if r.Header.Get("If-None-Match") == list.ETag {
			w.WriteHeader(http.StatusNotModified)
			return
		}
		w.WriteHeader(http.StatusOK)
		_ = json.NewEncoder(w).Encode(list)
	})
}
