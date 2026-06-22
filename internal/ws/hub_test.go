// Tests are in package ws (white-box) so they can access unexported fields
// and call internal hub methods directly — avoiding goroutine timing races
// that would arise if tests only used public channels.
package ws

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
)

// ── mockConn ──────────────────────────────────────────────────────────────────

// mockConn implements ws.Conn for testing.
// It captures all written frames in Written and drives reads via Reads.
type mockConn struct {
	mu          sync.Mutex
	Written     [][]byte       // frames captured by WriteMessage
	Reads       chan []byte     // push frames here to simulate inbound data
	closeErr    error          // non-nil after Close()
	pongHandler func(string) error
	closed      bool
}

func newMockConn() *mockConn {
	return &mockConn{
		Reads: make(chan []byte, 32),
	}
}

func (m *mockConn) ReadMessage() (int, []byte, error) {
	data, ok := <-m.Reads
	if !ok {
		return CloseMessage, nil, errors.New("connection closed")
	}
	return TextMessage, data, nil
}

func (m *mockConn) WriteMessage(_ int, data []byte) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.closed {
		return errors.New("use of closed connection")
	}
	// Copy so callers can safely check after the channel advances.
	buf := make([]byte, len(data))
	copy(buf, data)
	m.Written = append(m.Written, buf)
	return nil
}

func (m *mockConn) SetReadDeadline(_ time.Time) error  { return nil }
func (m *mockConn) SetWriteDeadline(_ time.Time) error { return nil }
func (m *mockConn) SetReadLimit(_ int64)               {}

func (m *mockConn) SetPongHandler(h func(string) error) {
	m.mu.Lock()
	m.pongHandler = h
	m.mu.Unlock()
}

func (m *mockConn) Close() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if !m.closed {
		m.closed = true
		close(m.Reads)
	}
	return nil
}

// lastWritten returns a copy of the last frame written, or nil.
func (m *mockConn) lastWritten() []byte {
	m.mu.Lock()
	defer m.mu.Unlock()
	if len(m.Written) == 0 {
		return nil
	}
	return m.Written[len(m.Written)-1]
}

// ── helper: spin up a hub + background Run ────────────────────────────────────

func newRunningHub(t *testing.T) (*Hub, context.CancelFunc) {
	t.Helper()
	h := NewHub()
	ctx, cancel := context.WithCancel(context.Background())
	go h.Run(ctx)
	return h, cancel
}

// registerClient registers a client with the hub and waits for the
// registration to be processed (send channel is confirmed writable).
func registerClient(t *testing.T, h *Hub, userID, deviceID uuid.UUID, platform string) (*Client, *mockConn) {
	t.Helper()
	conn := newMockConn()
	c := newClient(h, conn, userID, deviceID, platform)
	h.register <- c

	// Wait until the writePump goroutine is live: writePump drains send, so a
	// successful non-blocking send confirms the hub processed the registration.
	deadline := time.Now().Add(500 * time.Millisecond)
	for time.Now().Before(deadline) {
		if cap(c.send) > 0 {
			return c, conn
		}
		time.Sleep(time.Millisecond)
	}
	return c, conn
}

// drainSend reads one message from c.send within timeout.
func drainSend(t *testing.T, c *Client, timeout time.Duration) []byte {
	t.Helper()
	select {
	case data := <-c.send:
		return data
	case <-time.After(timeout):
		t.Fatalf("timeout waiting for message on device %s", c.deviceID)
		return nil
	}
}

// ── Tests ─────────────────────────────────────────────────────────────────────

func TestHub_RegisterUnregister(t *testing.T) {
	h, cancel := newRunningHub(t)
	defer cancel()

	userID := uuid.New()
	deviceID := uuid.New()

	// Register
	conn := newMockConn()
	c := newClient(h, conn, userID, deviceID, "macos")
	h.register <- c
	time.Sleep(20 * time.Millisecond) // let hub process

	if !h.IsDeviceOnline(deviceID) {
		t.Error("device should be online after register")
	}
	if h.ConnectedCount() != 1 {
		t.Errorf("ConnectedCount = %d, want 1", h.ConnectedCount())
	}

	// Unregister
	h.unregister <- c
	time.Sleep(20 * time.Millisecond)

	if h.IsDeviceOnline(deviceID) {
		t.Error("device should be offline after unregister")
	}
	if h.ConnectedCount() != 0 {
		t.Errorf("ConnectedCount = %d, want 0", h.ConnectedCount())
	}
}

