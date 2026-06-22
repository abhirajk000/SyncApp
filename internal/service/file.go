package service

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/repository"
	"github.com/syncbridge/api/internal/storage"
	"github.com/syncbridge/api/internal/thumbnail"
	"github.com/syncbridge/api/internal/ws"
)

// ── Sentinel errors ───────────────────────────────────────────────────────────

var (
	ErrFileNotFound       = errors.New("file not found")
	ErrUnsupportedMIME    = errors.New("unsupported MIME type")
	ErrFileTooLarge       = errors.New("file exceeds maximum allowed size")
	ErrAutoCloudBlocked   = errors.New("files over 1 GB cannot use cloud relay without force_relay")
	ErrChunkOutOfRange    = errors.New("chunk index out of range")
	ErrChunkHashMismatch  = errors.New("chunk integrity check failed: hash mismatch")
	ErrChunkAlreadyExists = errors.New("chunk already uploaded")
	ErrNotAllChunks       = errors.New("not all chunks have been uploaded")
	ErrFileHashMismatch   = errors.New("file integrity check failed: hash mismatch")
	ErrStorageFailed      = errors.New("file storage failed")
)

// ── Store / backend interfaces ────────────────────────────────────────────────

type fileStore interface {
	Create(ctx context.Context, f *repository.File) error
	FindByID(ctx context.Context, id, userID uuid.UUID) (*repository.File, error)
	FindByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*repository.File, int, error)
	UpdateStatus(ctx context.Context, id, userID uuid.UUID, status repository.FileStatus) error
	IncrementChunksReceived(ctx context.Context, id uuid.UUID) (int, error)
	MarkReady(ctx context.Context, id uuid.UUID, storedSize int64, compressed bool, thumbnailKey *string) error
	MarkFailed(ctx context.Context, id uuid.UUID) error
	Delete(ctx context.Context, id, userID uuid.UUID) error
	SetPinned(ctx context.Context, id, userID uuid.UUID, pinned bool, retentionMinutes int) error
	SumUnpinnedBytes(ctx context.Context, userID uuid.UUID) (int64, error)
	FindOldestUnpinned(ctx context.Context, userID uuid.UUID) (*repository.File, error)
	HardDelete(ctx context.Context, id uuid.UUID) (*repository.File, error)
}

type deliveryStore interface {
	MarkDelivered(ctx context.Context, fileID, deviceID uuid.UUID) error
	CountDeliveries(ctx context.Context, fileID, senderDeviceID uuid.UUID) (int, error)
}

type deliveryDeviceStore interface {
	CountActiveByUserID(ctx context.Context, userID uuid.UUID) (int, error)
}

type chunkStore interface {
	CreateMany(ctx context.Context, fileID uuid.UUID, chunkCount, chunkSize int) error
	MarkUploaded(ctx context.Context, fileID uuid.UUID, chunkIndex int, hash, objectKey string, size int) error
	FindByFileID(ctx context.Context, fileID uuid.UUID) ([]*repository.FileChunk, error)
	MissingIndices(ctx context.Context, fileID uuid.UUID) ([]int, error)
}

type fileHub interface {
	Broadcast(userID uuid.UUID, data []byte, excludeDevice *uuid.UUID)
}

// ── FileService ───────────────────────────────────────────────────────────────

// FileService manages file transfer (plaintext filenames at rest).
type FileService struct {
	files                   fileStore
	chunks                  chunkStore
	deliveries              deliveryStore
	devices                 deliveryDeviceStore
	settings                userSettingsStore
	store                   storage.Backend
	thumb                   *thumbnail.Generator
	hub                     fileHub
	gc                      *fileObjectDeleter

	maxFileSizeBytes        int64
	defaultChunkSize        int
	defaultRetentionMinutes int
	maxUnpinnedBytes        int64
	relayAutoMaxBytes       int64
	autoCloudMaxBytes       int64
}

