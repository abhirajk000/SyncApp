package service

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/repository"
	"github.com/syncbridge/api/internal/thumbnail"
)

// ── stubs ─────────────────────────────────────────────────────────────────────

// stubFileStore is a thread-safe in-memory file store.
type stubFileStore struct {
	mu    sync.Mutex
	files map[uuid.UUID]*repository.File
}

func newStubFileStore() *stubFileStore { return &stubFileStore{files: map[uuid.UUID]*repository.File{}} }

func (s *stubFileStore) Create(_ context.Context, f *repository.File) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.files[f.ID] = f
	return nil
}
func (s *stubFileStore) FindByID(_ context.Context, id, userID uuid.UUID) (*repository.File, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	f, ok := s.files[id]
	if !ok || f.UserID != userID {
		return nil, repository.ErrNotFound
	}
	return f, nil
}
func (s *stubFileStore) FindByUser(_ context.Context, userID uuid.UUID, limit, offset int) ([]*repository.File, int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var out []*repository.File
	for _, f := range s.files {
		if f.UserID == userID {
			out = append(out, f)
		}
	}
	return out, len(out), nil
}
func (s *stubFileStore) UpdateStatus(_ context.Context, id, userID uuid.UUID, status repository.FileStatus) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	f, ok := s.files[id]
	if !ok || f.UserID != userID {
		return repository.ErrNotFound
	}
	f.Status = status
	return nil
}
func (s *stubFileStore) IncrementChunksReceived(_ context.Context, id uuid.UUID) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	f, ok := s.files[id]
	if !ok {
		return 0, repository.ErrNotFound
	}
	f.ChunksReceived++
	if f.Status == repository.FileStatusPending {
		f.Status = repository.FileStatusUploading
	}
	return f.ChunksReceived, nil
}
func (s *stubFileStore) MarkReady(_ context.Context, id uuid.UUID, size int64, compressed bool, thumbKey *string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	f, ok := s.files[id]
	if !ok {
		return repository.ErrNotFound
	}
	f.Status = repository.FileStatusReady
	f.StoredSize = &size
	f.Compressed = compressed
	f.ThumbnailKey = thumbKey
	return nil
}
func (s *stubFileStore) MarkFailed(_ context.Context, id uuid.UUID) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if f, ok := s.files[id]; ok {
		f.Status = repository.FileStatusFailed
	}
	return nil
}
func (s *stubFileStore) Delete(_ context.Context, id, userID uuid.UUID) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	f, ok := s.files[id]
	if !ok || f.UserID != userID {
		return repository.ErrNotFound
	}
	delete(s.files, id)
	return nil
}

func (s *stubFileStore) SetPinned(_ context.Context, id, userID uuid.UUID, pinned bool, retentionMinutes int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	f, ok := s.files[id]
	if !ok || f.UserID != userID {
		return repository.ErrNotFound
	}
	f.IsPinned = pinned
	if pinned {
		now := time.Now()
		f.PinnedAt = &now
		f.ExpiresAt = nil
	} else {
		f.PinnedAt = nil
		t := time.Now().Add(time.Duration(retentionMinutes) * time.Minute)
		f.ExpiresAt = &t
	}
	return nil
}

func (s *stubFileStore) SumUnpinnedBytes(_ context.Context, userID uuid.UUID) (int64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var n int64
	for _, f := range s.files {
		if f.UserID == userID && !f.IsPinned {
			n += f.TotalSize
		}
	}
	return n, nil
}

func (s *stubFileStore) FindOldestUnpinned(_ context.Context, userID uuid.UUID) (*repository.File, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var oldest *repository.File
	for _, f := range s.files {
		if f.UserID == userID && !f.IsPinned {
			if oldest == nil || f.CreatedAt.Before(oldest.CreatedAt) {
				oldest = f
			}
		}
	}
	if oldest == nil {
		return nil, repository.ErrNotFound
	}
	return oldest, nil
}

func (s *stubFileStore) HardDelete(_ context.Context, id uuid.UUID) (*repository.File, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	f, ok := s.files[id]
	if !ok {
		return nil, repository.ErrNotFound
	}
	delete(s.files, id)
	return f, nil
}

// stubChunkStore is an in-memory chunk store.
type stubChunkStore struct {
	mu     sync.Mutex
	chunks map[uuid.UUID][]*repository.FileChunk // fileID → chunks
}

