package ws

// hub_integration_test.go exercises the Hub as a whole: multiple clients
// connecting, broadcasting, presence tracking, graceful shutdown, and
// clipboard.new delivery across the pin/unpin code paths added in Phase 8.
//
// All tests run in the white-box ws package so they can drive the hub
// directly without needing a real WebSocket server.

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
)

// ── helpers ───────────────────────────────────────────────────────────────────

// startHub creates a Hub, runs it in a goroutine, and returns a cancel func.
func startHub(t *testing.T) (*Hub, context.CancelFunc) {
	t.Helper()
	h := NewHub()
	ctx, cancel := context.WithCancel(context.Background())
	go h.Run(ctx)
	return h, cancel
}

// integrateRegisterClient wires a mockConn to the hub and returns the Client.
func integrateRegisterClient(t *testing.T, h *Hub, userID, deviceID uuid.UUID) *Client {
	t.Helper()
	conn := newMockConn()
	client := &Client{
		hub:      h,
		conn:     conn,
		userID:   userID,
		deviceID: deviceID,
		send:     make(chan []byte, 256),
	}
	h.register <- client
	time.Sleep(5 * time.Millisecond) // let hub process registration
	return client
}

// writtenEnvelopes parses all frames captured by a mockConn into Envelopes.
func writtenEnvelopes(conn *mockConn) []Envelope {
	conn.mu.Lock()
	defer conn.mu.Unlock()
	var out []Envelope
	for _, raw := range conn.Written {
		var env Envelope
		if err := json.Unmarshal(raw, &env); err == nil {
			out = append(out, env)
		}
	}
	return out
}

// ── tests ─────────────────────────────────────────────────────────────────────

// TestHub_BroadcastDeliversToAllDevices verifies that Broadcast sends a frame
// to every device belonging to a user.
func TestHub_BroadcastDelivers(t *testing.T) {
	h, cancel := startHub(t)
	defer cancel()

	userID := uuid.New()
	mac := integrateRegisterClient(t, h, userID, uuid.New())
	android := integrateRegisterClient(t, h, userID, uuid.New())

	msg := []byte(`{"type":"test","payload":{}}`)
	h.Broadcast(userID, msg, nil)
	time.Sleep(10 * time.Millisecond)

	// Both clients should receive the message via their send channels.
	for label, client := range map[string]*Client{"mac": mac, "android": android} {
		select {
		case <-client.send:
		default:
			t.Errorf("%s: expected message on send channel", label)
		}
	}
}

// TestHub_BroadcastExcludesSourceDevice verifies the excludeDevice opt-out.
func TestHub_BroadcastExcludesSource(t *testing.T) {
	h, cancel := startHub(t)
	defer cancel()

	userID := uuid.New()
	srcDeviceID := uuid.New()
	otherDeviceID := uuid.New()

	src := integrateRegisterClient(t, h, userID, srcDeviceID)
	other := integrateRegisterClient(t, h, userID, otherDeviceID)

	msg := []byte(`{"type":"clipboard.new","payload":{}}`)
	h.Broadcast(userID, msg, &srcDeviceID)
	time.Sleep(10 * time.Millisecond)

	checkSend := func(label string, client *Client, expectMsg bool) {
		t.Helper()
		select {
		case <-client.send:
			if !expectMsg {
				t.Errorf("%s: received unexpected message", label)
			}
		default:
			if expectMsg {
				t.Errorf("%s: expected message but send channel is empty", label)
			}
		}
	}
	checkSend("source", src, false)
	checkSend("other", other, true)

	q := NewQuerier(h)
	if !q.IsDeviceOnline(srcDeviceID) {
		t.Error("source device should be online")
	}
	if !q.IsDeviceOnline(otherDeviceID) {
		t.Error("other device should be online")
	}
}

// TestHub_PresenceTracking verifies register and unregister update presence.
func TestHub_PresenceTracking(t *testing.T) {
	h, cancel := startHub(t)
	defer cancel()

	userID := uuid.New()
	deviceID := uuid.New()
	q := NewQuerier(h)

	if q.IsDeviceOnline(deviceID) {
		t.Error("device should not be online before registration")
	}

	conn := newMockConn()
	client := &Client{
		hub:      h,
		conn:     conn,
		userID:   userID,
		deviceID: deviceID,
		send:     make(chan []byte, 256),
	}
	h.register <- client
	time.Sleep(5 * time.Millisecond)

	if !q.IsDeviceOnline(deviceID) {
		t.Error("device should be online after registration")
	}

	h.unregister <- client
	time.Sleep(5 * time.Millisecond)

	if q.IsDeviceOnline(deviceID) {
		t.Error("device should be offline after unregistration")
	}
}

