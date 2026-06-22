// Package signaling manages WebRTC peer-to-peer signaling sessions.
//
// Architecture overview:
//
//	Device A (initiator)              Server                Device B (responder)
//	     │                              │                         │
//	     │  POST /signal                │                         │
//	     │  {responder_id, sdp_offer}──▶│                         │
//	     │                              │──WS signal.offer────────▶│
//	     │                              │                         │
//	     │                              │◀─POST /signal/:id/answer─│
//	     │◀─WS signal.answer────────────│                         │
//	     │                              │                         │
//	     │  POST /signal/:id/ice ──────▶│──WS signal.ice──────────▶│
//	     │◀─WS signal.ice───────────────│◀─POST /signal/:id/ice───│
//	     │                              │                         │
//	     │◀═══════ WebRTC DataChannel (P2P, server not involved) ══│
//	     │                              │                         │
//	     │  POST /signal/:id/connected ▶│◀ POST /signal/:id/connected
//	                                    │  state → active
//
// Sessions are kept in-memory only (sync.Map + TTL).
// Phase 7: back with Redis for horizontal scale.
//
// Session lifecycle:
//   pending  → offered  (offer received)
//   offered  → answered (answer received)
//   answered → active   (both sides report P2P connected)
//   any      → failed   (explicit failure or TTL expiry)
package signaling

import (
	"errors"
	"sync"
	"sync/atomic"
	"time"

	"github.com/google/uuid"
)

// ── Sentinel errors ───────────────────────────────────────────────────────────

var (
	ErrSessionNotFound   = errors.New("signaling session not found")
	ErrSessionExpired    = errors.New("signaling session expired")
	ErrWrongDevice       = errors.New("device is not a party to this session")
	ErrInvalidTransition = errors.New("invalid state transition")
)

// ── State machine ─────────────────────────────────────────────────────────────

// State represents one step in the session lifecycle.
type State string

const (
	StatePending  State = "pending"  // created, waiting for SDP offer
	StateOffered  State = "offered"  // initiator submitted SDP offer
	StateAnswered State = "answered" // responder submitted SDP answer; ICE in progress
	StateActive   State = "active"   // both parties confirmed P2P is established
	StateFailed   State = "failed"   // ICE failed, timeout, or explicit failure
)

// ── ICE candidates ────────────────────────────────────────────────────────────

// ICECandidateRecord is one ICE candidate from either party.
type ICECandidateRecord struct {
	DeviceID      string    `json:"device_id"`
	Candidate     string    `json:"candidate"`
	SDPMid        string    `json:"sdp_mid"`
	SDPMLineIndex int       `json:"sdp_mline_index"`
	AddedAt       time.Time `json:"added_at"`
}

// ── Session ───────────────────────────────────────────────────────────────────

// Session holds the state for one WebRTC negotiation between two devices.
// All exported methods are goroutine-safe.
type Session struct {
	mu sync.RWMutex

	ID          string
	UserID      uuid.UUID
	InitiatorID uuid.UUID // device that called CreateOffer
	ResponderID uuid.UUID // device that should answer
	State       State
	SDPOffer    string
	SDPAnswer   string
	Candidates  []ICECandidateRecord

	// connectedCount reaches 2 when both parties report P2P success.
	connectedCount int32

	CreatedAt time.Time
	ExpiresAt time.Time
}

// IsExpired reports whether the session TTL has elapsed.
func (s *Session) IsExpired() bool {
	return time.Now().After(s.ExpiresAt)
}

// IsParty reports whether deviceID is the initiator or responder.
func (s *Session) IsParty(deviceID uuid.UUID) bool {
	return deviceID == s.InitiatorID || deviceID == s.ResponderID
}

// PeerOf returns the other party's device ID.
func (s *Session) PeerOf(deviceID uuid.UUID) (uuid.UUID, error) {
	switch deviceID {
	case s.InitiatorID:
		return s.ResponderID, nil
	case s.ResponderID:
		return s.InitiatorID, nil
	default:
		return uuid.Nil, ErrWrongDevice
	}
}

// SetOffer stores the SDP offer and transitions to StateOffered.
// Only the initiator may call this; the session must be in StatePending.
func (s *Session) SetOffer(sdp string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.IsExpired() {
		return ErrSessionExpired
	}
	if s.State != StatePending {
		return ErrInvalidTransition
	}
	s.SDPOffer = sdp
	s.State = StateOffered
	return nil
}

