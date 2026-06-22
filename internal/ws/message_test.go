package ws

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestMarshalUnmarshalEnvelope(t *testing.T) {
	env := NewEnvelope(TypePing)
	env.ID = "test-id-1"

	data, err := MarshalEnvelope(env)
	if err != nil {
		t.Fatalf("MarshalEnvelope: %v", err)
	}
	if len(data) == 0 {
		t.Fatal("marshalled envelope is empty")
	}

	got, err := UnmarshalEnvelope(data)
	if err != nil {
		t.Fatalf("UnmarshalEnvelope: %v", err)
	}
	if got.ID != env.ID {
		t.Errorf("ID: got %q, want %q", got.ID, env.ID)
	}
	if got.Type != TypePing {
		t.Errorf("Type: got %q, want %q", got.Type, TypePing)
	}
}

func TestUnmarshalEnvelope_MissingType(t *testing.T) {
	_, err := UnmarshalEnvelope([]byte(`{"id":"x"}`))
	if err == nil {
		t.Error("expected error for missing type field")
	}
}

func TestUnmarshalEnvelope_InvalidJSON(t *testing.T) {
	_, err := UnmarshalEnvelope([]byte(`not json`))
	if err == nil {
		t.Error("expected error for invalid JSON")
	}
}

func TestEncodePong(t *testing.T) {
	pingID := uuid.NewString()
	data, err := EncodePong(pingID)
	if err != nil {
		t.Fatalf("EncodePong: %v", err)
	}

	env, err := UnmarshalEnvelope(data)
	if err != nil {
		t.Fatalf("UnmarshalEnvelope after EncodePong: %v", err)
	}
	if env.Type != TypePong {
		t.Errorf("Type = %q, want %q", env.Type, TypePong)
	}

	var p PongPayload
	if err := json.Unmarshal(env.Payload, &p); err != nil {
		t.Fatalf("decode PongPayload: %v", err)
	}
	if p.EchoID != pingID {
		t.Errorf("EchoID = %q, want %q", p.EchoID, pingID)
	}
}

func TestEncodePresence(t *testing.T) {
	deviceID := uuid.New()
	data, err := EncodePresence(deviceID, StatusOnline, "ios")
	if err != nil {
		t.Fatalf("EncodePresence: %v", err)
	}

	env, err := UnmarshalEnvelope(data)
	if err != nil {
		t.Fatalf("UnmarshalEnvelope: %v", err)
	}
	if env.Type != TypePresence {
		t.Errorf("Type = %q, want %q", env.Type, TypePresence)
	}

	var p PresencePayload
	if err := json.Unmarshal(env.Payload, &p); err != nil {
		t.Fatalf("decode PresencePayload: %v", err)
	}
	if p.DeviceID != deviceID.String() {
		t.Errorf("DeviceID = %q, want %q", p.DeviceID, deviceID.String())
	}
	if p.Status != StatusOnline {
		t.Errorf("Status = %q, want %q", p.Status, StatusOnline)
	}
	if p.Platform != "ios" {
		t.Errorf("Platform = %q, want %q", p.Platform, "ios")
	}
}

func TestEncodeError(t *testing.T) {
	data, err := EncodeError("bad_request", "missing field")
	if err != nil {
		t.Fatalf("EncodeError: %v", err)
	}

	env, err := UnmarshalEnvelope(data)
	if err != nil {
		t.Fatalf("UnmarshalEnvelope: %v", err)
	}
	if env.Type != TypeError {
		t.Errorf("Type = %q, want %q", env.Type, TypeError)
	}

	var p ErrorPayload
	if err := json.Unmarshal(env.Payload, &p); err != nil {
		t.Fatalf("decode ErrorPayload: %v", err)
	}
	if p.Code != "bad_request" {
		t.Errorf("Code = %q, want %q", p.Code, "bad_request")
	}
}

func TestDecodeAckPayload_Valid(t *testing.T) {
	msgID := uuid.NewString()
	env, err := NewEnvelopeWithPayload(TypeAck, AckPayload{MessageID: msgID})
	if err != nil {
		t.Fatalf("NewEnvelopeWithPayload: %v", err)
	}

	got, err := DecodeAckPayload(env)
	if err != nil {
		t.Fatalf("DecodeAckPayload: %v", err)
	}
	if got.MessageID != msgID {
		t.Errorf("MessageID = %q, want %q", got.MessageID, msgID)
	}
}

func TestDecodeAckPayload_MissingMessageID(t *testing.T) {
	env := &Envelope{
		ID:      "x",
		Type:    TypeAck,
		Payload: json.RawMessage(`{"message_id":""}`),
	}
	_, err := DecodeAckPayload(env)
	if err == nil {
		t.Error("expected error for empty message_id")
	}
}

// TestRouting_Ping verifies that the hub responds to a client ping with a pong.
func TestRouting_Ping(t *testing.T) {
	h, cancel := newRunningHub(t)
	defer cancel()

	userID := uuid.New()
	deviceID := uuid.New()

	c := newClient(h, newMockConn(), userID, deviceID, "web")
	h.register <- c
	time.Sleep(20 * time.Millisecond) // let hub process registration

	// Simulate readPump calling hub.route with a ping frame.
	pingEnv := NewEnvelope(TypePing)
	pingEnv.ID = "ping-001"
	raw, _ := MarshalEnvelope(pingEnv)
	h.route(c, raw)

	// Client's send channel should contain a pong.
	pongData := drainSend(t, c, 200*time.Millisecond)
	pongEnv, err := UnmarshalEnvelope(pongData)
	if err != nil {
		t.Fatalf("invalid pong envelope: %v", err)
	}
	if pongEnv.Type != TypePong {
		t.Errorf("expected pong, got %q", pongEnv.Type)
	}

	var p PongPayload
	if err := json.Unmarshal(pongEnv.Payload, &p); err != nil {
		t.Fatalf("decode pong payload: %v", err)
	}
	if p.EchoID != "ping-001" {
		t.Errorf("EchoID = %q, want %q", p.EchoID, "ping-001")
	}
}

// TestRouting_UnknownType verifies that unsupported message types get an error response.
func TestRouting_UnknownType(t *testing.T) {
	h, cancel := newRunningHub(t)
	defer cancel()

	c := newClient(h, newMockConn(), uuid.New(), uuid.New(), "macos")
	h.register <- c
	time.Sleep(20 * time.Millisecond)

	raw, _ := MarshalEnvelope(&Envelope{ID: "x", Type: "clipboard.sync"})
	h.route(c, raw)

	errData := drainSend(t, c, 200*time.Millisecond)
	errEnv, err := UnmarshalEnvelope(errData)
	if err != nil {
		t.Fatalf("invalid error envelope: %v", err)
	}
	if errEnv.Type != TypeError {
		t.Errorf("expected error type, got %q", errEnv.Type)
	}
}
