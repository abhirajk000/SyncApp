package ws

import (
	"sync/atomic"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
)

// ── Tuning constants ──────────────────────────────────────────────────────────
// These are intentionally conservative; adjust in Phase 7 under load.

const (
	// writeWait is the deadline for a single write operation.
	writeWait = 10 * time.Second

	// pongWait is the time the server waits for a Pong after sending a Ping.
	// A client that doesn't pong within this window is closed.
	pongWait = 60 * time.Second

	// pingPeriod is how often the server sends a protocol-level Ping.
	// Must be < pongWait so the deadline is always reached AFTER the ping.
	pingPeriod = (pongWait * 9) / 10 // 54 s

	// maxInboundBytes caps the read size to prevent a malicious client from
	// causing large allocations.  Control messages (ping/ack) are small.
	maxInboundBytes = 8 * 1024 // 8 KB

	// sendBuf is the capacity of the Client's outbound channel.
	// Provides a burst buffer; if it fills the client is considered slow
	// and the connection is closed.
	sendBuf = 256
)

// ── Connection interface ──────────────────────────────────────────────────────

// Conn is the minimal WebSocket connection interface used by Client.
// It is satisfied by *websocket.Conn from github.com/gofiber/websocket/v2
// and by mockConn in tests.
//
// Keeping this narrow (8 methods) means tests don't need to stub rarely-used
// gorilla APIs and the production type can evolve independently.
type Conn interface {
	ReadMessage() (messageType int, p []byte, err error)
	WriteMessage(messageType int, data []byte) error
	SetReadDeadline(t time.Time) error
	SetWriteDeadline(t time.Time) error
	SetReadLimit(limit int64)
	SetPongHandler(h func(appData string) error)
	Close() error
}

// WebSocket frame type constants, mirroring gorilla/websocket values so the
// ws package has no direct import dependency on the websocket library.
const (
	TextMessage  = 1
	PingMessage  = 9
	CloseMessage = 8
)

// ── Client ────────────────────────────────────────────────────────────────────

// Client represents one active WebSocket connection.
//
// Concurrency model:
//   - readPump runs in the goroutine that called ServeWS (the Fiber handler goroutine).
//   - writePump runs in exactly one new goroutine spawned on registration.
//   - All writes to conn are owned by writePump — never call conn.WriteMessage
//     from any other goroutine.
//   - The Hub communicates with the Client exclusively via the send channel.
type Client struct {
	hub      *Hub
	conn     Conn
	userID   uuid.UUID
	deviceID uuid.UUID
	platform string

	// send is the outbound message queue.
	// writePump drains it; callers must never write to send after Close.
	send chan []byte

	// closed is set atomically to prevent double-unregister races.
	closed atomic.Bool
}

// newClient allocates a Client. send channel is buffered to sendBuf.
func newClient(hub *Hub, conn Conn, userID, deviceID uuid.UUID, platform string) *Client {
	return &Client{
		hub:      hub,
		conn:     conn,
		userID:   userID,
		deviceID: deviceID,
		platform: platform,
		send:     make(chan []byte, sendBuf),
	}
}

// Send enqueues data for delivery.
// Returns false if the send channel is full (slow consumer) or closed.
// Callers should treat false as "connection lost" and stop sending.
func (c *Client) Send(data []byte) bool {
	if c.closed.Load() {
		return false
	}
	select {
	case c.send <- data:
		return true
	default:
		return false
	}
}

// close drains and closes the send channel exactly once, signalling writePump
// to terminate.  Called by the hub after unregistering the client.
func (c *Client) close() {
	if c.closed.CompareAndSwap(false, true) {
		close(c.send)
	}
}

// ── Pumps ─────────────────────────────────────────────────────────────────────

// readPump runs in the calling goroutine (the Fiber WebSocket handler).
// It blocks until the connection closes, then requests unregistration.
//
// All inbound frames are dispatched to hub.route for processing.
func (c *Client) readPump() {
	defer func() {
		// Signal hub; writePump will finish after hub closes c.send.
		c.hub.unregister <- c
	}()

	c.conn.SetReadLimit(maxInboundBytes)

	// Extend read deadline on every received Pong frame (protocol-level).
	_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		return c.conn.SetReadDeadline(time.Now().Add(pongWait))
	})

	for {
		_, raw, err := c.conn.ReadMessage()
		if err != nil {
			// Any error (EOF, close frame, deadline exceeded) ends the read loop.
			log.Debug().
				Err(err).
				Str("device_id", c.deviceID.String()).
				Msg("ws: read error, closing client")
			break
		}
		c.hub.route(c, raw)
	}
}

// writePump runs in its own goroutine (spawned by the hub on registration).
// It drains the send channel and sends periodic Ping frames.
// It is the SOLE writer to c.conn to avoid concurrent write races.
func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		// Closing the conn here causes readPump's next read to return an error,
		// which triggers unregistration (the happy path for mutual termination).
		_ = c.conn.Close()
	}()

	for {
		select {
		case data, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// Hub closed the channel — send a close frame and exit.
				_ = c.conn.WriteMessage(CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(TextMessage, data); err != nil {
				log.Debug().
					Err(err).
					Str("device_id", c.deviceID.String()).
					Msg("ws: write error, closing client")
				return
			}

		case <-ticker.C:
			// Send a WebSocket protocol-level Ping to detect silent disconnects.
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(PingMessage, []byte{}); err != nil {
				return
			}
		}
	}
}
