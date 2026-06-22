package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// VectorClock maps deviceID (string UUID) to a Unix nanosecond timestamp.
// Stored as JSONB in the database.
type VectorClock map[string]int64

// MaxTimestamp returns the highest value in the clock.
// Used for Last-Writer-Wins conflict resolution.
func (vc VectorClock) MaxTimestamp() int64 {
	var max int64
	for _, v := range vc {
		if v > max {
			max = v
		}
	}
	return max
}

// HappensBefore reports whether vc causally precedes other.
// Returns true if every clock entry in vc is ≤ the corresponding entry in other,
// and at least one is strictly less.
func (vc VectorClock) HappensBefore(other VectorClock) bool {
	atLeastOneLess := false
	for k, v := range vc {
		otherV := other[k]
		if v > otherV {
			return false
		}
		if otherV > v {
			atLeastOneLess = true
		}
	}
	// If vc has fewer entries than other, those missing entries count as 0 < other[k].
	if !atLeastOneLess && len(vc) < len(other) {
		atLeastOneLess = true
	}
	return atLeastOneLess
}

// Merge returns a new VectorClock with the element-wise maximum of vc and other.
func (vc VectorClock) Merge(other VectorClock) VectorClock {
	result := make(VectorClock, len(vc)+len(other))
	for k, v := range vc {
		result[k] = v
	}
	for k, v := range other {
		if existing, ok := result[k]; !ok || v > existing {
			result[k] = v
		}
	}
	return result
}

// ── ClipboardEntry ────────────────────────────────────────────────────────────

// ClipboardEntry is one clipboard item (plaintext at rest).
type ClipboardEntry struct {
	ID             uuid.UUID
	UserID         uuid.UUID
	SourceDeviceID uuid.UUID
	ContentType    string
	Content        string
	ContentHash    string
	PlaintextSize  int
	VectorClock    VectorClock
	Pinned         bool
	PinnedAt       *time.Time
	CreatedAt      time.Time
	ExpiresAt      *time.Time
}

// ── ClipboardRepository ───────────────────────────────────────────────────────

// ClipboardRepository provides persistence for clipboard entries.
type ClipboardRepository struct {
	Base
}

// NewClipboardRepository constructs a ClipboardRepository.
func NewClipboardRepository(pool *pgxpool.Pool) *ClipboardRepository {
	return &ClipboardRepository{Base: NewBase(pool)}
}

// Create inserts a new ClipboardEntry and returns ErrDuplicate on hash collision.
func (r *ClipboardRepository) Create(ctx context.Context, e *ClipboardEntry) error {
	vcJSON, err := json.Marshal(e.VectorClock)
	if err != nil {
		return err
	}

	const q = `
		INSERT INTO clipboard_entries
		            (id, user_id, source_device_id, content_type,
		             content, content_hash, plaintext_size,
		             vector_clock, pinned, pinned_at, created_at, expires_at)
		VALUES      ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, now(), $11)
		RETURNING   created_at`

	return mapError(
		r.pool.QueryRow(ctx, q,
			e.ID, e.UserID, e.SourceDeviceID, e.ContentType,
			e.Content, e.ContentHash, e.PlaintextSize,
			vcJSON, e.Pinned, e.PinnedAt, e.ExpiresAt,
		).Scan(&e.CreatedAt),
	)
}

// FindByID returns the entry for the given id belonging to userID.
func (r *ClipboardRepository) FindByID(ctx context.Context, id, userID uuid.UUID) (*ClipboardEntry, error) {
	const q = `
		SELECT id, user_id, source_device_id, content_type,
		       content, content_hash, plaintext_size,
		       vector_clock, pinned, pinned_at, created_at, expires_at
		FROM   clipboard_entries
		WHERE  id      = $1
		  AND  user_id = $2`

	return r.scanOne(r.pool.QueryRow(ctx, q, id, userID))
}

