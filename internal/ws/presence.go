package ws

import (
	"time"

	"github.com/google/uuid"
)

// Querier is a read-only view of the Hub's presence state.
// It is safe to call from any goroutine; all reads go through the Hub's
// sync.Map and never block the Run goroutine.
//
// Intended consumers:
//   - Phase 5 clipboard sync (decide WS push vs. poll)
//   - Phase 6 file transfer (discover online peers)
//   - REST handlers returning device status
type Querier struct {
	hub *Hub
}

// NewQuerier creates a Querier backed by hub.
func NewQuerier(hub *Hub) *Querier {
	return &Querier{hub: hub}
}

// IsDeviceOnline reports whether deviceID has an active WebSocket connection.
func (q *Querier) IsDeviceOnline(deviceID uuid.UUID) bool {
	return q.hub.IsDeviceOnline(deviceID)
}

// IsUserOnline reports whether any device of userID is currently connected.
func (q *Querier) IsUserOnline(userID uuid.UUID) bool {
	return q.hub.IsOnline(userID)
}

// OnlineDevices returns the presence snapshot for every connected device of
// userID.  Returns nil (not an empty slice) when no devices are online.
func (q *Querier) OnlineDevices(userID uuid.UUID) []PresenceInfo {
	return q.hub.OnlineDevices(userID)
}

// ConnectedAt returns the time deviceID connected, and false when offline.
func (q *Querier) ConnectedAt(deviceID uuid.UUID) (time.Time, bool) {
	v, ok := q.hub.presence.Load(deviceID)
	if !ok {
		return time.Time{}, false
	}
	return v.(PresenceInfo).ConnectedAt, true
}

// TotalConnections returns the current number of active WebSocket connections
// across all users.  Useful for Prometheus metrics (Phase 7).
func (q *Querier) TotalConnections() int {
	return q.hub.ConnectedCount()
}

// ── Presence snapshot for REST handlers ──────────────────────────────────────

// DeviceStatus is a lightweight presence snapshot returned to REST callers.
type DeviceStatus struct {
	DeviceID    uuid.UUID `json:"device_id"`
	UserID      uuid.UUID `json:"user_id"`
	Platform    string    `json:"platform"`
	Online      bool      `json:"online"`
	ConnectedAt *time.Time `json:"connected_at,omitempty"`
}

// DeviceStatusFor returns a DeviceStatus for deviceID.
func (q *Querier) DeviceStatusFor(deviceID uuid.UUID) DeviceStatus {
	v, ok := q.hub.presence.Load(deviceID)
	if !ok {
		return DeviceStatus{DeviceID: deviceID, Online: false}
	}
	info := v.(PresenceInfo)
	t := info.ConnectedAt
	return DeviceStatus{
		DeviceID:    info.DeviceID,
		UserID:      info.UserID,
		Platform:    info.Platform,
		Online:      true,
		ConnectedAt: &t,
	}
}