func NewFileService(
	files fileStore,
	chunks chunkStore,
	deliveries deliveryStore,
	devices deliveryDeviceStore,
	settings userSettingsStore,
	store storage.Backend,
	thumb *thumbnail.Generator,
	hub fileHub,
	maxFileSizeMB int,
	defaultChunkSizeBytes int,
	defaultRetentionMinutes int,
	maxUnpinnedBytes int64,
	relayAutoMaxBytes int64,
	autoCloudMaxBytes int64,
) *FileService {
	return &FileService{
		files:                   files,
		chunks:                  chunks,
		deliveries:              deliveries,
		devices:                 devices,
		settings:                settings,
		store:                   store,
		thumb:                   thumb,
		hub:                     hub,
		gc:                      newFileObjectDeleter(store),
		maxFileSizeBytes:        int64(maxFileSizeMB) * 1024 * 1024,
		defaultChunkSize:        defaultChunkSizeBytes,
		defaultRetentionMinutes: defaultRetentionMinutes,
		maxUnpinnedBytes:        maxUnpinnedBytes,
		relayAutoMaxBytes:       relayAutoMaxBytes,
		autoCloudMaxBytes:       autoCloudMaxBytes,
	}
}

// ── Init ──────────────────────────────────────────────────────────────────────

// InitUpload validates the file metadata and creates all necessary DB records.
// The client must then upload each chunk to PUT /files/:id/chunks/:n.
func (s *FileService) InitUpload(
	ctx context.Context,
	userID, senderDeviceID uuid.UUID,
	req dto.FileInitRequest,
) (*dto.FileInitResponse, error) {
	if !dto.SupportedFileMIMETypes[req.MimeType] {
		return nil, ErrUnsupportedMIME
	}
	if req.TotalSize > s.maxFileSizeBytes {
		return nil, ErrFileTooLarge
	}

	mode := repository.TransferModeRelay
	if req.TransferMode == string(repository.TransferModeWebRTC) {
		mode = repository.TransferModeWebRTC
	} else if req.TotalSize > s.autoCloudMaxBytes && !req.ForceRelay {
		return nil, ErrAutoCloudBlocked
	} else if req.TotalSize > s.relayAutoMaxBytes && mode == repository.TransferModeRelay && !req.ForceRelay {
		// Prefer direct transfer for 100 MB–1 GB unless client forces relay.
		mode = repository.TransferModeWebRTC
	}

	if err := enforceCombinedQuota(ctx, userID, req.TotalSize, s.maxUnpinnedBytes, nil, s.files, s.gc); err != nil {
		return nil, err
	}

	chunkSize := req.ChunkSize
	if chunkSize <= 0 {
		chunkSize = s.defaultChunkSize
	}
	chunkCount := int(math.Ceil(float64(req.TotalSize) / float64(chunkSize)))

	retentionMins := s.defaultRetentionMinutes
	if s.settings != nil {
		if us, err := s.settings.Get(ctx, userID); err == nil {
			retentionMins = us.RetentionMinutes
		}
	}
	expiry := time.Now().Add(time.Duration(retentionMins) * time.Minute)
	expiresAt := &expiry

	fileID := uuid.New()
	f := &repository.File{
		ID:                fileID,
		UserID:            userID,
		SenderDeviceID:  senderDeviceID,
		OriginalName:    req.Name,
		MimeType:          req.MimeType,
		TotalSize:         req.TotalSize,
		ChunkSize:         chunkSize,
		ChunkCount:        chunkCount,
		FileHash:          req.FileHash,
		ObjectKeyPrefix:   fmt.Sprintf("files/%s", fileID),
		Status:            repository.FileStatusPending,
		Compressed:        dto.IsCompressible(req.MimeType),
		TransferMode:      mode,
		ExpiresAt:         expiresAt,
	}
	if err := s.files.Create(ctx, f); err != nil {
		return nil, fmt.Errorf("create file record: %w", err)
	}
	if err := s.chunks.CreateMany(ctx, fileID, chunkCount, chunkSize); err != nil {
		_ = s.files.MarkFailed(ctx, fileID) // best-effort cleanup
		return nil, fmt.Errorf("create chunk records: %w", err)
	}

	resp := &dto.FileInitResponse{
		FileID:     fileID.String(),
		ChunkSize:  chunkSize,
		ChunkCount: chunkCount,
	}
	if expiresAt != nil {
		resp.ExpiresAt = expiresAt.Format(time.RFC3339)
	}
	return resp, nil
}

