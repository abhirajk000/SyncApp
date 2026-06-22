package ws

import (
	"context"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
)

// ── Request types sent to the Hub goroutine ───────────────────────────────────

// deliverReq asks the hub to send data to one specific device.
type deliverReq struct {
	deviceID uuid.UUID
	data     []byte
	// ackID is non-empty when the caller wants delivery confirmation.
	// The hub registers a pending ack waiter keyed by ackID before sending.
	ackID string
}

// broadcastReq asks the hub to send data to every connected device of a user.
type broadcastReq struct {
	userID   uuid.UUID
	data     []byte
	// excludeDevice, if non-nil, is skipped (e.g. don't echo back to sender).
	excludeDevice *uuid.UUID
}

// ── Hub ───────────────────────────────────────────────────────────────────────

// Hub is the central WebSocket connection manager.
//
// Ownership rules (prevents data races without broad locking):
//   - The Run goroutine is the SOLE owner of the `clients` map.
//   - All mutations flow through register/unregister/deliver/broadcast channels.
//   - `presence` is a sync.Map; updated by Run, freely readable by any goroutine.
//   - `pendingAcks` is a sync.Map; registered by callers, resolved by Run.
//
// Memory: ~500 bytes per connected client (excluding send buffer).
// Goroutines per client: 2 (readPump + writePump) + 1 shared Run.
type Hub struct {
	// Owned by Run goroutine only.
	clients map[uuid.UUID]map[uuid.UUID]*Client // userID → deviceID → *Client

	register   chan *Client
	unregister chan *Client
	deliver    chan deliverReq
	broadcast  chan broadcastReq

	// presence is a zero-lock presence snapshot for external readers.
	// Values are PresenceInfo structs.
	presence sync.Map // key: deviceID (uuid.UUID) → PresenceInfo

	// pendingAcks tracks in-flight acks.
	// key: ackID (string) → chan struct{} (closed when ack received)
	pendingAcks sync.Map
}

// PresenceInfo is the value stored in Hub.presence.
type PresenceInfo struct {
	DeviceID    uuid.UUID
	UserID      uuid.UUID
	Platform    string
	ConnectedAt time.Time
}

// NewHub allocates a Hub.  Call Run in a goroutine to start it.
func NewHub() *Hub {
	return &Hub{
		clients:    make(map[uuid.UUID]map[uuid.UUID]*Client),
		register:   make(chan *Client, 64),
		unregister: make(chan *Client, 64),
		deliver:    make(chan deliverReq, 256),
		broadcast:  make(chan broadcastReq, 256),
	}
}

// Run is the hub's main event loop.  It must run in exactly one goroutine.
// It blocks until ctx is cancelled, at which point all connected clients are
// closed gracefully.
func (h *Hub) Run(ctx context.Context) {
	log.Info().Msg("ws hub started")
	for {
		select {
		case <-ctx.Done():
			h.shutdown()
			log.Info().Msg("ws hub stopped")
			return

		case c := <-h.register:
			h.handleRegister(c)

		case c := <-h.unregister:
			h.handleUnregister(c)

		case req := <-h.deliver:
			h.handleDeliver(req)

		case req := <-h.broadcast:
			h.handleBroadcast(req)
		}
	}
}

// ── External send API (safe to call from any goroutine) ──────────────────────

// Deliver sends data to the device identified by deviceID.
// Returns true if the device is currently connected, false otherwise.
// This call never blocks the caller; the delivery is async.
func (h *Hub) Deliver(deviceID uuid.UUID, data []byte) bool {
	if _, online := h.presence.Load(deviceID); !online {
		return false
	}
	h.deliver <- deliverReq{deviceID: deviceID, data: data}
	return true
}

// DeliverWithAck sends data to deviceID and returns an AckWaiter that the
// caller can use to wait for the client's acknowledgement.
// The caller MUST call AckWaiter.Cancel or wait for it to avoid leaks.
func (h *Hub) DeliverWithAck(deviceID uuid.UUID, data []byte) (*AckWaiter, bool) {
	if _, online := h.presence.Load(deviceID); !online {
		return nil, false
	}
	ackID := uuid.NewString()
	ch := make(chan struct{})
	h.pendingAcks.Store(ackID, ch)

	h.deliver <- deliverReq{deviceID: deviceID, data: data, ackID: ackID}
	return &AckWaiter{id: ackID, ch: ch, hub: h}, true
}

