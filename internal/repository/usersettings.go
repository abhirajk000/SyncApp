package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ── Valid retention values ────────────────────────────────────────────────────

// ValidRetentionMinutes is the set of retention values accepted by the API.
var ValidRetentionMinutes = map[int]bool{
	30:   true, // 30 minutes
	60:   true, // 1 hour
	120:  true, // 2 hours (default)
	360:  true, // 6 hours
	1440: true, // 24 hours
}

// DefaultRetentionMinutes is used when a user has no explicit preference.
const DefaultRetentionMinutes = 120

// ── UserSettings domain model ─────────────────────────────────────────────────

// UserSettings holds one row from the user_settings table.
type UserSettings struct {
	UserID           uuid.UUID
	RetentionMinutes int
	UpdatedAt        time.Time
}

// ── UserSettingsRepository ────────────────────────────────────────────────────

// UserSettingsRepository manages per-user retention preferences.
type UserSettingsRepository struct {
	Base
}

// NewUserSettingsRepository constructs a UserSettingsRepository.
func NewUserSettingsRepository(pool *pgxpool.Pool) *UserSettingsRepository {
	return &UserSettingsRepository{Base: NewBase(pool)}
}

// Get returns the settings for userID.
// Returns default settings (120 min) if no row exists yet.
func (r *UserSettingsRepository) Get(ctx context.Context, userID uuid.UUID) (*UserSettings, error) {
	const q = `
		SELECT user_id, retention_minutes, updated_at
		FROM   user_settings
		WHERE  user_id = $1`

	s := &UserSettings{}
	err := r.pool.QueryRow(ctx, q, userID).Scan(
		(*[16]byte)(&s.UserID),
		&s.RetentionMinutes,
		&s.UpdatedAt,
	)
	if err != nil {
		mapped := mapError(err)
		if mapped == ErrNotFound {
			return &UserSettings{
				UserID:           userID,
				RetentionMinutes: DefaultRetentionMinutes,
				UpdatedAt:        time.Now(),
			}, nil
		}
		return nil, mapped
	}
	return s, nil
}

// Upsert creates or updates the retention preference for userID.
// Returns ErrInvalidInput if minutes is not a valid retention value.
func (r *UserSettingsRepository) Upsert(ctx context.Context, userID uuid.UUID, minutes int) error {
	if !ValidRetentionMinutes[minutes] {
		return ErrInvalidInput
	}
	const q = `
		INSERT INTO user_settings (user_id, retention_minutes, updated_at)
		VALUES ($1, $2, now())
		ON CONFLICT (user_id) DO UPDATE
		SET retention_minutes = EXCLUDED.retention_minutes,
		    updated_at        = now()`

	_, err := r.pool.Exec(ctx, q, userID, minutes)
	return mapError(err)
}