// ── Chunk upload ──────────────────────────────────────────────────────────────

// UploadChunk stores one chunk of the upload, validates its hash, and tracks
// progress.  After every chunk it broadcasts a file.progress WS event to all
// devices of the user except the sender.
//
// headerHash must be the SHA-256 hex of the raw chunk bytes (before any
// server-side processing) to allow the server to detect corruption in transit.
func (s *FileService) UploadChunk(
	ctx context.Context,
	userID, senderDeviceID uuid.UUID,
	fileID uuid.UUID,
	chunkIndex int,
	data []byte,
	headerHash string,
) error {
	f, err := s.files.FindByID(ctx, fileID, userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return ErrFileNotFound
		}
		return err
	}
	if chunkIndex < 0 || chunkIndex >= f.ChunkCount {
		return ErrChunkOutOfRange
	}
	if f.Status == repository.FileStatusReady || f.Status == repository.FileStatusFailed {
		return fmt.Errorf("file is already in terminal state %q", f.Status)
	}

	// Validate chunk integrity.
	actual := sha256Hex(data)
	if headerHash != "" && actual != headerHash {
		return ErrChunkHashMismatch
	}

	// Persist chunk to storage.
	key := storage.ChunkKey(f.ObjectKeyPrefix, chunkIndex)
	if err := s.store.Put(ctx, key, bytes.NewReader(data), int64(len(data)), "application/octet-stream"); err != nil {
		return fmt.Errorf("%w: store chunk: %w", ErrStorageFailed, err)
	}

	// Record in DB.
	if err := s.chunks.MarkUploaded(ctx, fileID, chunkIndex, actual, key, len(data)); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return ErrChunkAlreadyExists
		}
		return fmt.Errorf("mark chunk uploaded: %w", err)
	}

	received, err := s.files.IncrementChunksReceived(ctx, fileID)
	if err != nil {
		return fmt.Errorf("increment progress: %w", err)
	}

	// Broadcast progress to other devices.
	s.broadcastProgress(userID, senderDeviceID, fileID, received, f.ChunkCount)

	return nil
}

// ── Complete / assembly ───────────────────────────────────────────────────────

// CompleteUpload assembles all chunks, validates the full-file SHA-256,
// optionally compresses the file, generates a thumbnail, and marks the file
// as ready.  It is safe to call concurrently; a CAS on status prevents double
// processing.
func (s *FileService) CompleteUpload(
	ctx context.Context,
	userID uuid.UUID,
	fileID uuid.UUID,
) (*dto.FileResponse, error) {
	f, err := s.files.FindByID(ctx, fileID, userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrFileNotFound
		}
		return nil, err
	}

	missing, err := s.chunks.MissingIndices(ctx, fileID)
	if err != nil {
		return nil, err
	}
	if len(missing) > 0 {
		return nil, fmt.Errorf("%w: missing chunk indices %v", ErrNotAllChunks, missing)
	}

	// Transition to 'processing' so concurrent calls are rejected.
	if err := s.files.UpdateStatus(ctx, fileID, userID, repository.FileStatusProcessing); err != nil {
		return nil, fmt.Errorf("transition to processing: %w", err)
	}

	storedSize, compressed, thumbKey, err := s.assemble(ctx, f)
	if err != nil {
		_ = s.files.MarkFailed(ctx, fileID)
		s.broadcastFailed(userID, fileID)
		return nil, err
	}

	if err := s.files.MarkReady(ctx, fileID, storedSize, compressed, thumbKey); err != nil {
		return nil, err
	}

	name := f.OriginalName

	s.broadcastReady(userID, fileID, f.MimeType, name)

	updated, _ := s.files.FindByID(ctx, fileID, userID)
	if updated != nil {
		f = updated
	}
	return toFileResponse(f, name), nil
}

// ── Get status (resume) ───────────────────────────────────────────────────────

