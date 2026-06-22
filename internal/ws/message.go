// Package ws implements the SyncBridge real-time WebSocket layer.
// Phase 5: clipboard.new message type.
// Phase 6: signal.offer / signal.answer / signal.ice / signal.peer types.
//
// Architecture overview:
//
//	┌──────────────┐   register/unregister   ┌─────────────────────────────┐
//	│   HTTP/WS    │ ──────────────────────▶ │          Hub                │
//	│   Handler    │                          │  (single goroutine owner)   │
//	└──────────────┘                          │                             │
//	                                          │  clients map                │
//	┌──────────────┐   deliver / broadcast    │  userID→deviceID→*Client   │
//	│  Other       │ ──────────────────────▶ │                             │
//	│  Packages    │ ◀────────────────────── │  presence sync.Map          │
//	│  (Phase 5+)  │   Querier reads         └─────────────────────────────┘
//	└──────────────┘                                    ▲ ▼
//	                                          ┌─────────────────────────────┐
//	                                          │       Client × N            │
//	                                          │  readPump  + writePump      │
//	                                          │  send chan []byte (buf 256) │
//	                                          └─────────────────────────────┘
//
// Message flow (JSON envelopes over WebSocket text frames):
//
//	Client → Server: ping, ack
//	Server → Client: pong, presence, error, (clipboard/file in later phases)
//
// Heartbeat: server sends a WebSocket-protocol Ping frame every 54 s;
//            client must respond with a Pong frame within 60 s or is closed.
//            Application-level {"type":"ping"} is also supported for clients
//            that cannot send protocol-level pings (e.g. browser WebSocket API).
package ws

