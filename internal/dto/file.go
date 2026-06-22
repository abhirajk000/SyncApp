package dto

import "time"

// ── Supported MIME types ──────────────────────────────────────────────────────

// SupportedFileMIMETypes is the allowlist of file types accepted for upload.
var SupportedFileMIMETypes = map[string]bool{
	// Images / Screenshots
	"image/jpeg": true, "image/png": true, "image/gif": true,
	"image/webp": true, "image/bmp": true, "image/tiff": true,
	"image/heic": true, "image/heif": true,
	// Videos
	"video/mp4": true, "video/webm": true, "video/quicktime": true,
	"video/x-msvideo": true, "video/x-matroska": true,
	// Documents
	"application/pdf": true,
	"application/msword": true,
	"application/vnd.openxmlformats-officedocument.wordprocessingml.document": true,
	"application/vnd.ms-excel": true,
	"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": true,
	"application/vnd.ms-powerpoint": true,
	"application/vnd.openxmlformats-officedocument.presentationml.presentation": true,
	"text/plain": true, "text/markdown": true, "text/csv": true,
	// Archives
	"application/zip": true, "application/x-zip-compressed": true,
	"application/gzip": true, "application/x-tar": true,
	"application/x-7z-compressed": true,
	// Fallback when the browser cannot detect MIME type
	"application/octet-stream": true,
}

// compressibleMIMETypes are candidates for gzip compression.
// Already-compressed formats (JPEG, MP4, ZIP…) are excluded.
var CompressibleMIMETypes = map[string]bool{
	"application/pdf": true,
	"application/msword": true,
	"application/vnd.openxmlformats-officedocument.wordprocessingml.document": true,
	"text/plain": true, "text/markdown": true, "text/csv": true,
}

// IsCompressible returns true if the MIME type is worth gzip-compressing.
func IsCompressible(mimeType string) bool { return CompressibleMIMETypes[mimeType] }

// ── Upload init ───────────────────────────────────────────────────────────────

// FileInitRequest is the body for POST /api/v1/files/init.
type FileInitRequest struct {
	// Name is the original filename (plaintext; server encrypts it for storage).
	Name string `json:"name" validate:"required,min=1,max=512"`
	// MimeType must be in SupportedFileMIMETypes.
	MimeType string `json:"mime_type" validate:"required"`
	// TotalSize is the uncompressed file size in bytes.
	TotalSize int64 `json:"total_size" validate:"required,min=1"`
	// ChunkSize is how many bytes each chunk contains (last chunk may be smaller).
	// Leave 0 to use the server default (4 MiB).
	ChunkSize int `json:"chunk_size"`
	// FileHash is the SHA-256 hex of the complete plaintext file.
	// The server validates this during assembly.
	FileHash string `json:"file_hash" validate:"required,len=64"`
	// TransferMode is "relay" (default) or "webrtc".
	TransferMode string `json:"transfer_mode"`
	// ForceRelay allows cloud relay for files >1 GB (user confirmed upload anyway).
	ForceRelay bool `json:"force_relay"`
}

// FileInitResponse is returned after a successful POST /api/v1/files/init.
type FileInitResponse struct {
	FileID     string `json:"file_id"`
	ChunkSize  int    `json:"chunk_size"`
	ChunkCount int    `json:"chunk_count"`
	ExpiresAt  string `json:"expires_at"` // RFC3339
}

// ── Upload status / resume ────────────────────────────────────────────────────

// FileStatusResponse is returned by GET /api/v1/files/:id/status.
type FileStatusResponse struct {
	FileID          string `json:"file_id"`
	Status          string `json:"status"`
	ChunkCount      int    `json:"chunk_count"`
	ChunksReceived  int    `json:"chunks_received"`
	// MissingChunks lists chunk indices (0-based) not yet received.
	// Empty when all chunks have been uploaded.
	MissingChunks   []int  `json:"missing_chunks"`
	ProgressPercent int    `json:"progress_percent"`
}

// ── File metadata ─────────────────────────────────────────────────────────────

// FileResponse is the full metadata for a stored file.
type FileResponse struct {
	ID             string     `json:"id"`
	Name           string     `json:"name"`            // decrypted filename
	MimeType       string     `json:"mime_type"`
	TotalSize      int64      `json:"total_size"`
	StoredSize     *int64     `json:"stored_size,omitempty"`
	ChunkCount     int        `json:"chunk_count"`
	ChunksReceived int        `json:"chunks_received"`
	Status         string     `json:"status"`
	HasThumbnail   bool       `json:"has_thumbnail"`
	TransferMode   string     `json:"transfer_mode"`
	SenderDeviceID string     `json:"sender_device_id"`
	IsPinned       bool       `json:"is_pinned"`
	PinnedAt       *time.Time `json:"pinned_at,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	ExpiresAt      *time.Time `json:"expires_at,omitempty"`
}

// FileListResponse wraps a paginated list of files.
type FileListResponse struct {
	Files   []FileResponse `json:"files"`
	Total   int            `json:"total"`
	Limit   int            `json:"limit"`
	Offset  int            `json:"offset"`
	HasMore bool           `json:"has_more"`
}