// GetUploadStatus returns which chunks are still missing, enabling the client
// to resume an interrupted upload without re-uploading complete chunks.
func (s *FileService) GetUploadStatus(
	ctx context.Context,
	userID, fileID uuid.UUID,
) (*dto.FileStatusResponse, error) {
	f, err := s.files.FindByID(ctx, fileID, userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrFileNotFound
		}
		return nil, err
	}

	missing, err := s.chunks.MissingIndices(ctx, fileID)
	if err != nil {
		return nil, err
	}

	pct := 0
	if f.ChunkCount > 0 {
		pct = (f.ChunksReceived * 100) / f.ChunkCount
	}

	return &dto.FileStatusResponse{
		FileID:          fileID.String(),
		Status:          string(f.Status),
		ChunkCount:      f.ChunkCount,
		ChunksReceived:  f.ChunksReceived,
		MissingChunks:   missing,
		ProgressPercent: pct,
	}, nil
}

// ── Download ──────────────────────────────────────────────────────────────────

// Download opens the assembled file for streaming.
// Returns (reader, contentLength, mimeType, error).
// The caller must close the reader.
func (s *FileService) Download(
	ctx context.Context,
	userID, deviceID, fileID uuid.UUID,
) (io.ReadCloser, int64, string, error) {
	f, err := s.files.FindByID(ctx, fileID, userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, 0, "", ErrFileNotFound
		}
		return nil, 0, "", err
	}
	if f.Status != repository.FileStatusReady {
		return nil, 0, "", fmt.Errorf("file is not ready (status: %s)", f.Status)
	}

	key := storage.DataKey(f.ObjectKeyPrefix)
	rc, size, err := s.store.Get(ctx, key)
	if err != nil {
		return nil, 0, "", fmt.Errorf("open file from storage: %w", err)
	}

	// Decompress on-the-fly if needed.
	if f.Compressed {
		gz, err := gzip.NewReader(rc)
		if err != nil {
			rc.Close()
			return nil, 0, "", fmt.Errorf("decompress: %w", err)
		}
		rc = &compressedReadCloser{Reader: gz, inner: rc}
		size = f.TotalSize
	}

	_ = s.recordDelivery(ctx, f, deviceID)

	return rc, size, f.MimeType, nil
}

// MarkDelivered records successful receipt on a device (P2P or manual ack).
func (s *FileService) MarkDelivered(ctx context.Context, userID, deviceID, fileID uuid.UUID) error {
	f, err := s.files.FindByID(ctx, fileID, userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return ErrFileNotFound
		}
		return err
	}
	return s.recordDelivery(ctx, f, deviceID)
}

// DownloadThumbnail streams the thumbnail for an image file.
func (s *FileService) DownloadThumbnail(
	ctx context.Context,
	userID, fileID uuid.UUID,
) (io.ReadCloser, int64, error) {
	f, err := s.files.FindByID(ctx, fileID, userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, 0, ErrFileNotFound
		}
		return nil, 0, err
	}
	if f.ThumbnailKey == nil {
		return nil, 0, ErrFileNotFound
	}
	rc, size, err := s.store.Get(ctx, *f.ThumbnailKey)
	return rc, size, err
}

// ── List / Get / Delete ───────────────────────────────────────────────────────

// GetFile returns metadata for one file.
func (s *FileService) GetFile(ctx context.Context, userID, fileID uuid.UUID) (*dto.FileResponse, error) {
	f, err := s.files.FindByID(ctx, fileID, userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrFileNotFound
		}
		return nil, err
	}
	return toFileResponse(f, f.OriginalName), nil
}

// ListFiles returns a paginated list of files for the user.
func (s *FileService) ListFiles(ctx context.Context, userID uuid.UUID, limit, offset int) (*dto.FileListResponse, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	files, total, err := s.files.FindByUser(ctx, userID, limit, offset)
	if err != nil {
		return nil, err
	}

	out := make([]dto.FileResponse, 0, len(files))
	for _, f := range files {
		out = append(out, *toFileResponse(f, f.OriginalName))
	}
	return &dto.FileListResponse{
		Files:   out,
		Total:   total,
		Limit:   limit,
		Offset:  offset,
		HasMore: offset+len(out) < total,
	}, nil
}

