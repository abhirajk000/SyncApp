// Package storage provides a simple, swappable object-store abstraction.
//
// Backends:
//   local — stores files on the server filesystem (default; zero dependencies).
//   s3    — stores files in AWS S3 or any S3-compatible service (MinIO, Cloudflare R2).
//
// All keys are opaque strings.  By convention SyncBridge uses the pattern:
//
//	files/{file_id}/chunk_{n}     — raw uploaded chunk (temporary)
//	files/{file_id}/data          — assembled, optionally compressed final object
//	files/{file_id}/thumbnail.jpg — 256×256 JPEG thumbnail (images only)
package storage

import (
	"context"
	"errors"
	"fmt"
	"io"

	"github.com/syncbridge/api/internal/config"
)

// ── Backend interface ─────────────────────────────────────────────────────────

// Backend is the minimal contract every storage driver must satisfy.
type Backend interface {
	// Put stores the bytes from r under key.
	// size must equal the number of bytes in r; pass -1 if unknown (slower for S3).
	Put(ctx context.Context, key string, r io.Reader, size int64, contentType string) error

	// Get opens key for sequential reading.
	// Returns (reader, content-length, error).  The caller must close the reader.
	Get(ctx context.Context, key string) (io.ReadCloser, int64, error)

	// Delete removes key.  No-ops if key does not exist.
	Delete(ctx context.Context, key string) error

	// Exists reports whether key has been stored.
	Exists(ctx context.Context, key string) (bool, error)

	// Type returns a human-readable backend name ("local", "s3", etc.).
	Type() string
}

// ── Errors ────────────────────────────────────────────────────────────────────

var (
	// ErrNotFound is returned when a key does not exist in the backend.
	ErrNotFound = errors.New("storage: object not found")
	// ErrIntegrity is returned when a retrieved object fails its integrity check.
	ErrIntegrity = errors.New("storage: integrity check failed")
)

// ── Factory ───────────────────────────────────────────────────────────────────

// New returns the Backend configured by cfg.ObjectStorageType.
//   - "local" or "":   LocalBackend rooted at cfg.ObjectStoragePath.
//   - "s3", "minio":   S3Backend using cfg.S3Endpoint / Bucket / credentials.
func New(cfg *config.Config) (Backend, error) {
	switch cfg.ObjectStorageType {
	case "s3", "minio":
		return NewS3Backend(S3Config{
			Endpoint:  cfg.S3Endpoint,
			Bucket:    cfg.S3Bucket,
			Region:    cfg.S3Region,
			AccessKey: cfg.S3AccessKey,
			SecretKey: cfg.S3SecretKey,
			UseSSL:    cfg.S3UseSSL,
		})
	case "local", "":
		return NewLocalBackend(cfg.ObjectStoragePath)
	default:
		return nil, fmt.Errorf("unknown storage type %q; valid values: local | s3 | minio", cfg.ObjectStorageType)
	}
}

// ── Key helpers ───────────────────────────────────────────────────────────────
//
// Conventions:
//   keyPrefix  is stored in files.object_key_prefix (e.g. "files/<file-id>")
//   Helpers append only the object-name segment, keeping paths unambiguous.

// ChunkKey returns the storage key for the n-th chunk of an upload.
func ChunkKey(keyPrefix string, chunkIndex int) string {
	return fmt.Sprintf("%s/chunk_%04d", keyPrefix, chunkIndex)
}

// DataKey returns the storage key for the assembled, final file object.
func DataKey(keyPrefix string) string {
	return fmt.Sprintf("%s/data", keyPrefix)
}

// ThumbnailKey returns the storage key for the file's JPEG thumbnail.
func ThumbnailKey(keyPrefix string) string {
	return fmt.Sprintf("%s/thumbnail.jpg", keyPrefix)
}
