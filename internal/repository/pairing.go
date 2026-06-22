package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// PairingStatus values match the CHECK constraint in the migration.
const (
	PairingStatusPending   = "pending"
	PairingStatusCompleted = "completed"
	PairingStatusExpired   = "expired"
	PairingStatusCancelled = "cancelled"
)

// PairingRequest models a QR code pairing session.
// An initiator device creates one; the scanning device calls confirm.
type PairingRequest struct {
	ID                uuid.UUID
	InitiatorDeviceID uuid.UUID
	OTP               string // 6-digit random code embedded in the QR payload
	Challenge         []byte // random bytes reserved for Phase 7 crypto-challenge
	Status            string
	CreatedAt         time.Time
	ExpiresAt         time.Time
}

// PairingRepository manages QR pairing lifecycle.
type PairingRepository struct {
	Base
}

// NewPairingRepository constructs a PairingRepository.
func NewPairingRepository(pool *pgxpool.Pool) *PairingRepository {
	return &PairingRepository{Base: NewBase(pool)}
}

// Create inserts a new PairingRequest.
func (r *PairingRepository) Create(ctx context.Context, p *PairingRequest) error {
	const q = `
		INSERT INTO pairing_requests
		            (id, initiator_device_id, otp, challenge, status, created_at, expires_at)
		VALUES      ($1, $2, $3, $4, 'pending', now(), $5)
		RETURNING   created_at`

	return mapError(
		r.pool.QueryRow(ctx, q,
			p.ID, p.InitiatorDeviceID, p.OTP, p.Challenge, p.ExpiresAt,
		).Scan(&p.CreatedAt),
	)
}

// FindPendingByOTP returns the unexpired pending request matching otp,
// or ErrNotFound.
func (r *PairingRepository) FindPendingByOTP(ctx context.Context, otp string) (*PairingRequest, error) {
	const q = `
		SELECT id, initiator_device_id, otp, challenge, status, created_at, expires_at
		FROM   pairing_requests
		WHERE  otp      = $1
		  AND  status   = 'pending'
		  AND  expires_at > now()`

	var p PairingRequest
	err := r.pool.QueryRow(ctx, q, otp).Scan(
		(*[16]byte)(&p.ID),
		(*[16]byte)(&p.InitiatorDeviceID),
		&p.OTP,
		&p.Challenge,
		&p.Status,
		&p.CreatedAt,
		&p.ExpiresAt,
	)
	if err != nil {
		return nil, mapError(err)
	}
	return &p, nil
}

// UpdateStatus transitions a pairing request to a new status.
func (r *PairingRepository) UpdateStatus(ctx context.Context, id uuid.UUID, status string) error {
	const q = `UPDATE pairing_requests SET status = $1 WHERE id = $2`

	tag, err := r.pool.Exec(ctx, q, status, id)
	if err != nil {
		return mapError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ExpirePending bulk-transitions all overdue pending requests to "expired".
// Intended to be called by a background cleanup goroutine (future Phase 7).
func (r *PairingRepository) ExpirePending(ctx context.Context) (int64, error) {
	const q = `
		UPDATE pairing_requests
		SET    status = 'expired'
		WHERE  status = 'pending'
		  AND  expires_at <= now()`

	tag, err := r.pool.Exec(ctx, q)
	if err != nil {
		return 0, mapError(err)
	}
	return tag.RowsAffected(), nil
}