// FindByContentHash returns an existing unexpired entry with the same dedup hash,
// or ErrNotFound.
func (r *ClipboardRepository) FindByContentHash(ctx context.Context, userID uuid.UUID, hash string) (*ClipboardEntry, error) {
	const q = `
		SELECT id, user_id, source_device_id, content_type,
		       content, content_hash, plaintext_size,
		       vector_clock, pinned, pinned_at, created_at, expires_at
		FROM   clipboard_entries
		WHERE  user_id          = $1
		  AND  content_hash  = $2
		  AND  (expires_at IS NULL OR expires_at > now())
		ORDER  BY created_at DESC
		LIMIT  1`

	return r.scanOne(r.pool.QueryRow(ctx, q, userID, hash))
}

// FindLatestByUser returns up to limit recent entries for userID, newest first.
// It does NOT decrypt — callers must decrypt each entry.
func (r *ClipboardRepository) FindLatestByUser(ctx context.Context, userID uuid.UUID, limit int) ([]*ClipboardEntry, error) {
	const q = `
		SELECT id, user_id, source_device_id, content_type,
		       content, content_hash, plaintext_size,
		       vector_clock, pinned, pinned_at, created_at, expires_at
		FROM   clipboard_entries
		WHERE  user_id  = $1
		  AND  (expires_at IS NULL OR expires_at > now())
		ORDER  BY created_at DESC
		LIMIT  $2`

	rows, err := r.pool.Query(ctx, q, userID, limit)
	if err != nil {
		return nil, mapError(err)
	}
	defer rows.Close()

	var entries []*ClipboardEntry
	for rows.Next() {
		e, err := r.scanRow(rows)
		if err != nil {
			return nil, err
		}
		entries = append(entries, e)
	}
	return entries, mapError(rows.Err())
}

// FindByUser returns a paginated list of entries for userID.
// Pinned items are sorted first, then by newest creation time.
func (r *ClipboardRepository) FindByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*ClipboardEntry, int, error) {
	var total int
	countQ := `SELECT count(*) FROM clipboard_entries WHERE user_id=$1 AND (expires_at IS NULL OR expires_at>now())`
	if err := r.pool.QueryRow(ctx, countQ, userID).Scan(&total); err != nil {
		return nil, 0, mapError(err)
	}
	if total == 0 {
		return nil, 0, nil
	}

	const q = `
		SELECT id, user_id, source_device_id, content_type,
		       content, content_hash, plaintext_size,
		       vector_clock, pinned, pinned_at, created_at, expires_at
		FROM   clipboard_entries
		WHERE  user_id  = $1
		  AND  (expires_at IS NULL OR expires_at > now())
		ORDER  BY pinned DESC, created_at DESC
		LIMIT  $2 OFFSET $3`

	rows, err := r.pool.Query(ctx, q, userID, limit, offset)
	if err != nil {
		return nil, 0, mapError(err)
	}
	defer rows.Close()

	var entries []*ClipboardEntry
	for rows.Next() {
		e, err := r.scanRow(rows)
		if err != nil {
			return nil, 0, err
		}
		entries = append(entries, e)
	}
	return entries, total, mapError(rows.Err())
}