// SetAnswer stores the SDP answer and transitions to StateAnswered.
// Only the responder may call this; the session must be in StateOffered.
func (s *Session) SetAnswer(sdp string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.IsExpired() {
		return ErrSessionExpired
	}
	if s.State != StateOffered {
		return ErrInvalidTransition
	}
	s.SDPAnswer = sdp
	s.State = StateAnswered
	return nil
}

// AddICECandidate appends a candidate from deviceID.
// Valid in StateOffered, StateAnswered, or StateActive.
func (s *Session) AddICECandidate(deviceID, candidate, sdpMid string, sdpMLineIndex int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.IsExpired() {
		return ErrSessionExpired
	}
	if s.State == StatePending || s.State == StateFailed {
		return ErrInvalidTransition
	}
	s.Candidates = append(s.Candidates, ICECandidateRecord{
		DeviceID:      deviceID,
		Candidate:     candidate,
		SDPMid:        sdpMid,
		SDPMLineIndex: sdpMLineIndex,
		AddedAt:       time.Now(),
	})
	return nil
}

// MarkConnected is called by a party when its P2P link is established.
// When both parties call it the session transitions to StateActive.
func (s *Session) MarkConnected() (becameActive bool) {
	n := atomic.AddInt32(&s.connectedCount, 1)
	if n == 2 {
		s.mu.Lock()
		if s.State == StateAnswered {
			s.State = StateActive
			becameActive = true
		}
		s.mu.Unlock()
	}
	return becameActive
}

// MarkFailed transitions the session to StateFailed.
func (s *Session) MarkFailed() {
	s.mu.Lock()
	s.State = StateFailed
	s.mu.Unlock()
}

// Snapshot returns a point-in-time copy safe for serialisation.
func (s *Session) Snapshot() Session {
	s.mu.RLock()
	defer s.mu.RUnlock()
	snap := *s
	snap.Candidates = make([]ICECandidateRecord, len(s.Candidates))
	copy(snap.Candidates, s.Candidates)
	return snap
}

// ── Store ─────────────────────────────────────────────────────────────────────

// Store is a thread-safe, in-memory registry of active signaling sessions.
//
// Memory: each session is ~1 KB + ICE candidates (typically < 20 × ~200 B).
// A busy server with 1 000 concurrent negotiations uses < 25 MB.
//
// Phase 7: replace with a Redis-backed store for horizontal scaling.
type Store struct {
	sessions sync.Map // id (string) → *Session
}

// NewStore allocates a Store.
func NewStore() *Store { return &Store{} }

// Create registers a new signaling session between initiator and responder.
// The session expires after ttl; use 2 minutes for normal negotiation.
func (s *Store) Create(userID, initiatorID, responderID uuid.UUID, ttl time.Duration) *Session {
	sess := &Session{
		ID:          uuid.NewString(),
		UserID:      userID,
		InitiatorID: initiatorID,
		ResponderID: responderID,
		State:       StatePending,
		Candidates:  nil,
		CreatedAt:   time.Now(),
		ExpiresAt:   time.Now().Add(ttl),
	}
	s.sessions.Store(sess.ID, sess)
	return sess
}

// Get retrieves a session by ID.
// Returns (nil, ErrSessionNotFound) if the ID is unknown.
// Returns (nil, ErrSessionExpired) if the session exists but has timed out.
func (s *Store) Get(id string) (*Session, error) {
	v, ok := s.sessions.Load(id)
	if !ok {
		return nil, ErrSessionNotFound
	}
	sess := v.(*Session)
	if sess.IsExpired() {
		s.sessions.Delete(id) // lazy eviction
		return nil, ErrSessionExpired
	}
	return sess, nil
}

// Delete removes a session immediately (e.g. after both parties connect).
func (s *Store) Delete(id string) {
	s.sessions.Delete(id)
}

// Cleanup removes all expired sessions and returns the number evicted.
// Safe to call periodically from a background goroutine.
func (s *Store) Cleanup() int {
	var n int
	s.sessions.Range(func(k, v any) bool {
		if v.(*Session).IsExpired() {
			s.sessions.Delete(k)
			n++
		}
		return true
	})
	return n
}

// Len returns the number of live sessions.
func (s *Store) Len() int {
	var n int
	s.sessions.Range(func(_, _ any) bool { n++; return true })
	return n
}
