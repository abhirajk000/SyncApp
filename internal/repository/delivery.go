package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// FileDeliveryRepository tracks which devices received a file.
type FileDeliveryRepository struct {
	Base
}

func NewFileDeliveryRepository(pool *pgxpool.Pool) *FileDeliveryRepository {
	return &FileDeliveryRepository{Base: NewBase(pool)}
}

// MarkDelivered records that deviceID received fileID.
func (r *FileDeliveryRepository) MarkDelivered(ctx context.Context, fileID, deviceID uuid.UUID) error {
	const q = `
		INSERT INTO file_deliveries (file_id, device_id)
		VALUES ($1, $2)
		ON CONFLICT (file_id, device_id) DO NOTHING`
	_, err := r.pool.Exec(ctx, q, fileID, deviceID)
	return mapError(err)
}

// CountDeliveries returns how many distinct devices (excluding sender) confirmed delivery.
func (r *FileDeliveryRepository) CountDeliveries(ctx context.Context, fileID, senderDeviceID uuid.UUID) (int, error) {
	const q = `
		SELECT count(*)
		FROM   file_deliveries
		WHERE  file_id = $1 AND device_id <> $2`
	var n int
	err := r.pool.QueryRow(ctx, q, fileID, senderDeviceID).Scan(&n)
	return n, mapError(err)
}

// HasDelivered reports whether deviceID already confirmed fileID.
func (r *FileDeliveryRepository) HasDelivered(ctx context.Context, fileID, deviceID uuid.UUID) (bool, error) {
	const q = `SELECT EXISTS(SELECT 1 FROM file_deliveries WHERE file_id=$1 AND device_id=$2)`
	var ok bool
	err := r.pool.QueryRow(ctx, q, fileID, deviceID).Scan(&ok)
	return ok, mapError(err)
}
