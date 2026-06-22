package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Device is the in-memory representation of a paired device.
// Nullable DB columns map to pointer types so that a nil clearly signals
// the absence of a value (distinct from an empty string / zero time).
type Device struct {
	ID                uuid.UUID
	UserID            uuid.UUID
	Name              string
	Platform          string // macos | android | ios | web
	PublicKey         []byte
	DeviceFingerprint string
	PushToken         *string
	LastSeenAt        *time.Time
	Trusted           bool
	TrustedUntil      *time.Time
	RevokedAt         *time.Time
	CreatedAt         time.Time
}

// DeviceRepository provides full CRUD access to the devices table.
type DeviceRepository struct {
	Base
}

// NewDeviceRepository constructs a DeviceRepository backed by pool.
func NewDeviceRepository(pool *pgxpool.Pool) *DeviceRepository {
	return &DeviceRepository{Base: NewBase(pool)}
}

// Create inserts a new Device row.
func (r *DeviceRepository) Create(ctx context.Context, d *Device) error {
	const q = `
		INSERT INTO devices
		            (id, user_id, name, platform, public_key, device_fingerprint,
		             trusted, trusted_until, created_at)
		VALUES      ($1, $2, $3, $4, $5, $6, $7, $8, now())
		RETURNING   created_at`

	return mapError(
		r.pool.QueryRow(ctx, q,
			d.ID, d.UserID, d.Name, d.Platform, d.PublicKey, d.DeviceFingerprint,
			d.Trusted, d.TrustedUntil,
		).Scan(&d.CreatedAt),
	)
}

// FindByID returns the device with the given id regardless of revocation state.
// Callers that want only active devices should check RevokedAt themselves, or
// use FindActiveByID.
func (r *DeviceRepository) FindByID(ctx context.Context, id uuid.UUID) (*Device, error) {
	const q = `
		SELECT id, user_id, name, platform, public_key, device_fingerprint,
		       push_token, last_seen_at, trusted, trusted_until, revoked_at, created_at
		FROM   devices
		WHERE  id = $1`

	var d Device
	err := r.pool.QueryRow(ctx, q, id).Scan(
		(*[16]byte)(&d.ID),
		(*[16]byte)(&d.UserID),
		&d.Name, &d.Platform,
		&d.PublicKey, &d.DeviceFingerprint,
		&d.PushToken, &d.LastSeenAt,
		&d.Trusted, &d.TrustedUntil, &d.RevokedAt, &d.CreatedAt,
	)
	if err != nil {
		return nil, mapError(err)
	}
	return &d, nil
}

// FindActiveByID returns a device only when it is not revoked.
func (r *DeviceRepository) FindActiveByID(ctx context.Context, id uuid.UUID) (*Device, error) {
	const q = `
		SELECT id, user_id, name, platform, public_key, device_fingerprint,
		       push_token, last_seen_at, trusted, trusted_until, revoked_at, created_at
		FROM   devices
		WHERE  id         = $1
		  AND  revoked_at IS NULL`

	var d Device
	err := r.pool.QueryRow(ctx, q, id).Scan(
		(*[16]byte)(&d.ID),
		(*[16]byte)(&d.UserID),
		&d.Name, &d.Platform,
		&d.PublicKey, &d.DeviceFingerprint,
		&d.PushToken, &d.LastSeenAt,
		&d.Trusted, &d.TrustedUntil, &d.RevokedAt, &d.CreatedAt,
	)
	if err != nil {
		return nil, mapError(err)
	}
	return &d, nil
}

// FindByUserID returns all active devices belonging to userID, ordered by
// creation date descending.
func (r *DeviceRepository) FindByUserID(ctx context.Context, userID uuid.UUID) ([]*Device, error) {
	const q = `
		SELECT id, user_id, name, platform, public_key, device_fingerprint,
		       push_token, last_seen_at, trusted, trusted_until, revoked_at, created_at
		FROM   devices
		WHERE  user_id   = $1
		  AND  revoked_at IS NULL
		ORDER  BY created_at DESC`

	rows, err := r.pool.Query(ctx, q, userID)
	if err != nil {
		return nil, mapError(err)
	}
	defer rows.Close()

	var devices []*Device
	for rows.Next() {
		var d Device
		if err := rows.Scan(
			(*[16]byte)(&d.ID),
			(*[16]byte)(&d.UserID),
			&d.Name, &d.Platform,
			&d.PublicKey, &d.DeviceFingerprint,
			&d.PushToken, &d.LastSeenAt,
			&d.Trusted, &d.TrustedUntil, &d.RevokedAt, &d.CreatedAt,
		); err != nil {
			return nil, err
		}
		devices = append(devices, &d)
	}
	return devices, mapError(rows.Err())
}

// Revoke stamps revoked_at on the device, immediately invalidating it.
// Does NOT revoke existing sessions; callers must do that separately.
func (r *DeviceRepository) Revoke(ctx context.Context, id uuid.UUID) error {
	const q = `
		UPDATE devices
		SET    revoked_at = now()
		WHERE  id         = $1
		  AND  revoked_at IS NULL`

	tag, err := r.pool.Exec(ctx, q, id)
	if err != nil {
		return mapError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// UpdateTrust sets the trusted flag on a device.
func (r *DeviceRepository) UpdateTrust(ctx context.Context, id uuid.UUID, trusted bool) error {
	const q = `UPDATE devices SET trusted = $1 WHERE id = $2 AND revoked_at IS NULL`

	tag, err := r.pool.Exec(ctx, q, trusted, id)
	if err != nil {
		return mapError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// UpdateLastSeen bumps last_seen_at to now() without touching any other column.
func (r *DeviceRepository) UpdateLastSeen(ctx context.Context, id uuid.UUID) error {
	const q = `UPDATE devices SET last_seen_at = now() WHERE id = $1 AND revoked_at IS NULL`
	_, err := r.pool.Exec(ctx, q, id)
	return mapError(err)
}

// UpdateName sets the user-visible device label.
func (r *DeviceRepository) UpdateName(ctx context.Context, id uuid.UUID, name string) error {
	const q = `UPDATE devices SET name = $2 WHERE id = $1 AND revoked_at IS NULL`

	tag, err := r.pool.Exec(ctx, q, id, name)
	if err != nil {
		return mapError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// CountActiveByUserID returns the number of non-revoked devices for userID.
func (r *DeviceRepository) CountActiveByUserID(ctx context.Context, userID uuid.UUID) (int, error) {
	const q = `SELECT count(*) FROM devices WHERE user_id = $1 AND revoked_at IS NULL`
	var n int
	if err := r.pool.QueryRow(ctx, q, userID).Scan(&n); err != nil {
		return 0, mapError(err)
	}
	return n, nil
}

// UpdateTrustedUntil sets trusted=true and extends the PIN-free trust window.
func (r *DeviceRepository) UpdateTrustedUntil(ctx context.Context, id uuid.UUID, until time.Time) error {
	const q = `
		UPDATE devices
		SET    trusted       = true,
		       trusted_until = $2
		WHERE  id = $1
		  AND  revoked_at IS NULL`

	tag, err := r.pool.Exec(ctx, q, id, until)
	if err != nil {
		return mapError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
