package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// AuditEvent represents a single immutable security event written to audit_logs.
// EventData is a free-form map serialised as JSONB.
type AuditEvent struct {
	ID        uuid.UUID
	UserID    *uuid.UUID
	DeviceID  *uuid.UUID
	EventType string         // e.g. "user.registered", "device.revoked", "auth.login_failed"
	EventData map[string]any // arbitrary context; never contains secrets
	IPAddress *string
	UserAgent *string
	CreatedAt time.Time
}

// Predefined event type constants used across the codebase.
const (
	EventUserRegistered   = "user.registered"
	EventUserLogin        = "user.login"
	EventUserLoginFailed  = "user.login_failed"
	EventUserLogout       = "user.logout"
	EventTokenRefreshed   = "token.refreshed"
	EventDeviceRegistered = "device.registered"
	EventDeviceRevoked    = "device.revoked"
	EventDeviceTrusted    = "device.trusted"
	EventPairingInitiated = "pairing.initiated"
	EventPairingCompleted = "pairing.completed"
	EventPairingFailed    = "pairing.failed"
)

// AuditRepository writes security events to the append-only audit_logs table.
type AuditRepository struct {
	Base
}

// NewAuditRepository constructs an AuditRepository.
func NewAuditRepository(pool *pgxpool.Pool) *AuditRepository {
	return &AuditRepository{Base: NewBase(pool)}
}

// Log appends event to the audit trail. Errors are intentionally soft-logged
// by callers; a failure here must never break the primary operation.
func (r *AuditRepository) Log(ctx context.Context, event *AuditEvent) error {
	if event.ID == uuid.Nil {
		event.ID = uuid.New()
	}

	const q = `
		INSERT INTO audit_logs
		            (id, user_id, device_id, event_type, event_data, ip_address, user_agent)
		VALUES      ($1, $2, $3, $4, $5, $6::inet, $7)
		RETURNING   created_at`

	return mapError(
		r.pool.QueryRow(ctx, q,
			event.ID,
			event.UserID,
			event.DeviceID,
			event.EventType,
			event.EventData,
			event.IPAddress,
			event.UserAgent,
		).Scan(&event.CreatedAt),
	)
}