// TestHub_MultipleUsers verifies isolation: User A's broadcast doesn't reach User B.
func TestHub_MultipleUsers_Isolated(t *testing.T) {
	h, cancel := startHub(t)
	defer cancel()

	userA := uuid.New()
	userB := uuid.New()
	_ = integrateRegisterClient(t, h, userA, uuid.New())
	clientB := integrateRegisterClient(t, h, userB, uuid.New())

	msg := []byte(`{"type":"clipboard.new","payload":{}}`)
	h.Broadcast(userA, msg, nil)
	time.Sleep(10 * time.Millisecond)

	select {
	case frame := <-clientB.send:
		t.Errorf("userB received userA's broadcast: %s", frame)
	default:
		// Expected: no cross-user leak.
	}
}

// TestHub_OnlineDevices lists devices for a user.
func TestHub_OnlineDevices(t *testing.T) {
	h, cancel := startHub(t)
	defer cancel()

	userID := uuid.New()
	d1 := uuid.New()
	d2 := uuid.New()
	integrateRegisterClient(t, h, userID, d1)
	integrateRegisterClient(t, h, userID, d2)
	time.Sleep(10 * time.Millisecond)

	q := NewQuerier(h)
	online := q.OnlineDevices(userID)
	if len(online) != 2 {
		t.Errorf("OnlineDevices = %d; want 2", len(online))
	}
}

// TestHub_ShutdownGraceful verifies the hub stops cleanly on ctx cancellation.
func TestHub_ShutdownGraceful(t *testing.T) {
	h, cancel := startHub(t)

	userID := uuid.New()
	integrateRegisterClient(t, h, userID, uuid.New())
	time.Sleep(5 * time.Millisecond)

	cancel() // triggers hub shutdown
	time.Sleep(20 * time.Millisecond)

	defer func() {
		if r := recover(); r != nil {
			t.Errorf("Broadcast after shutdown panicked: %v", r)
		}
	}()
	h.Broadcast(userID, []byte(`{}`), nil)
}

// TestHub_ClipboardPinMessage verifies the clipboard.pin WS message type
// encodes correctly and can be broadcast.
func TestHub_ClipboardPinMessage(t *testing.T) {
	h, cancel := startHub(t)
	defer cancel()

	userID := uuid.New()
	deviceID := uuid.New()
	client := &Client{
		hub:      h,
		conn:     newMockConn(),
		userID:   userID,
		deviceID: deviceID,
		send:     make(chan []byte, 256),
	}
	h.register <- client
	time.Sleep(5 * time.Millisecond)

	data, err := EncodeClipboardPin(uuid.New().String(), true, time.Now().UTC().Format(time.RFC3339))
	if err != nil {
		t.Fatalf("EncodeClipboardPin: %v", err)
	}
	h.Broadcast(userID, data, nil)
	time.Sleep(5 * time.Millisecond)

	select {
	case frame := <-client.send:
		var env Envelope
		if err := json.Unmarshal(frame, &env); err != nil {
			t.Fatalf("unmarshal: %v", err)
		}
		if env.Type != TypeClipboardPin {
			t.Errorf("type = %q; want %q", env.Type, TypeClipboardPin)
		}
	case <-time.After(50 * time.Millisecond):
		t.Error("timed out waiting for clipboard.pin frame")
	}
}

// TestHub_FilePinMessage verifies the file.pin WS message type.
func TestHub_FilePinMessage(t *testing.T) {
	data, err := EncodeFilePin(uuid.New().String(), false, "")
	if err != nil {
		t.Fatalf("EncodeFilePin: %v", err)
	}
	var env Envelope
	if err := json.Unmarshal(data, &env); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if env.Type != TypeFilePin {
		t.Errorf("type = %q; want %q", env.Type, TypeFilePin)
	}
}