func newStubChunkStore() *stubChunkStore {
	return &stubChunkStore{chunks: map[uuid.UUID][]*repository.FileChunk{}}
}
func (s *stubChunkStore) CreateMany(_ context.Context, fileID uuid.UUID, count, size int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	cs := make([]*repository.FileChunk, count)
	for i := range cs {
		cs[i] = &repository.FileChunk{ID: uuid.New(), FileID: fileID, ChunkIndex: i, Size: size}
	}
	s.chunks[fileID] = cs
	return nil
}
func (s *stubChunkStore) MarkUploaded(_ context.Context, fileID uuid.UUID, idx int, hash, key string, size int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, c := range s.chunks[fileID] {
		if c.ChunkIndex == idx {
			if c.UploadedAt != nil {
				return repository.ErrNotFound // already uploaded
			}
			now := time.Now()
			c.ChunkHash = hash
			c.ObjectKey = key
			c.Size = size
			c.UploadedAt = &now
			return nil
		}
	}
	return repository.ErrNotFound
}
func (s *stubChunkStore) FindByFileID(_ context.Context, fileID uuid.UUID) ([]*repository.FileChunk, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	cs := s.chunks[fileID]
	out := make([]*repository.FileChunk, len(cs))
	copy(out, cs)
	return out, nil
}
func (s *stubChunkStore) MissingIndices(_ context.Context, fileID uuid.UUID) ([]int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var out []int
	for _, c := range s.chunks[fileID] {
		if c.UploadedAt == nil {
			out = append(out, c.ChunkIndex)
		}
	}
	return out, nil
}

// stubMemStorage is an in-memory object store.
type stubMemStorage struct {
	mu      sync.Mutex
	objects map[string][]byte
}

func newStubMemStorage() *stubMemStorage {
	return &stubMemStorage{objects: map[string][]byte{}}
}
func (s *stubMemStorage) Type() string { return "mem" }
func (s *stubMemStorage) Put(_ context.Context, key string, r io.Reader, _ int64, _ string) error {
	data, err := io.ReadAll(r)
	if err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.objects[key] = data
	return nil
}
func (s *stubMemStorage) Get(_ context.Context, key string) (io.ReadCloser, int64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	data, ok := s.objects[key]
	if !ok {
		return nil, 0, ErrFileNotFound
	}
	return io.NopCloser(bytes.NewReader(data)), int64(len(data)), nil
}
func (s *stubMemStorage) Delete(_ context.Context, key string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.objects, key)
	return nil
}
func (s *stubMemStorage) Exists(_ context.Context, key string) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, ok := s.objects[key]
	return ok, nil
}

// stubFileHub captures broadcast calls for assertions.
type stubFileHub struct {
	mu     sync.Mutex
	events []struct {
		userID        uuid.UUID
		data          []byte
		excludeDevice *uuid.UUID
	}
}

func (h *stubFileHub) Broadcast(userID uuid.UUID, data []byte, excludeDevice *uuid.UUID) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.events = append(h.events, struct {
		userID        uuid.UUID
		data          []byte
		excludeDevice *uuid.UUID
	}{userID, data, excludeDevice})
}

// ── helpers ───────────────────────────────────────────────────────────────────

func filesum(data []byte) string {
	h := sha256.Sum256(data)
	return hex.EncodeToString(h[:])
}

func buildFileService(t *testing.T, userID uuid.UUID) (*FileService, *stubFileStore, *stubChunkStore, *stubMemStorage, *stubFileHub) {
	t.Helper()
	fs := newStubFileStore()
	cs := newStubChunkStore()
	st := newStubMemStorage()
	hub := &stubFileHub{}
	svc := NewFileService(fs, cs, nil, nil, &stubSettingsStore{}, st, thumbnail.New(), hub, 1024, 4*1024*1024, 120, 1<<30, 100<<20, 1024<<20)
	_ = userID
	return svc, fs, cs, st, hub
}

// ── tests ─────────────────────────────────────────────────────────────────────

func TestFileService_InitUpload(t *testing.T) {
	userID := uuid.New()
	deviceID := uuid.New()
	svc, _, cs, _, _ := buildFileService(t, userID)

	data := []byte("hello world document content")
	req := dto.FileInitRequest{
		Name:      "test.txt",
		MimeType:  "text/plain",
		TotalSize: int64(len(data)),
		FileHash:  filesum(data),
	}

	resp, err := svc.InitUpload(context.Background(), userID, deviceID, req)
	if err != nil {
		t.Fatalf("InitUpload: %v", err)
	}
	if resp.FileID == "" {
		t.Error("expected non-empty FileID")
	}
	if resp.ChunkCount < 1 {
		t.Errorf("expected ChunkCount ≥ 1, got %d", resp.ChunkCount)
	}

	// Chunk records should be pre-created.
	fid, _ := uuid.Parse(resp.FileID)
	missing, _ := cs.MissingIndices(context.Background(), fid)
	if len(missing) != resp.ChunkCount {
		t.Errorf("missing chunks = %d, want %d", len(missing), resp.ChunkCount)
	}
}