func TestHub_PresenceOnConnect(t *testing.T) {
	h, cancel := newRunningHub(t)
	defer cancel()

	userID := uuid.New()
	peer1 := uuid.New()
	peer2 := uuid.New()

	// Register peer1 first.
	conn1 := newMockConn()
	c1 := newClient(h, conn1, userID, peer1, "macos")
	h.register <- c1
	time.Sleep(20 * time.Millisecond)

	// Register peer2 — peer1 should receive an "online" presence event.
	conn2 := newMockConn()
	c2 := newClient(h, conn2, userID, peer2, "ios")
	h.register <- c2
	time.Sleep(20 * time.Millisecond)

	// peer1 should have received a presence frame for peer2.
	data := drainSend(t, c1, 200*time.Millisecond)

	env, err := UnmarshalEnvelope(data)
	if err != nil {
		t.Fatalf("invalid envelope: %v", err)
	}
	if env.Type != TypePresence {
		t.Errorf("expected presence type, got %q", env.Type)
	}

	_ = c2 // silence unused warning; writePump blocks on nil conn
}

func TestHub_PresenceOnDisconnect(t *testing.T) {
	h, cancel := newRunningHub(t)
	defer cancel()

	userID := uuid.New()
	peer1 := uuid.New()
	peer2 := uuid.New()

	conn1 := newMockConn()
	c1 := newClient(h, conn1, userID, peer1, "macos")
	h.register <- c1
	time.Sleep(20 * time.Millisecond)

	conn2 := newMockConn()
	c2 := newClient(h, conn2, userID, peer2, "android")
	h.register <- c2
	time.Sleep(20 * time.Millisecond)
	// Drain the "peer2 online" presence sent to c1.
	_ = drainSend(t, c1, 200*time.Millisecond)

	// Disconnect peer2.
	h.unregister <- c2
	time.Sleep(20 * time.Millisecond)

	// c1 should receive a "peer2 offline" presence frame.
	data := drainSend(t, c1, 200*time.Millisecond)
	env, err := UnmarshalEnvelope(data)
	if err != nil {
		t.Fatalf("invalid envelope: %v", err)
	}
	if env.Type != TypePresence {
		t.Errorf("expected presence type, got %q", env.Type)
	}
}

func TestHub_Deliver(t *testing.T) {
	h, cancel := newRunningHub(t)
	defer cancel()

	userID := uuid.New()
	deviceID := uuid.New()

	conn := newMockConn()
	c := newClient(h, conn, userID, deviceID, "ios")
	h.register <- c
	time.Sleep(20 * time.Millisecond)

	payload := []byte(`{"id":"test","type":"custom"}`)
	delivered := h.Deliver(deviceID, payload)
	if !delivered {
		t.Error("Deliver() should return true for connected device")
	}

	data := drainSend(t, c, 200*time.Millisecond)
	if string(data) != string(payload) {
		t.Errorf("delivered data = %s, want %s", data, payload)
	}
}

func TestHub_DeliverOfflineDevice(t *testing.T) {
	h, cancel := newRunningHub(t)
	defer cancel()

	delivered := h.Deliver(uuid.New(), []byte(`{}`))
	if delivered {
		t.Error("Deliver() should return false for offline device")
	}
}

func TestHub_Broadcast(t *testing.T) {
	h, cancel := newRunningHub(t)
	defer cancel()

	userID := uuid.New()
	d1, d2, d3 := uuid.New(), uuid.New(), uuid.New()

	c1conn := newMockConn()
	c1 := newClient(h, c1conn, userID, d1, "macos")
	h.register <- c1

	c2conn := newMockConn()
	c2 := newClient(h, c2conn, userID, d2, "ios")
	h.register <- c2

	c3conn := newMockConn()
	c3 := newClient(h, c3conn, userID, d3, "android")
	h.register <- c3

	time.Sleep(30 * time.Millisecond)
	// Drain presence events sent during registration.
	for len(c1.send) > 0 { <-c1.send }
	for len(c2.send) > 0 { <-c2.send }
	for len(c3.send) > 0 { <-c3.send }

	payload := []byte(`{"id":"bcast","type":"test"}`)
	// Broadcast excluding d1 (the sender).
	h.Broadcast(userID, payload, &d1)
	time.Sleep(20 * time.Millisecond)

	// c2 and c3 should receive it.
	if got := drainSend(t, c2, 200*time.Millisecond); string(got) != string(payload) {
		t.Errorf("c2 got %s, want %s", got, payload)
	}
	if got := drainSend(t, c3, 200*time.Millisecond); string(got) != string(payload) {
		t.Errorf("c3 got %s, want %s", got, payload)
	}

	// c1 should NOT receive its own broadcast.
	select {
	case <-c1.send:
		t.Error("c1 should not receive its own broadcast")
	case <-time.After(50 * time.Millisecond):
		// expected
	}
}

func TestHub_BroadcastIsolatesUsers(t *testing.T) {
	h, cancel := newRunningHub(t)
	defer cancel()

	userA := uuid.New()
	userB := uuid.New()

	cA := newClient(h, newMockConn(), userA, uuid.New(), "macos")
	cB := newClient(h, newMockConn(), userB, uuid.New(), "ios")
	h.register <- cA
	h.register <- cB
	time.Sleep(30 * time.Millisecond)
	for len(cA.send) > 0 { <-cA.send }
	for len(cB.send) > 0 { <-cB.send }

	// Broadcast to userA only.
	h.Broadcast(userA, []byte(`{"id":"a","type":"x"}`), nil)
	time.Sleep(20 * time.Millisecond)

	// userB's client should not receive anything.
	select {
	case msg := <-cB.send:
		t.Errorf("userB should not receive userA's broadcast, got: %s", msg)
	case <-time.After(50 * time.Millisecond):
		// expected
	}
}