// DeleteByID soft-deletes (by expiring immediately) the entry if it belongs to userID.
func (r *ClipboardRepository) DeleteByID(ctx context.Context, id, userID uuid.UUID) error {
	const q = `
		UPDATE clipboard_entries
		SET    expires_at = now()
		WHERE  id      = $1
		  AND  user_id = $2
		  AND  pinned  = false`

	tag, err := r.pool.Exec(ctx, q, id, userID)
	if err != nil {
		return mapError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SetPinned pins or unpins an entry.
//
// Pinning:   sets pinned=true, pinned_at=now(), expires_at=NULL (immortal).
// Unpinning: sets pinned=false, pinned_at=NULL,
//            expires_at = now() + retentionMinutes (re-arms the expiry timer).
func (r *ClipboardRepository) SetPinned(ctx context.Context, id, userID uuid.UUID, pinned bool, retentionMinutes int) error {
	var q string
	var args []any

	if pinned {
		q = `
			UPDATE clipboard_entries
			SET    pinned    = true,
			       pinned_at = now(),
			       expires_at = NULL
			WHERE  id      = $1
			  AND  user_id = $2`
		args = []any{id, userID}
	} else {
		q = `
			UPDATE clipboard_entries
			SET    pinned    = false,
			       pinned_at = NULL,
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

// SumUnpinnedBytes returns total plaintext bytes of unpinned clipboard entries.
func (r *ClipboardRepository) SumUnpinnedBytes(ctx context.Context, userID uuid.UUID) (int64, error) {
	const q = `
		SELECT COALESCE(SUM(plaintext_size), 0)
		FROM   clipboard_entries
		WHERE  user_id = $1 AND pinned = false
		  AND  (expires_at IS NULL OR expires_at > now())`
	var n int64
	err := r.pool.QueryRow(ctx, q, userID).Scan(&n)
	return n, mapError(err)
}

// FindOldestUnpinned returns the oldest unpinned entry for eviction.
func (r *ClipboardRepository) FindOldestUnpinned(ctx context.Context, userID uuid.UUID) (*ClipboardEntry, error) {
	const q = `
		SELECT id, user_id, source_device_id, content_type,
		       content, content_hash, plaintext_size,
		       vector_clock, pinned, pinned_at, created_at, expires_at
		FROM   clipboard_entries
		WHERE  user_id = $1 AND pinned = false
		  AND  (expires_at IS NULL OR expires_at > now())
		ORDER  BY created_at ASC
		LIMIT  1`
	return r.scanOne(r.pool.QueryRow(ctx, q, userID))
}

// HardDelete permanently removes a clipboard entry.
func (r *ClipboardRepository) HardDelete(ctx context.Context, id, userID uuid.UUID) error {
	const q = `DELETE FROM clipboard_entries WHERE id = $1 AND user_id = $2`
	tag, err := r.pool.Exec(ctx, q, id, userID)
	if err != nil {
		return mapError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// PurgeExpired hard-deletes entries whose expires_at has passed.
// Intended for a scheduled cleanup job (Phase 7).
func (r *ClipboardRepository) PurgeExpired(ctx context.Context) (int64, error) {
	const q = `DELETE FROM clipboard_entries WHERE expires_at IS NOT NULL AND expires_at < now() AND pinned = false`
	tag, err := r.pool.Exec(ctx, q)
	if err != nil {
		return 0, mapError(err)
	}
	return tag.RowsAffected(), nil
}

// ── scan helpers ──────────────────────────────────────────────────────────────

// pgxRow is a common interface satisfied by pgx Row and Rows (for scanOne/scanRow).
type pgxRow interface {
	Scan(dest ...any) error
}

func (r *ClipboardRepository) scanOne(row pgxRow) (*ClipboardEntry, error) {
	e, err := r.scanRow(row)
	if err != nil {
		return nil, mapError(err)
	}
	return e, nil
}

func (r *ClipboardRepository) scanRow(row pgxRow) (*ClipboardEntry, error) {
	var (
		e       ClipboardEntry
		vcBytes []byte
	)
	err := row.Scan(
		(*[16]byte)(&e.ID),
		(*[16]byte)(&e.UserID),
		(*[16]byte)(&e.SourceDeviceID),
		&e.ContentType,
		&e.Content,
		&e.ContentHash,
		&e.PlaintextSize,
		&vcBytes,
		&e.Pinned,
		&e.PinnedAt,
		&e.CreatedAt,
		&e.ExpiresAt,
	)
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(vcBytes, &e.VectorClock); err != nil {
		return nil, fmt.Errorf("unmarshal vector_clock: %w", err)
	}
	return &e, nil
}
