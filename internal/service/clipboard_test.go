package service

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/repository"
)

// ── In-memory stubs ───────────────────────────────────────────────────────────

type stubClipboardStore struct {
	mu      sync.Mutex
	entries []*repository.ClipboardEntry
}

func (s *stubClipboardStore) Create(ctx context.Context, e *repository.ClipboardEntry) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	e.CreatedAt = time.Now()
	s.entries = append(s.entries, e)
	return nil
}

func (s *stubClipboardStore) FindByID(ctx context.Context, id, userID uuid.UUID) (*repository.ClipboardEntry, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, e := range s.entries {
		if e.ID == id && e.UserID == userID {
			if e.ExpiresAt != nil && e.ExpiresAt.Before(time.Now()) {
				return nil, repository.ErrNotFound
			}
			return e, nil
		}
	}
	return nil, repository.ErrNotFound
}

func (s *stubClipboardStore) FindByContentHash(ctx context.Context, userID uuid.UUID, hash string) (*repository.ClipboardEntry, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := len(s.entries) - 1; i >= 0; i-- {
		e := s.entries[i]
		if e.UserID == userID && e.ContentHash == hash {
			if e.ExpiresAt != nil && e.ExpiresAt.Before(time.Now()) {
				continue
			}
			return e, nil
		}
	}
	return nil, repository.ErrNotFound
}

func (s *stubClipboardStore) FindLatestByUser(ctx context.Context, userID uuid.UUID, limit int) ([]*repository.ClipboardEntry, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var out []*repository.ClipboardEntry
	// Iterate in reverse (newest first).
	for i := len(s.entries) - 1; i >= 0; i-- {
		e := s.entries[i]
		if e.UserID != userID {
			continue
		}
		if e.ExpiresAt != nil && e.ExpiresAt.Before(time.Now()) {
			continue
		}
		out = append(out, e)
		if len(out) >= limit {
			break
		}
	}
	return out, nil
}

func (s *stubClipboardStore) FindByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*repository.ClipboardEntry, int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var all []*repository.ClipboardEntry
	for i := len(s.entries) - 1; i >= 0; i-- {
		e := s.entries[i]
		if e.UserID == userID {
			if e.ExpiresAt == nil || !e.ExpiresAt.Before(time.Now()) {
				all = append(all, e)
			}
		}
	}
	total := len(all)
	if offset >= total {
		return nil, total, nil
	}
	end := offset + limit
	if end > total {
		end = total
	}
	return all[offset:end], total, nil
}

func (s *stubClipboardStore) DeleteByID(ctx context.Context, id, userID uuid.UUID) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, e := range s.entries {
		if e.ID == id && e.UserID == userID && !e.Pinned {
			now := time.Now()
			e.ExpiresAt = &now
			return nil
		}
	}
	return repository.ErrNotFound
}

func (s *stubClipboardStore) SetPinned(ctx context.Context, id, userID uuid.UUID, pinned bool, retentionMinutes int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, e := range s.entries {
		if e.ID == id && e.UserID == userID {
			e.Pinned = pinned
			if pinned {
				now := time.Now()
				e.PinnedAt = &now
				e.ExpiresAt = nil
			} else {
				e.PinnedAt = nil
				t := time.Now().Add(time.Duration(retentionMinutes) * time.Minute)
				e.ExpiresAt = &t
			}
			return nil
		}
	}
	return repository.ErrNotFound
}

func (s *stubClipboardStore) SumUnpinnedBytes(_ context.Context, userID uuid.UUID) (int64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var n int64
	for _, e := range s.entries {
		if e.UserID == userID && !e.Pinned {
			n += int64(e.PlaintextSize)
		}
	}
	return n, nil
}

func (s *stubClipboardStore) FindOldestUnpinned(_ context.Context, userID uuid.UUID) (*repository.ClipboardEntry, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var oldest *repository.ClipboardEntry
	for _, e := range s.entries {
		if e.UserID == userID && !e.Pinned {
			if oldest == nil || e.CreatedAt.Before(oldest.CreatedAt) {
				oldest = e
			}
		}
	}
	if oldest == nil {
		return nil, repository.ErrNotFound
	}
	return oldest, nil
}

func (s *stubClipboardStore) HardDelete(_ context.Context, id, userID uuid.UUID) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, e := range s.entries {
		if e.ID == id && e.UserID == userID {
			s.entries = append(s.entries[:i], s.entries[i+1:]...)
			return nil
		}
	}
	return repository.ErrNotFound
}

// ──────────────────────────────────────────────────────────────────────────────

type stubHub struct {
	mu         sync.Mutex
	broadcasts []broadcastRecord
}

type broadcastRecord struct {
	userID        uuid.UUID
	data          []byte
	excludeDevice *uuid.UUID
}

func (h *stubHub) Broadcast(userID uuid.UUID, data []byte, excludeDevice *uuid.UUID) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.broadcasts = append(h.broadcasts, broadcastRecord{userID, data, excludeDevice})
}

// ── Test helpers ──────────────────────────────────────────────────────────────

const testKEK = "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"

