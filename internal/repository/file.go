package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ── File domain model ─────────────────────────────────────────────────────────

// FileStatus represents the current upload/processing state of a file.
type FileStatus string

const (
	FileStatusPending    FileStatus = "pending"
	FileStatusUploading  FileStatus = "uploading"
	FileStatusProcessing FileStatus = "processing"
	FileStatusReady      FileStatus = "ready"
	FileStatusFailed     FileStatus = "failed"
)

// FileTransferMode indicates how the file is being transferred.
type FileTransferMode string

const (
	TransferModeRelay   FileTransferMode = "relay"   // chunked HTTP through server
	TransferModeWebRTC  FileTransferMode = "webrtc"  // P2P; server stores backup copy
)

// File is the domain model for one uploaded file.
type File struct {
	ID              uuid.UUID
	UserID          uuid.UUID
	SenderDeviceID  uuid.UUID
	OriginalName    string
	MimeType        string
	TotalSize       int64
	StoredSize      *int64    // post-compression size; nil until assembly complete
	ChunkSize       int
	ChunkCount      int
	ChunksReceived  int
	FileHash        string    // SHA-256(plaintext file) hex, provided by client
	ObjectKeyPrefix string    // storage key prefix for this file's objects
	ThumbnailKey    *string   // set after thumbnail generation
	Status          FileStatus
	Compressed      bool
	TransferMode    FileTransferMode
	IsPinned        bool
	PinnedAt        *time.Time
	CreatedAt       time.Time
	ExpiresAt       *time.Time
}

// FileChunk tracks one uploaded chunk.
type FileChunk struct {
	ID         uuid.UUID
	FileID     uuid.UUID
	ChunkIndex int
	ChunkHash  string    // SHA-256(chunk plaintext) hex, validated on upload
	ObjectKey  string    // full storage key for this chunk
	Size       int
	UploadedAt *time.Time
}

// ── FileRepository ────────────────────────────────────────────────────────────

// FileRepository manages File persistence.
type FileRepository struct {
	Base
}

// NewFileRepository constructs a FileRepository.
func NewFileRepository(pool *pgxpool.Pool) *FileRepository {
	return &FileRepository{Base: NewBase(pool)}
}

// Create inserts a new File record.
func (r *FileRepository) Create(ctx context.Context, f *File) error {
	const q = `
		INSERT INTO files
		            (id, user_id, sender_device_id, original_name,
		             mime_type, total_size, chunk_size, chunk_count, file_hash,
		             object_key_prefix, status, compressed, transfer_mode,
		             created_at, expires_at)
		VALUES      ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,now(),$14)
		RETURNING   created_at`

	return mapError(
		r.pool.QueryRow(ctx, q,
			f.ID, f.UserID, f.SenderDeviceID, f.OriginalName,
			f.MimeType, f.TotalSize, f.ChunkSize, f.ChunkCount, f.FileHash,
			f.ObjectKeyPrefix, f.Status, f.Compressed, f.TransferMode,
			f.ExpiresAt,
		).Scan(&f.CreatedAt),
	)
}

// FindByID returns the file owned by userID with the given id.
func (r *FileRepository) FindByID(ctx context.Context, id, userID uuid.UUID) (*File, error) {
	const q = `
		SELECT id, user_id, sender_device_id, original_name,
		       mime_type, total_size, stored_size, chunk_size, chunk_count,
		       chunks_received, file_hash, object_key_prefix, thumbnail_key,
		       status, compressed, transfer_mode, is_pinned, pinned_at,
		       created_at, expires_at
		FROM   files
		WHERE  id = $1 AND user_id = $2`

	return r.scanOne(r.pool.QueryRow(ctx, q, id, userID))
}