func TestFileService_InitUpload_UnsupportedMIME(t *testing.T) {
	userID := uuid.New()
	deviceID := uuid.New()
	svc, _, _, _, _ := buildFileService(t, userID)

	_, err := svc.InitUpload(context.Background(), userID, deviceID, dto.FileInitRequest{
		Name:      "bad.exe",
		MimeType:  "application/x-executable",
		TotalSize: 100,
		FileHash:  "aabbcc" + hex.EncodeToString(make([]byte, 29)),
	})
	if err != ErrUnsupportedMIME {
		t.Errorf("expected ErrUnsupportedMIME, got %v", err)
	}
}

func TestFileService_InitUpload_TooLarge(t *testing.T) {
	userID := uuid.New()
	deviceID := uuid.New()
	svc, _, _, _, _ := buildFileService(t, userID)

	// The test service has maxFileSizeMB=1024; send 2 GiB.
	_, err := svc.InitUpload(context.Background(), userID, deviceID, dto.FileInitRequest{
		Name:      "huge.zip",
		MimeType:  "application/zip",
		TotalSize: 2 * 1024 * 1024 * 1024,
		FileHash:  hex.EncodeToString(make([]byte, 32)),
	})
	if err != ErrFileTooLarge {
		t.Errorf("expected ErrFileTooLarge, got %v", err)
	}
}

func TestFileService_UploadChunk_HashMismatch(t *testing.T) {
	userID := uuid.New()
	deviceID := uuid.New()
	svc, _, _, _, _ := buildFileService(t, userID)
	ctx := context.Background()

	data := []byte("chunk content")
	resp, _ := svc.InitUpload(ctx, userID, deviceID, dto.FileInitRequest{
		Name:     "f.txt",
		MimeType: "text/plain",
		TotalSize: int64(len(data)),
		FileHash: filesum(data),
	})
	fid, _ := uuid.Parse(resp.FileID)

	err := svc.UploadChunk(ctx, userID, deviceID, fid, 0, data, "deadbeef"+hex.EncodeToString(make([]byte, 28)))
	if err != ErrChunkHashMismatch {
		t.Errorf("expected ErrChunkHashMismatch, got %v", err)
	}
}

func TestFileService_FullFlow_SingleChunk(t *testing.T) {
	userID := uuid.New()
	deviceID := uuid.New()
	svc, _, _, st, hub := buildFileService(t, userID)
	ctx := context.Background()

	data := []byte("complete file content for single chunk test")
	hash := filesum(data)
	chunkHash := hash // single chunk; same hash

	resp, err := svc.InitUpload(ctx, userID, deviceID, dto.FileInitRequest{
		Name:      "doc.txt",
		MimeType:  "text/plain",
		TotalSize: int64(len(data)),
		FileHash:  hash,
	})
	if err != nil {
		t.Fatalf("InitUpload: %v", err)
	}

	fid, _ := uuid.Parse(resp.FileID)

	// Upload the single chunk.
	if err := svc.UploadChunk(ctx, userID, deviceID, fid, 0, data, chunkHash); err != nil {
		t.Fatalf("UploadChunk: %v", err)
	}

	// Progress WS event should have been emitted.
	hub.mu.Lock()
	got := len(hub.events)
	hub.mu.Unlock()
	if got == 0 {
		t.Error("expected at least one WS broadcast after chunk upload")
	}

	// Complete the upload.
	fileResp, err := svc.CompleteUpload(ctx, userID, fid)
	if err != nil {
		t.Fatalf("CompleteUpload: %v", err)
	}
	if fileResp.Status != "ready" {
		t.Errorf("expected status 'ready', got %q", fileResp.Status)
	}
	if !fileResp.HasThumbnail {
		// text/plain has no thumbnail — that's fine.
	}

	// Assembled file must exist in storage under "files/{id}/data".
	_, size, err := st.Get(ctx, "files/"+fid.String()+"/data")
	if err != nil {
		t.Fatalf("get assembled file: %v", err)
	}
	if size == 0 {
		t.Error("assembled file has zero size")
	}

	// Download should work.
	rc, dlSize, mime, err := svc.Download(ctx, userID, deviceID, fid)
	if err != nil {
		t.Fatalf("Download: %v", err)
	}
	defer rc.Close()
	if mime != "text/plain" {
		t.Errorf("mime = %q, want %q", mime, "text/plain")
	}
	downloaded, _ := io.ReadAll(rc)
	if !bytes.Equal(downloaded, data) {
		t.Errorf("downloaded content mismatch: got %d bytes, want %d", len(downloaded), len(data))
	}
	_ = dlSize
}