// DeleteFile soft-deletes a file.
func (s *FileService) DeleteFile(ctx context.Context, userID, fileID uuid.UUID) error {
	err := s.files.Delete(ctx, fileID, userID)
	if errors.Is(err, repository.ErrNotFound) {
		return ErrFileNotFound
	}
	return err
}

// ── Pin ───────────────────────────────────────────────────────────────────────

// SetPinned pins or unpins a file.
//
// Pinning:   expires_at=NULL, pinned_at=now().
// Unpinning: expires_at = now() + user retention window.
// Broadcasts a file.pin WS event to all of the user's online devices.
func (s *FileService) SetPinned(ctx context.Context, userID, fileID uuid.UUID, pinned bool) error {
	retentionMins := s.defaultRetentionMinutes
	if s.settings != nil {
		if us, err := s.settings.Get(ctx, userID); err == nil {
			retentionMins = us.RetentionMinutes
		}
	}

	if err := s.files.SetPinned(ctx, fileID, userID, pinned, retentionMins); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return ErrFileNotFound
		}
		return err
	}

	if s.hub != nil {
		pinnedAt := ""
		if pinned {
			pinnedAt = time.Now().UTC().Format(time.RFC3339)
		}
		if data, err := ws.EncodeFilePin(fileID.String(), pinned, pinnedAt); err == nil {
			s.hub.Broadcast(userID, data, nil)
		}
	}
	return nil
}

// ── Assembly (private) ────────────────────────────────────────────────────────

// assemble streams all chunks from storage, validates the full SHA-256,
// optionally gzip-compresses the content, generates a thumbnail, then stores
// the final object. Returns (storedSize, thumbnailKey, error).
func (s *FileService) assemble(ctx context.Context, f *repository.File) (int64, bool, *string, error) {
	chunks, err := s.chunks.FindByFileID(ctx, f.ID)
	if err != nil {
		return 0, false, nil, err
	}

	// ── Stream chunks, compute hash and accumulate plaintext ──────────────────
	h := sha256.New()
	var plainBuf bytes.Buffer

	for _, c := range chunks {
		rc, _, err := s.store.Get(ctx, c.ObjectKey)
		if err != nil {
			return 0, false, nil, fmt.Errorf("read chunk %d: %w", c.ChunkIndex, err)
		}
		data, err := io.ReadAll(rc)
		rc.Close()
		if err != nil {
			return 0, false, nil, fmt.Errorf("read chunk %d data: %w", c.ChunkIndex, err)
		}
		h.Write(data)
		plainBuf.Write(data)
	}

	// ── Validate full-file hash ────────────────────────────────────────────────
	actual := hex.EncodeToString(h.Sum(nil))
	if actual != f.FileHash {
		return 0, false, nil, ErrFileHashMismatch
	}

	plainData := plainBuf.Bytes()

	// ── Optional thumbnail ────────────────────────────────────────────────────
	var thumbKey *string
		if thumbnail.CanThumbnail(f.MimeType) {
		thumbData, err := s.thumb.Generate(plainData, f.MimeType)
		if err == nil {
			tk := storage.ThumbnailKey(f.ObjectKeyPrefix)
			if stErr := s.store.Put(ctx, tk, bytes.NewReader(thumbData), int64(len(thumbData)), "image/jpeg"); stErr == nil {
				thumbKey = &tk
			}
		}
	}

	// ── Compress if eligible ──────────────────────────────────────────────────
	finalData := plainData
	actuallyCompressed := false
	if f.Compressed {
		var buf bytes.Buffer
		w, _ := gzip.NewWriterLevel(&buf, gzip.BestCompression)
		w.Write(plainData)
		w.Close()
		if buf.Len() < len(plainData) {
			finalData = buf.Bytes()
			actuallyCompressed = true
		}
	}

	// ── Store final assembled file ────────────────────────────────────────────
	finalKey := storage.DataKey(f.ObjectKeyPrefix)
	if err := s.store.Put(ctx, finalKey, bytes.NewReader(finalData), int64(len(finalData)), f.MimeType); err != nil {
		return 0, false, nil, fmt.Errorf("%w: store assembled file: %w", ErrStorageFailed, err)
	}

	// ── Delete chunk objects to reclaim storage ────────────────────────────────
	for _, c := range chunks {
		if delErr := s.store.Delete(ctx, c.ObjectKey); delErr != nil {
			log.Warn().Err(delErr).Str("key", c.ObjectKey).Msg("delete chunk after assembly")
		}
	}

	return int64(len(finalData)), actuallyCompressed, thumbKey, nil
}

