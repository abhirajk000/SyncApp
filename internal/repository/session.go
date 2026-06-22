package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Session represents an active refresh-token session in the sessions table.
// Only the SHA-256 hash of the refresh token JWT is stored, never the raw token.
type Session struct {
	ID             uuid.UUID
	DeviceID       uuid.UUID
	TokenHash      string     // SHA-256(refresh_token_jwt), hex-encoded
	WSConnectionID *string
	IPAddress      *string
	IssuedAt       time.Time
	ExpiresAt      time.Time
	RevokedAt      *time.Time
}

// SessionRepository handles refresh-token session lifecycle.
type SessionRepository struct {
	Base
}

// NewSessionRepository constructs a SessionRepository.
func NewSessionRepository(pool *pgxpool.Pool) *SessionRepository {
	return &SessionRepository{Base: NewBase(pool)}
}

// Create persists a new session row.
func (r *SessionRepository) Create(ctx context.Context, s *Session) error {
	const q = `
		INSERT INTO sessions (id, device_id, token_hash, ip_address, issued_at, expires_at)
		VALUES ($1, $2, $3, $4::inet, now(), $5)
		RETURNING issued_at`

	return mapError(
		r.pool.QueryRow(ctx, q,
			s.ID, s.DeviceID, s.TokenHash, s.IPAddress, s.ExpiresAt,
		).Scan(&s.IssuedAt),
	)
}

// FindByTokenHash returns an active, non-expired session matching the hash,
// or ErrNotFound.
func (r *SessionRepository) FindByTokenHash(ctx context.Context, hash string) (*Session, error) {
	const q = `
		SELECT id, device_id, token_hash, ws_connection_id,
		       ip_address::text, issued_at, expires_at, revoked_at
		FROM   sessions
		WHERE  token_hash = $1
		  AND  revoked_at IS NULL
		  AND  expires_at > now()`

	var s Session
	err := r.pool.QueryRow(ctx, q, hash).Scan(
		(*[16]byte)(&s.ID),
		(*[16]byte)(&s.DeviceID),
		&s.TokenHash,
		&s.WSConnectionID,
		&s.IPAddress,
		&s.IssuedAt,
		&s.ExpiresAt,
		&s.RevokedAt,
	)
	if err != nil {
		return nil, mapError(err)
	}
	return &s, nil
}

// Revoke marks a single session as revoked by its token hash.
// Returns ErrNotFound when the session doesn't exist or is already revoked.
func (r *SessionRepository) Revoke(ctx context.Context, tokenHash string) error {
	const q = `
		UPDATE sessions
		SET    revoked_at = now()
		WHERE  token_hash = $1
		  AND  revoked_at IS NULL`

	tag, err := r.pool.Exec(ctx, q, tokenHash)
	if err != nil {
		return mapError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// RevokeAllForDevice revokes every active session belonging to deviceID.
// Used when a device is revoked or during account-wide logout.
func (r *SessionRepository) RevokeAllForDevice(ctx context.Context, deviceID uuid.UUID) error {
	const q = `
		UPDATE sessions
		SET    revoked_at = now()
		WHERE  device_id  = $1
		  AND  revoked_at IS NULL`

	_, err := r.pool.Exec(ctx, q, deviceID)
	return mapError(err)
}

// FindActiveByDeviceID returns all non-expired, non-revoked sessions for a device.
func (r *SessionRepository) FindActiveByDeviceID(ctx context.Context, deviceID uuid.UUID) ([]*Session, error) {
	const q = `
		SELECT id, device_id, token_hash, ws_connection_id,
		       ip_address::text, issued_at, expires_at, revoked_at
		FROM   sessions
		WHERE  device_id  = $1
		  AND  revoked_at IS NULL
		  AND  expires_at > now()
		ORDER  BY issued_at DESC`

	rows, err := r.pool.Query(ctx, q, deviceID)
	if err != nil {
		return nil, mapError(err)
	}
	defer rows.Close()

	var sessions []*Session
	for rows.Next() {
		var s Session
		if err := rows.Scan(
			(*[16]byte)(&s.ID),
			(*[16]byte)(&s.DeviceID),
			&s.TokenHash,
			&s.WSConnectionID,
			&s.IPAddress,
			&s.IssuedAt,
			&s.ExpiresAt,
			&s.RevokedAt,
		); err != nil {
			return nil, mapError(err)
		}
		sessions = append(sessions, &s)
	}
	return sessions, mapError(rows.Err())
}