// Broadcast sends data to all connected devices of userID.
// excludeDevice, if non-nil, is skipped (pass the sender's deviceID to avoid echo).
func (h *Hub) Broadcast(userID uuid.UUID, data []byte, excludeDevice *uuid.UUID) {
	h.broadcast <- broadcastReq{userID: userID, data: data, excludeDevice: excludeDevice}
}

// IsOnline returns true when at least one device of userID is connected.
func (h *Hub) IsOnline(userID uuid.UUID) bool {
	found := false
	h.presence.Range(func(_, v any) bool {
		if v.(PresenceInfo).UserID == userID {
			found = true
			return false // stop iteration
		}
		return true
	})
	return found
}

// IsDeviceOnline returns true when the specific device is connected.
func (h *Hub) IsDeviceOnline(deviceID uuid.UUID) bool {
	_, ok := h.presence.Load(deviceID)
	return ok
}

// OnlineDevices returns PresenceInfo for every connected device of userID.
func (h *Hub) OnlineDevices(userID uuid.UUID) []PresenceInfo {
	var result []PresenceInfo
	h.presence.Range(func(_, v any) bool {
		if info := v.(PresenceInfo); info.UserID == userID {
			result = append(result, info)
		}
		return true
	})
	return result
}

// ConnectedCount returns the total number of active connections.
func (h *Hub) ConnectedCount() int {
	n := 0
	h.presence.Range(func(_, _ any) bool {
		n++
		return true
	})
	return n
}

// ── Internal message routing ──────────────────────────────────────────────────

// route is called by a client's readPump to dispatch an inbound frame.
// It runs in the client's readPump goroutine, NOT in the hub's Run goroutine.
// It may therefore only touch sync-safe data (pendingAcks) or enqueue work.
func (h *Hub) route(c *Client, raw []byte) {
	env, err := UnmarshalEnvelope(raw)
	if err != nil {
		errFrame, _ := EncodeError("bad_envelope", "invalid JSON envelope")
		c.Send(errFrame)
		return
	}

	switch env.Type {
	case TypePing:
		pong, err := EncodePong(env.ID)
		if err != nil {
			return
		}
		c.Send(pong)

	case TypeAck:
		ack, err := DecodeAckPayload(env)
		if err != nil {
			errFrame, _ := EncodeError("bad_ack", err.Error())
			c.Send(errFrame)
			return
		}
		// Resolve the pending ack waiter, if any.
		if v, ok := h.pendingAcks.LoadAndDelete(ack.MessageID); ok {
			close(v.(chan struct{}))
		}

	default:
		errFrame, _ := EncodeError("unknown_type", "unsupported message type: "+env.Type)
		c.Send(errFrame)
	}
}

// ── Run-goroutine handlers (only called from Run) ─────────────────────────────

func (h *Hub) handleRegister(c *Client) {
	// Ensure the per-user sub-map exists.
	if _, ok := h.clients[c.userID]; !ok {
		h.clients[c.userID] = make(map[uuid.UUID]*Client)
	}

	// If the same device reconnects (e.g. tab reload), evict the old connection.
	if old, ok := h.clients[c.userID][c.deviceID]; ok {
		log.Debug().
			Str("device_id", c.deviceID.String()).
			Msg("ws: evicting stale connection on reconnect")
		old.close()
	}

	h.clients[c.userID][c.deviceID] = c

	// Start writePump in a dedicated goroutine.
	go c.writePump()

	// Update presence snapshot.
	info := PresenceInfo{
		DeviceID:    c.deviceID,
		UserID:      c.userID,
		Platform:    c.platform,
		ConnectedAt: time.Now(),
	}
	h.presence.Store(c.deviceID, info)

	log.Debug().
		Str("user_id", c.userID.String()).
		Str("device_id", c.deviceID.String()).
		Int("total", h.ConnectedCount()).
		Msg("ws: client registered")

	// Notify all other devices of this user that this device came online.
	h.notifyPresence(c, StatusOnline)
}