// ── WS broadcasts (private) ───────────────────────────────────────────────────

func (s *FileService) broadcastProgress(userID, excludeDevice uuid.UUID, fileID uuid.UUID, received, total int) {
	data, err := ws.EncodeFileProgress(fileID.String(), received, total)
	if err != nil {
		return
	}
	s.hub.Broadcast(userID, data, &excludeDevice)
}

func (s *FileService) broadcastReady(userID, fileID uuid.UUID, mimeType, name string) {
	data, err := ws.EncodeFileReady(fileID.String(), mimeType, name)
	if err != nil {
		return
	}
	s.hub.Broadcast(userID, data, nil)
}

func (s *FileService) broadcastFailed(userID, fileID uuid.UUID) {
	data, err := ws.EncodeFileFailed(fileID.String())
	if err != nil {
		return
	}
	s.hub.Broadcast(userID, data, nil)
}

// ── Helpers ───────────────────────────────────────────────────────────────────

func sha256Hex(data []byte) string {
	h := sha256.Sum256(data)
	return hex.EncodeToString(h[:])
}

func (s *FileService) recordDelivery(ctx context.Context, f *repository.File, deviceID uuid.UUID) error {
	if s.deliveries == nil || deviceID == f.SenderDeviceID {
		return nil
	}
	if err := s.deliveries.MarkDelivered(ctx, f.ID, deviceID); err != nil {
		return err
	}
	return s.tryDeleteAfterDelivery(ctx, f)
}

func (s *FileService) tryDeleteAfterDelivery(ctx context.Context, f *repository.File) error {
	if f.IsPinned || s.devices == nil || s.deliveries == nil {
		return nil
	}
	active, err := s.devices.CountActiveByUserID(ctx, f.UserID)
	if err != nil {
		return err
	}
	expected := active - 1 // exclude sender
	if expected <= 0 {
		return nil
	}
	got, err := s.deliveries.CountDeliveries(ctx, f.ID, f.SenderDeviceID)
	if err != nil {
		return err
	}
	if got < expected {
		return nil
	}
	deleted, err := s.files.HardDelete(ctx, f.ID)
	if err != nil {
		return err
	}
	if s.gc != nil {
		_ = s.gc.DeleteFileObjects(ctx, deleted)
	}
	return nil
}

func toFileResponse(f *repository.File, name string) *dto.FileResponse {
	return &dto.FileResponse{
		ID:             f.ID.String(),
		Name:           name,
		MimeType:       f.MimeType,
		TotalSize:      f.TotalSize,
		StoredSize:     f.StoredSize,
		ChunkCount:     f.ChunkCount,
		ChunksReceived: f.ChunksReceived,
		Status:         string(f.Status),
		HasThumbnail:   f.ThumbnailKey != nil,
		TransferMode:   string(f.TransferMode),
		SenderDeviceID: f.SenderDeviceID.String(),
		IsPinned:       f.IsPinned,
		PinnedAt:       f.PinnedAt,
		CreatedAt:      f.CreatedAt,
		ExpiresAt:      f.ExpiresAt,
	}
}

// compressedReadCloser wraps a gzip.Reader so that closing it also closes the
// underlying storage ReadCloser.
type compressedReadCloser struct {
	*gzip.Reader
	inner io.Closer
}

func (c *compressedReadCloser) Close() error {
	err1 := c.Reader.Close()
	err2 := c.inner.Close()
	if err1 != nil {
		return err1
	}
	return err2
}