import (
	"crypto/hmac"
	"crypto/sha1" //nolint:gosec // HMAC-SHA1 is required by coturn's credential spec (RFC 8489)
	"encoding/base64"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// ── Message types ─────────────────────────────────────────────────────────────

const (
	// TypePing is sent client→server to test connectivity.
	TypePing = "ping"
	// TypePong is the server reply to a TypePing.
	TypePong = "pong"
	// TypeAck is sent client→server to acknowledge a delivered message.
	TypeAck = "ack"
	// TypePresence is sent server→client on device online/offline changes.
	TypePresence = "presence"
	// TypeError is sent server→client on protocol or routing errors.
	TypeError = "error"

	// TypeClipboardNew is sent server→client when another device syncs clipboard content.
	// Clients SHOULD send a TypeAck in response.
	TypeClipboardNew = "clipboard.new"

	// ── Phase 6: WebRTC signaling ─────────────────────────────────────────────

	// TypeSignalOffer is sent server→responder when an initiator submits an offer.
	TypeSignalOffer = "signal.offer"
	// TypeSignalAnswer is sent server→initiator when the responder submits an answer.
	TypeSignalAnswer = "signal.answer"
	// TypeSignalICE is sent server→peer to forward a trickle-ICE candidate.
	TypeSignalICE = "signal.ice"
	// TypeSignalPeer is sent server→device when a same-LAN peer is discovered.
	// Clients SHOULD attempt direct connection to the advertised addresses.
	TypeSignalPeer = "signal.peer"

	// ── Phase 7: file synchronisation ────────────────────────────────────────

	// TypeFileProgress is sent server→client after each chunk upload.
	// Clients SHOULD use this to display an upload progress bar on paired devices.
	TypeFileProgress = "file.progress"

	// TypeFileReady is sent server→client when a file finishes assembly.
	// Clients SHOULD present a download prompt to the user.
	TypeFileReady = "file.ready"

	// TypeFileFailed is sent server→client when assembly or integrity check fails.
	TypeFileFailed = "file.failed"

	// ── Phase 8: retention / pin events ──────────────────────────────────────

	// TypeClipboardPin is sent server→all-devices when a clipboard entry is
	// pinned or unpinned on any device.  Clients SHOULD update the pin state
	// in their local cache without re-fetching the full history.
	TypeClipboardPin = "clipboard.pin"

	// TypeFilePin is sent server→all-devices when a file is pinned or unpinned.
	TypeFilePin = "file.pin"
)

// ── Wire format ───────────────────────────────────────────────────────────────

// Envelope is the outer wrapper for every WebSocket message in both directions.
// Clients and server MUST always send valid JSON envelopes.
//
// Wire example:
//
//	{"id":"<uuid>","type":"ping"}
//	{"id":"<uuid>","type":"pong","payload":{"echo_id":"<prev-id>"}}
type Envelope struct {
	// ID is a client-generated UUID for correlation and ack tracking.
	// Server-originated messages also carry a unique ID.
	ID      string          `json:"id"`
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

// ── Payload structs ───────────────────────────────────────────────────────────

// PongPayload echoes the ID of the corresponding ping.
type PongPayload struct {
	EchoID string `json:"echo_id"`
}

// AckPayload confirms receipt of a server-sent message.
type AckPayload struct {
	MessageID string `json:"message_id"`
}

// PresenceStatus values for PresencePayload.Status.
const (
	StatusOnline  = "online"
	StatusOffline = "offline"
)

// PresencePayload announces a device status change to peer devices.
type PresencePayload struct {
	DeviceID string `json:"device_id"`
	Status   string `json:"status"` // "online" | "offline"
	Platform string `json:"platform,omitempty"`
}

// ErrorPayload carries a human-readable error back to the misbehaving client.
type ErrorPayload struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// ── Codec ─────────────────────────────────────────────────────────────────────

// MarshalEnvelope serialises env to JSON.
// It is the only path for creating outbound frames; using a pool eliminates
// a per-message heap allocation on the hot write path.
func MarshalEnvelope(env *Envelope) ([]byte, error) {
	return json.Marshal(env)
}

// UnmarshalEnvelope parses an inbound frame.
func UnmarshalEnvelope(data []byte) (*Envelope, error) {
	var env Envelope
	if err := json.Unmarshal(data, &env); err != nil {
		return nil, fmt.Errorf("parse envelope: %w", err)
	}
	if env.Type == "" {
		return nil, fmt.Errorf("envelope missing type field")
	}
	return &env, nil
}

// ── Builder helpers ───────────────────────────────────────────────────────────

// NewEnvelope creates an Envelope with a fresh UUID.
func NewEnvelope(msgType string) *Envelope {
	return &Envelope{
		ID:   uuid.NewString(),
		Type: msgType,
	}
}

// NewEnvelopeWithPayload creates an Envelope with the given payload marshalled.
func NewEnvelopeWithPayload(msgType string, payload any) (*Envelope, error) {
	b, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshal payload: %w", err)
	}
	return &Envelope{
		ID:      uuid.NewString(),
		Type:    msgType,
		Payload: b,
	}, nil
}

// EncodePong builds and serialises a pong reply to the given ping ID.
func EncodePong(pingID string) ([]byte, error) {
	env, err := NewEnvelopeWithPayload(TypePong, PongPayload{EchoID: pingID})
	if err != nil {
		return nil, err
	}
	return MarshalEnvelope(env)
}

// EncodePresence builds and serialises a presence announcement.
func EncodePresence(deviceID uuid.UUID, status, platform string) ([]byte, error) {
	env, err := NewEnvelopeWithPayload(TypePresence, PresencePayload{
		DeviceID: deviceID.String(),
		Status:   status,
		Platform: platform,
	})
	if err != nil {
		return nil, err
	}
	return MarshalEnvelope(env)
}

// EncodeError builds and serialises an error message.
func EncodeError(code, message string) ([]byte, error) {
	env, err := NewEnvelopeWithPayload(TypeError, ErrorPayload{
		Code:    code,
		Message: message,
	})
	if err != nil {
		return nil, err
	}
	return MarshalEnvelope(env)
}

// ClipboardNewPayload is sent server→client when a new clipboard entry arrives.
// The server decrypts the content before pushing so clients receive plaintext.
type ClipboardNewPayload struct {
	EntryID        string           `json:"entry_id"`
	ContentType    string           `json:"content_type"`
	Content        string           `json:"content"`          // decrypted plaintext
	SourceDeviceID string           `json:"source_device_id"`
	PlaintextSize  int              `json:"plaintext_size"`
	VectorClock    map[string]int64 `json:"vector_clock"`
	CreatedAt      time.Time        `json:"created_at"`
}

// EncodeClipboardNew builds and serialises a clipboard.new notification.
// entry is passed as an opaque struct via a helper interface to avoid coupling
// the ws package to the repository package.
// Callers (service.ClipboardService) call this helper after creating an entry.
//
// Parameters mirror repository.ClipboardEntry fields to avoid an import cycle.
func EncodeClipboardNew(
	entryID, contentType, content, sourceDeviceID string,
	plaintextSize int,
	vectorClock map[string]int64,
	createdAt time.Time,
) ([]byte, error) {
	env, err := NewEnvelopeWithPayload(TypeClipboardNew, ClipboardNewPayload{
		EntryID:        entryID,
		ContentType:    contentType,
		Content:        content,
		SourceDeviceID: sourceDeviceID,
		PlaintextSize:  plaintextSize,
		VectorClock:    vectorClock,
		CreatedAt:      createdAt,
	})
	if err != nil {
		return nil, err
	}
	return MarshalEnvelope(env)
}

// ── Phase 6: signaling payloads ───────────────────────────────────────────────

// SignalOfferPayload carries an SDP offer from the initiating device.
type SignalOfferPayload struct {
	SessionID string `json:"session_id"`
	SDPOffer  string `json:"sdp_offer"`
}

// SignalAnswerPayload carries an SDP answer from the responding device.
type SignalAnswerPayload struct {
	SessionID string `json:"session_id"`
	SDPAnswer string `json:"sdp_answer"`
}

// SignalICEPayload carries one trickle-ICE candidate between peers.
type SignalICEPayload struct {
	SessionID     string `json:"session_id"`
	FromDeviceID  string `json:"from_device_id"`
	Candidate     string `json:"candidate"`
	SDPMid        string `json:"sdp_mid"`
	SDPMLineIndex int    `json:"sdp_mline_index"`
}

// SignalPeerPayload tells a device about a same-LAN peer it can reach directly.
// Devices SHOULD attempt to initiate a WebRTC or raw-socket connection to one
// of the addresses before falling back to the server relay.
type SignalPeerPayload struct {
	DeviceID string   `json:"device_id"`
	Addrs    []string `json:"addrs"`
	Port     int      `json:"port,omitempty"`
}

// EncodeSignalOffer builds and serialises a signal.offer envelope.
func EncodeSignalOffer(sessionID, sdpOffer string) ([]byte, error) {
	env, err := NewEnvelopeWithPayload(TypeSignalOffer, SignalOfferPayload{
		SessionID: sessionID,
		SDPOffer:  sdpOffer,
	})
	if err != nil {
		return nil, err
	}
	return MarshalEnvelope(env)
}

// EncodeSignalAnswer builds and serialises a signal.answer envelope.
func EncodeSignalAnswer(sessionID, sdpAnswer string) ([]byte, error) {
	env, err := NewEnvelopeWithPayload(TypeSignalAnswer, SignalAnswerPayload{
		SessionID: sessionID,
		SDPAnswer: sdpAnswer,
	})
	if err != nil {
		return nil, err
	}
	return MarshalEnvelope(env)
}

// EncodeSignalICE builds and serialises a signal.ice envelope.
func EncodeSignalICE(sessionID, fromDeviceID, candidate, sdpMid string, sdpMLineIndex int) ([]byte, error) {
	env, err := NewEnvelopeWithPayload(TypeSignalICE, SignalICEPayload{
		SessionID:     sessionID,
		FromDeviceID:  fromDeviceID,
		Candidate:     candidate,
		SDPMid:        sdpMid,
		SDPMLineIndex: sdpMLineIndex,
	})
	if err != nil {
		return nil, err
	}
	return MarshalEnvelope(env)
}

// EncodeSignalPeer builds and serialises a signal.peer envelope.
func EncodeSignalPeer(deviceID string, addrs []string, port int) ([]byte, error) {
	env, err := NewEnvelopeWithPayload(TypeSignalPeer, SignalPeerPayload{
		DeviceID: deviceID,
		Addrs:    addrs,
		Port:     port,
	})
	if err != nil {
		return nil, err
	}
	return MarshalEnvelope(env)
}

// ── TURN credential helper ────────────────────────────────────────────────────

// GenerateTURNCredentials produces RFC 8489 time-limited HMAC-SHA1 credentials
// compatible with coturn's --use-auth-secret mode.
//
//	username   = "<unix_expiry>:<device_id>"
//	credential = base64(HMAC-SHA1(secret, username))
//
// Credentials are valid for 24 hours from the moment of generation.
func GenerateTURNCredentials(secret, deviceID string) (username, credential string) {
	expiry := time.Now().Add(24 * time.Hour).Unix()
	username = fmt.Sprintf("%d:%s", expiry, deviceID)
	mac := hmac.New(sha1.New, []byte(secret)) //nolint:gosec
	mac.Write([]byte(username))
	credential = base64.StdEncoding.EncodeToString(mac.Sum(nil))
	return
}

// ── Phase 7: file payloads ────────────────────────────────────────────────────

// FileProgressPayload reports upload progress to paired devices.
type FileProgressPayload struct {
	FileID          string `json:"file_id"`
	ChunksReceived  int    `json:"chunks_received"`
	ChunkCount      int    `json:"chunk_count"`
	ProgressPercent int    `json:"progress_percent"`
}

// FileReadyPayload notifies paired devices that a file is available to download.
type FileReadyPayload struct {
	FileID   string `json:"file_id"`
	MimeType string `json:"mime_type"`
	Name     string `json:"name"` // decrypted filename
}

// FileFailedPayload notifies paired devices that a file transfer failed.
type FileFailedPayload struct {
	FileID string `json:"file_id"`
}

// EncodeFileProgress builds and serialises a file.progress notification.
func EncodeFileProgress(fileID string, received, total int) ([]byte, error) {
	pct := 0
	if total > 0 {
		pct = (received * 100) / total
	}
	env, err := NewEnvelopeWithPayload(TypeFileProgress, FileProgressPayload{
		FileID:          fileID,
		ChunksReceived:  received,
		ChunkCount:      total,
		ProgressPercent: pct,
	})
	if err != nil {
		return nil, err
	}
	return MarshalEnvelope(env)
}

// EncodeFileReady builds and serialises a file.ready notification.
func EncodeFileReady(fileID, mimeType, name string) ([]byte, error) {
	env, err := NewEnvelopeWithPayload(TypeFileReady, FileReadyPayload{
		FileID:   fileID,
		MimeType: mimeType,
		Name:     name,
	})
	if err != nil {
		return nil, err
	}
	return MarshalEnvelope(env)
}

// EncodeFileFailed builds and serialises a file.failed notification.
func EncodeFileFailed(fileID string) ([]byte, error) {
	env, err := NewEnvelopeWithPayload(TypeFileFailed, FileFailedPayload{FileID: fileID})
	if err != nil {
		return nil, err
	}
	return MarshalEnvelope(env)
}

// ── Phase 8: pin event payloads ───────────────────────────────────────────────

// ClipboardPinPayload is the payload for TypeClipboardPin events.
type ClipboardPinPayload struct {
	EntryID  string `json:"entry_id"`
	Pinned   bool   `json:"pinned"`
	PinnedAt string `json:"pinned_at,omitempty"` // RFC3339; empty when unpinned
}

// FilePinPayload is the payload for TypeFilePin events.
type FilePinPayload struct {
	FileID   string `json:"file_id"`
	Pinned   bool   `json:"pinned"`
	PinnedAt string `json:"pinned_at,omitempty"` // RFC3339; empty when unpinned
}

// EncodeClipboardPin builds and serialises a clipboard.pin event.
func EncodeClipboardPin(entryID string, pinned bool, pinnedAt string) ([]byte, error) {
	env, err := NewEnvelopeWithPayload(TypeClipboardPin, ClipboardPinPayload{
		EntryID:  entryID,
		Pinned:   pinned,
		PinnedAt: pinnedAt,
	})
	if err != nil {
		return nil, err
	}
	return MarshalEnvelope(env)
}

// EncodeFilePin builds and serialises a file.pin event.
func EncodeFilePin(fileID string, pinned bool, pinnedAt string) ([]byte, error) {
	env, err := NewEnvelopeWithPayload(TypeFilePin, FilePinPayload{
		FileID:   fileID,
		Pinned:   pinned,
		PinnedAt: pinnedAt,
	})
	if err != nil {
		return nil, err
	}
	return MarshalEnvelope(env)
}

// DecodeAckPayload extracts the AckPayload from an envelope.
func DecodeAckPayload(env *Envelope) (*AckPayload, error) {
	var p AckPayload
	if err := json.Unmarshal(env.Payload, &p); err != nil {
		return nil, fmt.Errorf("decode ack payload: %w", err)
	}
	if p.MessageID == "" {
		return nil, fmt.Errorf("ack payload missing message_id")
	}
	return &p, nil
}