func (h *Hub) handleUnregister(c *Client) {
	userDevices, ok := h.clients[c.userID]
	if !ok {
		return
	}
	existing, ok := userDevices[c.deviceID]
	if !ok || existing != c {
		// Stale unregister from an already-replaced client; ignore.
		return
	}

	delete(userDevices, c.deviceID)
	if len(userDevices) == 0 {
		delete(h.clients, c.userID)
	}

	// Close the send channel so writePump exits.
	c.close()

	// Remove from presence snapshot.
	h.presence.Delete(c.deviceID)

	log.Debug().
		Str("user_id", c.userID.String()).
		Str("device_id", c.deviceID.String()).
		Int("total", h.ConnectedCount()).
		Msg("ws: client unregistered")

	// Notify remaining devices that this device went offline.
	h.notifyPresence(c, StatusOffline)
}

func (h *Hub) handleDeliver(req deliverReq) {
	userDevices := h.findUserDeviceMap(req.deviceID)
	if userDevices == nil {
		return
	}
	c, ok := userDevices[req.deviceID]
	if !ok {
		return
	}
	if !c.Send(req.data) {
		// Slow or closed consumer; evict.
		h.handleUnregister(c)
	}
}

func (h *Hub) handleBroadcast(req broadcastReq) {
	userDevices, ok := h.clients[req.userID]
	if !ok {
		return
	}
	for devID, c := range userDevices {
		if req.excludeDevice != nil && devID == *req.excludeDevice {
			continue
		}
		if !c.Send(req.data) {
			// Slow consumer — close it.
			h.handleUnregister(c)
		}
	}
}

// notifyPresence broadcasts a presence event to all OTHER devices of the same user.
func (h *Hub) notifyPresence(c *Client, status string) {
	frame, err := EncodePresence(c.deviceID, status, c.platform)
	if err != nil {
		log.Warn().Err(err).Msg("ws: failed to encode presence frame")
		return
	}

	userDevices, ok := h.clients[c.userID]
	if !ok {
		return
	}
	for devID, peer := range userDevices {
		if devID == c.deviceID {
			continue // don't tell the device about itself
		}
		if !peer.Send(frame) {
			h.handleUnregister(peer)
		}
	}
}

// findUserDeviceMap returns the inner map for whatever user owns deviceID.
// Runs in O(U) where U is the number of distinct users — acceptable since
// U is small and this path is only hit for targeted deliveries.
//
// A reverse-lookup map (deviceID → userID) would make this O(1); add it
// in Phase 8 if user counts grow large.
func (h *Hub) findUserDeviceMap(deviceID uuid.UUID) map[uuid.UUID]*Client {
	for _, devices := range h.clients {
		if _, ok := devices[deviceID]; ok {
			return devices
		}
	}
	return nil
}

// shutdown gracefully closes all connections when the context is cancelled.
func (h *Hub) shutdown() {
	for userID, devices := range h.clients {
		for devID, c := range devices {
			c.close()
			delete(devices, devID)
			h.presence.Delete(devID)
		}
		delete(h.clients, userID)
	}
}

// ── AckWaiter ─────────────────────────────────────────────────────────────────

// AckWaiter allows callers to optionally wait for a client to acknowledge
// a delivered message.  Always call Cancel or Wait — never discard it.
//
// Usage:
//
//	waiter, ok := hub.DeliverWithAck(deviceID, data)
//	if !ok { return }
//	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
//	defer cancel()
//	if err := waiter.Wait(ctx); err != nil {
//	    // timeout or context cancelled
//	}
type AckWaiter struct {
	id  string
	ch  chan struct{}
	hub *Hub
}

// Wait blocks until the client sends an ack or ctx expires.
func (w *AckWaiter) Wait(ctx context.Context) error {
	select {
	case <-w.ch:
		return nil
	case <-ctx.Done():
		w.Cancel()
		return ctx.Err()
	}
}

// Cancel removes the pending ack registration without waiting.
// Safe to call multiple times; idempotent.
func (w *AckWaiter) Cancel() {
	if v, ok := w.hub.pendingAcks.LoadAndDelete(w.id); ok {
		// Close the channel so any concurrent Wait returns immediately.
		close(v.(chan struct{}))
	}
}