// stubSettingsStore returns the default (120-minute) settings for any user.
type stubSettingsStore struct{}

func (s *stubSettingsStore) Get(_ context.Context, userID uuid.UUID) (*repository.UserSettings, error) {
	return &repository.UserSettings{UserID: userID, RetentionMinutes: 120}, nil
}

func newTestService(t *testing.T) (*ClipboardService, *stubClipboardStore, *stubHub) {
	t.Helper()
	store := &stubClipboardStore{}
	hub := &stubHub{}
	svc := NewClipboardService(store, &stubSettingsStore{}, hub, nil, nil, 10, 120, 1<<30)
	return svc, store, hub
}

// ── Tests ─────────────────────────────────────────────────────────────────────

func TestSync_Success(t *testing.T) {
	svc, _, hub := newTestService(t)

	userID := uuid.New()
	deviceID := uuid.New()

	entry, deduped, err := svc.Sync(context.Background(), userID, deviceID, "text/plain", "hello world")
	if err != nil {
		t.Fatalf("Sync error: %v", err)
	}
	if deduped {
		t.Error("expected deduplicated=false for first sync")
	}
	if entry.Content != "hello world" {
		t.Errorf("content mismatch: got %q", entry.Content)
	}
	if entry.ContentType != "text/plain" {
		t.Errorf("content type mismatch: got %q", entry.ContentType)
	}
	if entry.PlaintextSize != len("hello world") {
		t.Errorf("plaintext_size: got %d, want %d", entry.PlaintextSize, len("hello world"))
	}

	// Hub should have received a broadcast to other devices.
	hub.mu.Lock()
	n := len(hub.broadcasts)
	hub.mu.Unlock()
	if n == 0 {
		t.Error("expected WS broadcast; none received")
	}
}

func TestSync_Deduplication(t *testing.T) {
	svc, _, _ := newTestService(t)

	userID := uuid.New()
	deviceID := uuid.New()

	const text = "duplicate me"
	first, deduped1, err := svc.Sync(context.Background(), userID, deviceID, "text/plain", text)
	if err != nil || deduped1 {
		t.Fatalf("first sync: err=%v deduped=%v", err, deduped1)
	}

	second, deduped2, err := svc.Sync(context.Background(), userID, deviceID, "text/plain", text)
	if err != nil {
		t.Fatalf("second sync: %v", err)
	}
	if !deduped2 {
		t.Error("expected deduplicated=true on second sync with same content")
	}
	if first.ID != second.ID {
		t.Errorf("dedup should return same entry ID: %q vs %q", first.ID, second.ID)
	}
}

func TestSync_InvalidContentType(t *testing.T) {
	svc, _, _ := newTestService(t)

	_, _, err := svc.Sync(context.Background(), uuid.New(), uuid.New(), "image/png", "somedata")
	if !errors.Is(err, ErrUnsupportedContentType) {
		t.Errorf("expected ErrUnsupportedContentType, got %v", err)
	}
}

func TestSync_ContentTooLarge(t *testing.T) {
	svc, _, _ := newTestService(t)

	// Build content that exceeds the 10MB limit.
	big := make([]byte, 11*1024*1024)
	for i := range big {
		big[i] = 'A'
	}

	_, _, err := svc.Sync(context.Background(), uuid.New(), uuid.New(), "text/plain", string(big))
	if !errors.Is(err, ErrContentTooLarge) {
		t.Errorf("expected ErrContentTooLarge, got %v", err)
	}
}

func TestSync_AllContentTypes(t *testing.T) {
	svc, _, _ := newTestService(t)
	userID := uuid.New()
	deviceID := uuid.New()

	cases := []struct {
		ct      string
		content string
	}{
		{"text/plain", "plain text"},
		{"text/uri-list", "https://example.com\nhttps://another.com"},
		{"text/html", "<b>bold</b>"},
		{"text/rtf", `{\rtf1\ansi hello}`},
		{"image/png", "iVBORw0KGgo="},
		{"image/jpeg", "/9j/4AAQ"},
	}
	for _, tc := range cases {
		t.Run(tc.ct, func(t *testing.T) {
			entry, _, err := svc.Sync(context.Background(), userID, deviceID, tc.ct, tc.content)
			if err != nil {
				t.Fatalf("Sync(%s): %v", tc.ct, err)
			}
			if entry.Content != tc.content {
				t.Errorf("content roundtrip mismatch for %s: got %q", tc.ct, entry.Content)
			}
		})
	}
}

func TestGetCurrent_LWW(t *testing.T) {
	svc, _, _ := newTestService(t)

	userID := uuid.New()
	deviceA := uuid.New()
	deviceB := uuid.New()

	// Device A syncs first.
	_, _, err := svc.Sync(context.Background(), userID, deviceA, "text/plain", "from device A")
	if err != nil {
		t.Fatalf("sync A: %v", err)
	}
	// Device B syncs after — should become the current.
	time.Sleep(time.Millisecond) // ensure B has a later timestamp
	_, _, err = svc.Sync(context.Background(), userID, deviceB, "text/plain", "from device B")
	if err != nil {
		t.Fatalf("sync B: %v", err)
	}

	current, err := svc.GetCurrent(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetCurrent: %v", err)
	}
	if current.Content != "from device B" {
		t.Errorf("LWW: expected 'from device B', got %q", current.Content)
	}
}