func TestFileService_CompleteUpload_MissingChunks(t *testing.T) {
	userID := uuid.New()
	deviceID := uuid.New()
	svc, _, _, _, _ := buildFileService(t, userID)
	ctx := context.Background()

	data := make([]byte, 5*1024*1024) // 5 MiB → 2 chunks with 4 MiB chunk size
	for i := range data {
		data[i] = byte(i % 256)
	}
	resp, _ := svc.InitUpload(ctx, userID, deviceID, dto.FileInitRequest{
		Name:      "big.zip",
		MimeType:  "application/zip",
		TotalSize: int64(len(data)),
		FileHash:  filesum(data),
	})
	fid, _ := uuid.Parse(resp.FileID)

	// Only upload chunk 0, not chunk 1.
	chunk0 := data[:4*1024*1024]
	_ = svc.UploadChunk(ctx, userID, deviceID, fid, 0, chunk0, filesum(chunk0))

	_, err := svc.CompleteUpload(ctx, userID, fid)
	if err == nil {
		t.Fatal("expected error for missing chunks, got nil")
	}
}

func TestFileService_ResumeUpload(t *testing.T) {
	userID := uuid.New()
	deviceID := uuid.New()
	svc, _, _, _, _ := buildFileService(t, userID)
	ctx := context.Background()

	data := make([]byte, 5*1024*1024) // 5 MiB → 2 chunks
	hash := filesum(data)
	resp, _ := svc.InitUpload(ctx, userID, deviceID, dto.FileInitRequest{
		Name:      "resume.zip",
		MimeType:  "application/zip",
		TotalSize: int64(len(data)),
		FileHash:  hash,
		ChunkSize: 4 * 1024 * 1024,
	})
	fid, _ := uuid.Parse(resp.FileID)

	// Upload only chunk 0 to simulate an interrupted upload.
	chunk0 := data[:4*1024*1024]
	_ = svc.UploadChunk(ctx, userID, deviceID, fid, 0, chunk0, filesum(chunk0))

	// Resume: ask server which chunks are missing.
	status, err := svc.GetUploadStatus(ctx, userID, fid)
	if err != nil {
		t.Fatalf("GetUploadStatus: %v", err)
	}
	if len(status.MissingChunks) != 1 || status.MissingChunks[0] != 1 {
		t.Errorf("expected missing=[1], got %v", status.MissingChunks)
	}

	// Upload missing chunk 1.
	chunk1 := data[4*1024*1024:]
	_ = svc.UploadChunk(ctx, userID, deviceID, fid, 1, chunk1, filesum(chunk1))

	// Now complete should succeed.
	fileResp, err := svc.CompleteUpload(ctx, userID, fid)
	if err != nil {
		t.Fatalf("CompleteUpload after resume: %v", err)
	}
	if fileResp.Status != "ready" {
		t.Errorf("want 'ready', got %q", fileResp.Status)
	}
}

func TestFileService_IntegrityMismatch(t *testing.T) {
	userID := uuid.New()
	deviceID := uuid.New()
	svc, _, _, _, _ := buildFileService(t, userID)
	ctx := context.Background()

	data := []byte("some text content")
	wrongHash := hex.EncodeToString(make([]byte, 32)) // all-zero hash ≠ sha256(data)

	resp, _ := svc.InitUpload(ctx, userID, deviceID, dto.FileInitRequest{
		Name:      "bad.txt",
		MimeType:  "text/plain",
		TotalSize: int64(len(data)),
		FileHash:  wrongHash,
	})
	fid, _ := uuid.Parse(resp.FileID)

	_ = svc.UploadChunk(ctx, userID, deviceID, fid, 0, data, "")

	_, err := svc.CompleteUpload(ctx, userID, fid)
	if err != ErrFileHashMismatch {
		t.Errorf("expected ErrFileHashMismatch, got %v", err)
	}
}

func TestFileService_DeleteFile(t *testing.T) {
	userID := uuid.New()
	deviceID := uuid.New()
	svc, _, _, _, _ := buildFileService(t, userID)
	ctx := context.Background()

	data := []byte("to be deleted")
	resp, _ := svc.InitUpload(ctx, userID, deviceID, dto.FileInitRequest{
		Name:      "del.txt",
		MimeType:  "text/plain",
		TotalSize: int64(len(data)),
		FileHash:  filesum(data),
	})
	fid, _ := uuid.Parse(resp.FileID)

	if err := svc.DeleteFile(ctx, userID, fid); err != nil {
		t.Fatalf("DeleteFile: %v", err)
	}

	// Subsequent get should fail.
	if _, err := svc.GetFile(ctx, userID, fid); err != ErrFileNotFound {
		t.Errorf("expected ErrFileNotFound after delete, got %v", err)
	}
}

func TestFileService_GetUploadStatus_UnknownFile(t *testing.T) {
	userID := uuid.New()
	svc, _, _, _, _ := buildFileService(t, userID)
	ctx := context.Background()

	_, err := svc.GetUploadStatus(ctx, userID, uuid.New())
	if err != ErrFileNotFound {
		t.Errorf("expected ErrFileNotFound, got %v", err)
	}
}
