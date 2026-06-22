package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// LocalPeer records the LAN addresses a device has self-reported.
// Used by the signaling service to detect when two devices are on the
// same subnet and hint them to attempt a direct connection.
type LocalPeer struct {
	ID       uuid.UUID
	UserID   uuid.UUID
	DeviceID uuid.UUID
	// Addrs is a list of bare IPv4/IPv6 strings (no port), e.g. ["192.168.1.5"].
	Addrs     []string
	Port      int
	UpdatedAt time.Time
	ExpiresAt time.Time
}

// LocalPeerRepository manages local-peer LAN address records.
type LocalPeerRepository struct {
	Base
}

// NewLocalPeerRepository constructs a LocalPeerRepository.
func NewLocalPeerRepository(pool *pgxpool.Pool) *LocalPeerRepository {
	return &LocalPeerRepository{Base: NewBase(pool)}
}

// Upsert inserts or replaces the local-peer record for lp.DeviceID.
// The UNIQUE(device_id) constraint drives the conflict resolution.
func (r *LocalPeerRepository) Upsert(ctx context.Context, lp *LocalPeer) error {
	addrsJSON, err := json.Marshal(lp.Addrs)
	if err != nil {
		return fmt.Errorf("marshal addrs: %w", err)
	}

	const q = `
		INSERT INTO local_peers (id, user_id, device_id, addrs, port, updated_at, expires_at)
		VALUES ($1, $2, $3, $4, $5, now(), $6)
		ON CONFLICT (device_id) DO UPDATE
		    SET addrs      = EXCLUDED.addrs,
		        port       = EXCLUDED.port,
		        updated_at = now(),
		        expires_at = EXCLUDED.expires_at
		RETURNING updated_at`

	return mapError(
		r.pool.QueryRow(ctx, q,
			lp.ID, lp.UserID, lp.DeviceID, addrsJSON, lp.Port, lp.ExpiresAt,
		).Scan(&lp.UpdatedAt),
	)
}

// FindByUserID returns all non-expired local-peer records for userID.
// Used to find potential same-LAN peers.
func (r *LocalPeerRepository) FindByUserID(ctx context.Context, userID uuid.UUID) ([]*LocalPeer, error) {
	const q = `
		SELECT id, user_id, device_id, addrs, port, updated_at, expires_at
		FROM   local_peers
		WHERE  user_id    = $1
		  AND  expires_at > now()`

	rows, err := r.pool.Query(ctx, q, userID)
	if err != nil {
		return nil, mapError(err)
	}
	defer rows.Close()

	var peers []*LocalPeer
	for rows.Next() {
		lp, err := r.scanRow(rows)
		if err != nil {
			return nil, err
		}
		peers = append(peers, lp)
	}
	return peers, mapError(rows.Err())
}

// DeleteByDeviceID removes the local-peer record for a specific device.
// Called on clean disconnect.
func (r *LocalPeerRepository) DeleteByDeviceID(ctx context.Context, deviceID uuid.UUID) error {
	const q = `DELETE FROM local_peers WHERE device_id = $1`
	_, err := r.pool.Exec(ctx, q, deviceID)
	return mapError(err)
}

// PurgeExpired hard-deletes expired local-peer rows.
func (r *LocalPeerRepository) PurgeExpired(ctx context.Context) (int64, error) {
	const q = `DELETE FROM local_peers WHERE expires_at < now()`
	tag, err := r.pool.Exec(ctx, q)
	if err != nil {
		return 0, mapError(err)
	}
	return tag.RowsAffected(), nil
}

// ── scan helpers ──────────────────────────────────────────────────────────────

func (r *LocalPeerRepository) scanRow(row interface{ Scan(...any) error }) (*LocalPeer, error) {
	var (
		lp        LocalPeer
		addrsJSON []byte
	)
	err := row.Scan(
		(*[16]byte)(&lp.ID),
		(*[16]byte)(&lp.UserID),
		(*[16]byte)(&lp.DeviceID),
		&addrsJSON,
		&lp.Port,
		&lp.UpdatedAt,
		&lp.ExpiresAt,
	)
	if err != nil {
		return nil, mapError(err)
	}
	if err := json.Unmarshal(addrsJSON, &lp.Addrs); err != nil {
		return nil, fmt.Errorf("unmarshal addrs: %w", err)
	}
	return &lp, nil
}