func TestGetCurrent_Empty(t *testing.T) {
	svc, _, _ := newTestService(t)

	_, err := svc.GetCurrent(context.Background(), uuid.New())
	if !errors.Is(err, ErrClipboardNotFound) {
		t.Errorf("expected ErrClipboardNotFound, got %v", err)
	}
}

func TestGetHistory_Pagination(t *testing.T) {
	svc, _, _ := newTestService(t)

	userID := uuid.New()
	deviceID := uuid.New()
	for i := 0; i < 5; i++ {
		_, _, err := svc.Sync(context.Background(), userID, deviceID, "text/plain",
			uuid.New().String(), // unique content each time
		)
		if err != nil {
			t.Fatalf("sync %d: %v", i, err)
		}
	}

	page1, err := svc.GetHistory(context.Background(), userID, 3, 0)
	if err != nil {
		t.Fatalf("GetHistory p1: %v", err)
	}
	if len(page1.Entries) != 3 {
		t.Errorf("page1: want 3 entries, got %d", len(page1.Entries))
	}
	if page1.Total != 5 {
		t.Errorf("total: want 5, got %d", page1.Total)
	}
	if !page1.HasMore {
		t.Error("page1 should have HasMore=true")
	}

	page2, err := svc.GetHistory(context.Background(), userID, 3, 3)
	if err != nil {
		t.Fatalf("GetHistory p2: %v", err)
	}
	if len(page2.Entries) != 2 {
		t.Errorf("page2: want 2 entries, got %d", len(page2.Entries))
	}
	if page2.HasMore {
		t.Error("page2 should have HasMore=false")
	}
}

func TestGetByID_NotFound(t *testing.T) {
	svc, _, _ := newTestService(t)

	_, err := svc.GetByID(context.Background(), uuid.New(), uuid.New())
	if !errors.Is(err, ErrClipboardNotFound) {
		t.Errorf("expected ErrClipboardNotFound, got %v", err)
	}
}

func TestDelete_Pinned(t *testing.T) {
	svc, _, _ := newTestService(t)

	userID := uuid.New()
	deviceID := uuid.New()

	entry, _, err := svc.Sync(context.Background(), userID, deviceID, "text/plain", "to pin")
	if err != nil {
		t.Fatalf("sync: %v", err)
	}

	id, _ := parseUUID(t, entry.ID)
	if err := svc.Pin(context.Background(), userID, id, true); err != nil {
		t.Fatalf("pin: %v", err)
	}

	// Pinned entries must not be deletable via DeleteByID.
	err = svc.Delete(context.Background(), userID, id)
	if !errors.Is(err, ErrClipboardNotFound) {
		t.Errorf("expected ErrClipboardNotFound on pinned delete, got %v", err)
	}
}

func TestPin_Roundtrip(t *testing.T) {
	svc, _, _ := newTestService(t)

	userID := uuid.New()
	deviceID := uuid.New()

	entry, _, err := svc.Sync(context.Background(), userID, deviceID, "text/plain", "will be pinned")
	if err != nil {
		t.Fatalf("sync: %v", err)
	}
	id, _ := parseUUID(t, entry.ID)

	if err := svc.Pin(context.Background(), userID, id, true); err != nil {
		t.Fatalf("pin true: %v", err)
	}

	fetched, err := svc.GetByID(context.Background(), userID, id)
	if err != nil {
		t.Fatalf("get after pin: %v", err)
	}
	if !fetched.Pinned {
		t.Error("expected Pinned=true")
	}

	if err := svc.Pin(context.Background(), userID, id, false); err != nil {
		t.Fatalf("unpin: %v", err)
	}
	fetched2, _ := svc.GetByID(context.Background(), userID, id)
	if fetched2.Pinned {
		t.Error("expected Pinned=false after unpin")
	}
}

func TestBroadcastExcludesSender(t *testing.T) {
	svc, _, hub := newTestService(t)

	userID := uuid.New()
	deviceID := uuid.New()

	_, _, err := svc.Sync(context.Background(), userID, deviceID, "text/plain", "check exclusion")
	if err != nil {
		t.Fatalf("sync: %v", err)
	}

	hub.mu.Lock()
	defer hub.mu.Unlock()
	if len(hub.broadcasts) == 0 {
		t.Fatal("expected a broadcast")
	}
	bc := hub.broadcasts[0]
	if bc.excludeDevice == nil || *bc.excludeDevice != deviceID {
		t.Errorf("broadcast should exclude sender %s", deviceID)
	}
}

// ── test helpers ──────────────────────────────────────────────────────────────

func parseUUID(t *testing.T, s string) (uuid.UUID, bool) {
	t.Helper()
	id, err := uuid.Parse(s)
	if err != nil {
		t.Fatalf("parseUUID(%q): %v", s, err)
	}
	return id, true
}
