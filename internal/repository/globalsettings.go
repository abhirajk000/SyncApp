package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// OwnerUserID is the fixed UUID for the single SyncBridge owner account.
var OwnerUserID = uuid.MustParse("00000000-0000-4000-8000-000000000001")

// DefaultMasterPIN is seeded on first migration.
const DefaultMasterPIN = "070901"

// GlobalSettings holds the singleton application configuration row.
type GlobalSettings struct {
	MasterPIN   string
	OwnerUserID uuid.UUID
	UpdatedAt   time.Time
}

// GlobalSettingsRepository reads the singleton global_settings row.
type GlobalSettingsRepository struct {
	Base
}

// NewGlobalSettingsRepository constructs a GlobalSettingsRepository.
func NewGlobalSettingsRepository(pool *pgxpool.Pool) *GlobalSettingsRepository {
	return &GlobalSettingsRepository{Base: NewBase(pool)}
}

// Get returns the global settings row.
func (r *GlobalSettingsRepository) Get(ctx context.Context) (*GlobalSettings, error) {
	const q = `
		SELECT master_pin, owner_user_id, updated_at
		FROM   global_settings
		WHERE  id = 1`

	s := &GlobalSettings{}
	err := r.pool.QueryRow(ctx, q).Scan(
		&s.MasterPIN,
		(*[16]byte)(&s.OwnerUserID),
		&s.UpdatedAt,
	)
	if err != nil {
		return nil, mapError(err)
	}
	return s, nil
}