func TestHub_AckResolution(t *testing.T) {
	h, cancel := newRunningHub(t)
	defer cancel()

	userID := uuid.New()
	deviceID := uuid.New()

	c := newClient(h, newMockConn(), userID, deviceID, "web")
	h.register <- c
	time.Sleep(20 * time.Millisecond)

	payload := []byte(`{"id":"msg1","type":"event"}`)
	waiter, ok := h.DeliverWithAck(deviceID, payload)
	if !ok {
		t.Fatal("DeliverWithAck should succeed for online device")
	}

	// Drain and discard the delivered payload from the send channel.
	drainSend(t, c, 200*time.Millisecond)

	// Simulate the client sending an ack back.
	// We do this by calling hub.route directly (as the readPump would).
	ackEnv, err := NewEnvelopeWithPayload(TypeAck, AckPayload{MessageID: waiter.id})
	if err != nil {
		t.Fatalf("build ack envelope: %v", err)
	}
	ackBytes, _ := MarshalEnvelope(ackEnv)
	h.route(c, ackBytes)

	// waiter.Wait should return immediately.
	ctx, cancelCtx := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancelCtx()
	if err := waiter.Wait(ctx); err != nil {
		t.Errorf("Wait() returned unexpected error: %v", err)
	}
}

func TestHub_AckTimeout(t *testing.T) {
	h, cancel := newRunningHub(t)
	defer cancel()

	userID := uuid.New()
	deviceID := uuid.New()

	c := newClient(h, newMockConn(), userID, deviceID, "macos")
	h.register <- c
	time.Sleep(20 * time.Millisecond)

	_, ok := h.DeliverWithAck(deviceID, []byte(`{}`))
	if !ok {
		t.Fatal("DeliverWithAck should succeed for online device")
	}

	// Don't send an ack — Wait should time out.
	ctx, cancelCtx := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancelCtx()

	// Create a new waiter manually to test Cancel path.
	ackID := uuid.NewString()
	ch := make(chan struct{})
	h.pendingAcks.Store(ackID, ch)
	waiter := &AckWaiter{id: ackID, ch: ch, hub: h}

	if err := waiter.Wait(ctx); err == nil {
		t.Error("expected timeout error, got nil")
	}

	// After Cancel, the channel should be closed (no goroutine leak).
	if _, ok := h.pendingAcks.Load(ackID); ok {
		t.Error("pendingAck should be removed after Cancel")
	}
}

func TestHub_ReconnectEvictsStaleClient(t *testing.T) {
	h, cancel := newRunningHub(t)
	defer cancel()

	userID := uuid.New()
	deviceID := uuid.New()

	// First connection.
	c1 := newClient(h, newMockConn(), userID, deviceID, "ios")
	h.register <- c1
	time.Sleep(20 * time.Millisecond)

	// Second connection with the same device (reconnect).
	c2 := newClient(h, newMockConn(), userID, deviceID, "ios")
	h.register <- c2
	time.Sleep(20 * time.Millisecond)

	// Only the new client should be in the hub.
	if h.ConnectedCount() != 1 {
		t.Errorf("ConnectedCount = %d, want 1 (stale client should be evicted)", h.ConnectedCount())
	}

	// Old send channel should be closed (c1.closed = true).
	if !c1.closed.Load() {
		t.Error("stale client should be marked closed after reconnect eviction")
	}
}

func TestHub_OnlineDevicesQuery(t *testing.T) {
	h, cancel := newRunningHub(t)
	defer cancel()

	userID := uuid.New()
	d1, d2 := uuid.New(), uuid.New()

	h.register <- newClient(h, newMockConn(), userID, d1, "macos")
	h.register <- newClient(h, newMockConn(), userID, d2, "ios")
	time.Sleep(30 * time.Millisecond)

	devices := h.OnlineDevices(userID)
	if len(devices) != 2 {
		t.Errorf("OnlineDevices count = %d, want 2", len(devices))
	}
}

func TestHub_Shutdown(t *testing.T) {
	h, cancel := newRunningHub(t)

	userID := uuid.New()
	for i := 0; i < 5; i++ {
		h.register <- newClient(h, newMockConn(), userID, uuid.New(), "web")
	}
	time.Sleep(30 * time.Millisecond)

	if h.ConnectedCount() != 5 {
		t.Fatalf("expected 5 connections before shutdown, got %d", h.ConnectedCount())
	}

	// Cancel context → Run exits and calls shutdown().
	cancel()
	time.Sleep(50 * time.Millisecond)

	if h.ConnectedCount() != 0 {
		t.Errorf("expected 0 connections after shutdown, got %d", h.ConnectedCount())
	}
}