// FindByUser returns a user's files with pagination.
// Pinned files are sorted first, then by newest creation time.
func (r *FileRepository) FindByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*File, int, error) {
	var total int
	if err := r.pool.QueryRow(ctx,
		`SELECT count(*) FROM files WHERE user_id=$1 AND (expires_at IS NULL OR expires_at>now())`,
		userID,
	).Scan(&total); err != nil {
		return nil, 0, mapError(err)
	}
	if total == 0 {
		return nil, 0, nil
	}

	const q = `
		SELECT id, user_id, sender_device_id, original_name,
		       mime_type, total_size, stored_size, chunk_size, chunk_count,
		       chunks_received, file_hash, object_key_prefix, thumbnail_key,
		       status, compressed, transfer_mode, is_pinned, pinned_at,
		       created_at, expires_at
		FROM   files
		WHERE  user_id = $1 AND (expires_at IS NULL OR expires_at > now())
		ORDER  BY is_pinned DESC, created_at DESC
		LIMIT  $2 OFFSET $3`

	rows, err := r.pool.Query(ctx, q, userID, limit, offset)
	if err != nil {
		return nil, 0, mapError(err)
	}
	defer rows.Close()

	var files []*File
	for rows.Next() {
		f, err := r.scanRow(rows)
		if err != nil {
			return nil, 0, err
		}
		files = append(files, f)
	}
	return files, total, mapError(rows.Err())
}

// UpdateStatus transitions a file to a new status.
func (r *FileRepository) UpdateStatus(ctx context.Context, id, userID uuid.UUID, status FileStatus) error {
	const q = `UPDATE files SET status=$1 WHERE id=$2 AND user_id=$3`
	tag, err := r.pool.Exec(ctx, q, status, id, userID)
	if err != nil {
		return mapError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// IncrementChunksReceived atomically increments chunks_received.
// Returns the new value.
func (r *FileRepository) IncrementChunksReceived(ctx context.Context, id uuid.UUID) (int, error) {
	const q = `
		UPDATE files
		SET    chunks_received = chunks_received + 1,
		       status          = CASE
		                           WHEN status = 'pending' THEN 'uploading'
		                           ELSE status
		                         END
		WHERE  id = $1
		RETURNING chunks_received`

	var n int
	if err := r.pool.QueryRow(ctx, q, id).Scan(&n); err != nil {
		return 0, mapError(err)
	}
	return n, nil
}

// MarkReady sets status='ready', stored_size, compressed flag, and optional thumbnail_key.
func (r *FileRepository) MarkReady(ctx context.Context, id uuid.UUID, storedSize int64, compressed bool, thumbnailKey *string) error {
	const q = `
		UPDATE files
		SET    status        = 'ready',
		       stored_size   = $2,
		       compressed    = $3,
		       thumbnail_key = $4
		WHERE  id = $1`

	tag, err := r.pool.Exec(ctx, q, id, storedSize, compressed, thumbnailKey)
	if err != nil {
		return mapError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// MarkFailed sets status='failed'.
func (r *FileRepository) MarkFailed(ctx context.Context, id uuid.UUID) error {
	const q = `UPDATE files SET status='failed' WHERE id=$1`
	_, err := r.pool.Exec(ctx, q, id)
	return mapError(err)
}

// Delete soft-deletes a file by setting expires_at to now.
// Pinned files cannot be deleted; returns ErrNotFound if the file is pinned
// or doesn't exist.
func (r *FileRepository) Delete(ctx context.Context, id, userID uuid.UUID) error {
	const q = `UPDATE files SET expires_at=now() WHERE id=$1 AND user_id=$2 AND is_pinned=false`
	tag, err := r.pool.Exec(ctx, q, id, userID)
	if err != nil {
		return mapError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SetPinned pins or unpins a file.
//
// Pinning:   is_pinned=true, pinned_at=now(), expires_at=NULL.
// Unpinning: is_pinned=false, pinned_at=NULL,
//            expires_at = now() + retentionMinutes.
func (r *FileRepository) SetPinned(ctx context.Context, id, userID uuid.UUID, pinned bool, retentionMinutes int) error {
	var q string
	var args []any

	if pinned {
		q = `
			UPDATE files
			SET    is_pinned  = true,
			       pinned_at  = now(),
			       expires_at = NULL
			WHERE  id      = $1
			  AND  user_id = $2`
		args = []any{id, userID}
	} else {
		q = `
			UPDATE files
			SET    is_pinned  = false,
			       pinned_at  = NULL,
			       expires_at = now() + ($3 * interval '1 minute')
			WHERE  id      = $1
			  AND  user_id = $2`
		args = []any{id, userID, retentionMinutes}
	}

	tag, err := r.pool.Exec(ctx, q, args...)
	if err != nil {
		return mapError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SumUnpinnedBytes returns stored bytes for unpinned files.
func (r *FileRepository) SumUnpinnedBytes(ctx context.Context, userID uuid.UUID) (int64, error) {
	const q = `
		SELECT COALESCE(SUM(COALESCE(stored_size, total_size)), 0)
		FROM   files
		WHERE  user_id = $1 AND is_pinned = false
		  AND  (expires_at IS NULL OR expires_at > now())`
	var n int64
	err := r.pool.QueryRow(ctx, q, userID).Scan(&n)
	return n, mapError(err)
}

// FindOldestUnpinned returns the oldest unpinned file for eviction.
func (r *FileRepository) FindOldestUnpinned(ctx context.Context, userID uuid.UUID) (*File, error) {
	const q = `
		SELECT id, user_id, sender_device_id, original_name,
		       mime_type, total_size, stored_size, chunk_size, chunk_count,
		       chunks_received, file_hash, object_key_prefix, thumbnail_key,
		       status, compressed, transfer_mode, is_pinned, pinned_at,
		       created_at, expires_at
		FROM   files
		WHERE  user_id = $1 AND is_pinned = false
		  AND  (expires_at IS NULL OR expires_at > now())
		ORDER  BY created_at ASC
		LIMIT  1`
	return r.scanOne(r.pool.QueryRow(ctx, q, userID))
}

// HardDelete permanently removes a file row and returns it for storage GC.
func (r *FileRepository) HardDelete(ctx context.Context, id uuid.UUID) (*File, error) {
	const q = `
		DELETE FROM files
		WHERE  id = $1
		RETURNING id, user_id, sender_device_id, original_name,
		          mime_type, total_size, stored_size, chunk_size, chunk_count,
		          chunks_received, file_hash, object_key_prefix, thumbnail_key,
		          status, compressed, transfer_mode, is_pinned, pinned_at,
		          created_at, expires_at`
	return r.scanOne(r.pool.QueryRow(ctx, q, id))
}

// ── FileChunkRepository ───────────────────────────────────────────────────────

// FileChunkRepository manages chunk tracking for file uploads.
type FileChunkRepository struct {
	Base
}

// NewFileChunkRepository constructs a FileChunkRepository.
func NewFileChunkRepository(pool *pgxpool.Pool) *FileChunkRepository {
	return &FileChunkRepository{Base: NewBase(pool)}
}

// CreateMany inserts pre-created (not yet uploaded) chunk records for fileID.
// This is called during file init so the missing-chunks query always works.
func (r *FileChunkRepository) CreateMany(ctx context.Context, fileID uuid.UUID, chunkCount int, chunkSize int) error {
	batch := make([]FileChunk, chunkCount)
	for i := range batch {
		batch[i] = FileChunk{
			ID:         uuid.New(),
			FileID:     fileID,
			ChunkIndex: i,
			Size:       chunkSize,
		}
	}

	// Use a single multi-value INSERT for efficiency.
	// Build args: ($1,$2,$3,$4,$5), ($6,$7,$8,$9,$10), ...
	args := make([]any, 0, chunkCount*5)
	query := "INSERT INTO file_chunks (id, file_id, chunk_index, chunk_hash, object_key, size) VALUES "
	for i, c := range batch {
		if i > 0 {
			query += ","
		}
		base := i * 6
		query += fmt.Sprintf("($%d,$%d,$%d,$%d,$%d,$%d)", base+1, base+2, base+3, base+4, base+5, base+6)
		args = append(args, c.ID, c.FileID, c.ChunkIndex, "", "", c.Size)
	}

	_, err := r.pool.Exec(ctx, query, args...)
	return mapError(err)
}

// MarkUploaded marks a chunk as uploaded, recording its hash and storage key.
func (r *FileChunkRepository) MarkUploaded(ctx context.Context, fileID uuid.UUID, chunkIndex int, hash, objectKey string, size int) error {
	const q = `
		UPDATE file_chunks
		SET    chunk_hash  = $1,
		       object_key  = $2,
		       size        = $3,
		       uploaded_at = now()
		WHERE  file_id     = $4
		  AND  chunk_index = $5
		  AND  uploaded_at IS NULL`

	tag, err := r.pool.Exec(ctx, q, hash, objectKey, size, fileID, chunkIndex)
	if err != nil {
		return mapError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// FindByFileID returns all chunks for fileID, ordered by chunk_index.
func (r *FileChunkRepository) FindByFileID(ctx context.Context, fileID uuid.UUID) ([]*FileChunk, error) {
	const q = `
		SELECT id, file_id, chunk_index, chunk_hash, object_key, size, uploaded_at
		FROM   file_chunks
		WHERE  file_id = $1
		ORDER  BY chunk_index ASC`

	rows, err := r.pool.Query(ctx, q, fileID)
	if err != nil {
		return nil, mapError(err)
	}
	defer rows.Close()

	var chunks []*FileChunk
	for rows.Next() {
		c := &FileChunk{}
		if err := rows.Scan(
			(*[16]byte)(&c.ID),
			(*[16]byte)(&c.FileID),
			&c.ChunkIndex,
			&c.ChunkHash,
			&c.ObjectKey,
			&c.Size,
			&c.UploadedAt,
		); err != nil {
			return nil, err
		}
		chunks = append(chunks, c)
	}
	return chunks, mapError(rows.Err())
}

// MissingIndices returns chunk indices that have not been uploaded yet.
func (r *FileChunkRepository) MissingIndices(ctx context.Context, fileID uuid.UUID) ([]int, error) {
	const q = `
		SELECT chunk_index
		FROM   file_chunks
		WHERE  file_id     = $1
		  AND  uploaded_at IS NULL
		ORDER  BY chunk_index`

	rows, err := r.pool.Query(ctx, q, fileID)
	if err != nil {
		return nil, mapError(err)
	}
	defer rows.Close()

	var out []int
	for rows.Next() {
		var n int
		if err := rows.Scan(&n); err != nil {
			return nil, err
		}
		out = append(out, n)
	}
	return out, mapError(rows.Err())
}

// DeleteByFileID removes all chunk records for fileID.
// Called after assembly to keep the chunks table lean.
func (r *FileChunkRepository) DeleteByFileID(ctx context.Context, fileID uuid.UUID) error {
	const q = `DELETE FROM file_chunks WHERE file_id = $1`
	_, err := r.pool.Exec(ctx, q, fileID)
	return mapError(err)
}

// ── scan helpers ──────────────────────────────────────────────────────────────

type pgxScanner interface{ Scan(...any) error }

func (r *FileRepository) scanOne(row pgxScanner) (*File, error) {
	f, err := r.scanRow(row)
	if err != nil {
		return nil, mapError(err)
	}
	return f, nil
}

func (r *FileRepository) scanRow(row pgxScanner) (*File, error) {
	var f File
	err := row.Scan(
		(*[16]byte)(&f.ID),
		(*[16]byte)(&f.UserID),
		(*[16]byte)(&f.SenderDeviceID),
		&f.OriginalName,
		&f.MimeType,
		&f.TotalSize,
		&f.StoredSize,
		&f.ChunkSize,
		&f.ChunkCount,
		&f.ChunksReceived,
		&f.FileHash,
		&f.ObjectKeyPrefix,
		&f.ThumbnailKey,
		&f.Status,
		&f.Compressed,
		&f.TransferMode,
		&f.IsPinned,
		&f.PinnedAt,
		&f.CreatedAt,
		&f.ExpiresAt,
	)
	if err != nil {
		return nil, err
	}
	return &f, nil
}
