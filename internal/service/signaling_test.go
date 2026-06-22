package service

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/repository"
	"github.com/syncbridge/api/internal/signaling"
)

// ── In-memory stubs ───────────────────────────────────────────────────────────

// stubSignalingStore wraps the real signaling.Store (it's already in-memory).
type stubSignalingStore struct {
	*signaling.Store
}

func newStubSignalingStore() *stubSignalingStore {
	return &stubSignalingStore{Store: signaling.NewStore()}
}

// ──────────────────────────────────────────────────────────────────────────────

type stubLocalPeerStore struct {
	mu    sync.Mutex
	peers []*repository.LocalPeer
}

func (s *stubLocalPeerStore) Upsert(_ context.Context, lp *repository.LocalPeer) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, p := range s.peers {
		if p.DeviceID == lp.DeviceID {
			s.peers[i] = lp
			lp.UpdatedAt = time.Now()
			return nil
		}
	}
	lp.UpdatedAt = time.Now()
	s.peers = append(s.peers, lp)
	return nil
}

func (s *stubLocalPeerStore) FindByUserID(_ context.Context, userID uuid.UUID) ([]*repository.LocalPeer, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var out []*repository.LocalPeer
	now := time.Now()
	for _, p := range s.peers {
		if p.UserID == userID && p.ExpiresAt.After(now) {
			out = append(out, p)
		}
	}
	return out, nil
}

func (s *stubLocalPeerStore) DeleteByDeviceID(_ context.Context, deviceID uuid.UUID) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, p := range s.peers {
		if p.DeviceID == deviceID {
			s.peers = append(s.peers[:i], s.peers[i+1:]...)
			return nil
		}
	}
	return nil
}

// ──────────────────────────────────────────────────────────────────────────────

type stubSignalingHub struct {
	mu        sync.Mutex
	delivered []deliveredMsg
}

type deliveredMsg struct {
	deviceID uuid.UUID
	data     []byte
}

func (h *stubSignalingHub) Deliver(deviceID uuid.UUID, data []byte) bool {
	h.mu.Lock()
	h.delivered = append(h.delivered, deliveredMsg{deviceID, data})
	h.mu.Unlock()
	return true
}

// ── Test helpers ──────────────────────────────────────────────────────────────

func newTestSignalingService() (*SignalingService, *stubSignalingStore, *stubLocalPeerStore, *stubSignalingHub) {
	store := newStubSignalingStore()
	peers := &stubLocalPeerStore{}
	hub := &stubSignalingHub{}
	svc := NewSignalingService(store, peers, hub, TURNConfig{
		STUNURLs: []string{"stun:stun.example.com:3478"},
		TURNURLs: []string{"turn:turn.example.com:3478"},
		Secret:   "testsecret",
	})
	return svc, store, peers, hub
}

// ── Tests: RTC config ─────────────────────────────────────────────────────────

func TestGetRTCConfig_IncludesSTUNAndTURN(t *testing.T) {
	svc, _, _, _ := newTestSignalingService()

	cfg := svc.GetRTCConfig(uuid.New())
	if len(cfg.ICEServers) < 2 {
		t.Fatalf("expected at least 2 ICE servers (STUN + TURN), got %d", len(cfg.ICEServers))
	}

	var foundStun, foundTurn bool
	for _, srv := range cfg.ICEServers {
		if len(srv.URLs) > 0 {
			url := srv.URLs[0]
			if len(url) >= 4 && url[:4] == "stun" {
				foundStun = true
			}
			if len(url) >= 4 && url[:4] == "turn" {
				foundTurn = true
				if srv.Username == "" || srv.Credential == "" {
					t.Error("TURN server missing username/credential")
				}
			}
		}
	}
	if !foundStun {
		t.Error("expected STUN server in ICE config")
	}
	if !foundTurn {
		t.Error("expected TURN server in ICE config")
	}
}

func TestGetRTCConfig_FallbackWhenNoConfig(t *testing.T) {
	store := newStubSignalingStore()
	peers := &stubLocalPeerStore{}
	hub := &stubSignalingHub{}
	svc := NewSignalingService(store, peers, hub, TURNConfig{}) // no STUN/TURN configured

	cfg := svc.GetRTCConfig(uuid.New())
	if len(cfg.ICEServers) == 0 {
		t.Error("expected fallback Google STUN when no servers configured")
	}
}

// ── Tests: signaling flow ─────────────────────────────────────────────────────

func TestCreateOffer_Success(t *testing.T) {
	svc, _, _, hub := newTestSignalingService()

	userID := uuid.New()
	initiator := uuid.New()
	responder := uuid.New()

	sess, err := svc.CreateOffer(context.Background(), userID, initiator, responder, "v=0\r\n...")
	if err != nil {
		t.Fatalf("CreateOffer: %v", err)
	}
	if sess.State != string(signaling.StateOffered) {
		t.Errorf("expected state=offered, got %q", sess.State)
	}
	if sess.SDPOffer != "v=0\r\n..." {
		t.Errorf("sdp_offer mismatch: %q", sess.SDPOffer)
	}
	if sess.InitiatorID != initiator.String() {
		t.Errorf("initiator_id mismatch")
	}

	// Hub should have attempted delivery to responder.
	hub.mu.Lock()
	n := len(hub.delivered)
	hub.mu.Unlock()
	if n == 0 {
		t.Error("expected WS delivery to responder")
	}
}

func TestCreateOffer_SameDevice(t *testing.T) {
	svc, _, _, _ := newTestSignalingService()
	id := uuid.New()
	_, err := svc.CreateOffer(context.Background(), uuid.New(), id, id, "offer")
	if err == nil {
		t.Error("expected error when initiator == responder")
	}
}

func TestSubmitAnswer_Success(t *testing.T) {
	svc, _, _, _ := newTestSignalingService()

	userID := uuid.New()
	initiator := uuid.New()
	responder := uuid.New()

	sess, _ := svc.CreateOffer(context.Background(), userID, initiator, responder, "offer-sdp")

	answered, err := svc.SubmitAnswer(context.Background(), sess.ID, responder, "answer-sdp")
	if err != nil {
		t.Fatalf("SubmitAnswer: %v", err)
	}
	if answered.State != string(signaling.StateAnswered) {
		t.Errorf("expected state=answered, got %q", answered.State)
	}
	if answered.SDPAnswer != "answer-sdp" {
		t.Errorf("sdp_answer mismatch")
	}
}

func TestSubmitAnswer_WrongDevice(t *testing.T) {
	svc, _, _, _ := newTestSignalingService()
	userID := uuid.New()
	sess, _ := svc.CreateOffer(context.Background(), userID, uuid.New(), uuid.New(), "offer")

	_, err := svc.SubmitAnswer(context.Background(), sess.ID, uuid.New(), "answer")
	if !errors.Is(err, ErrSignalingUnauthorized) {
		t.Errorf("expected ErrSignalingUnauthorized, got %v", err)
	}
}

func TestSubmitAnswer_WrongState(t *testing.T) {
	svc, _, _, _ := newTestSignalingService()
	userID := uuid.New()
	responder := uuid.New()
	sess, _ := svc.CreateOffer(context.Background(), userID, uuid.New(), responder, "offer")

	// Answer it once.
	svc.SubmitAnswer(context.Background(), sess.ID, responder, "answer1")

	// Trying to answer again must fail.
	_, err := svc.SubmitAnswer(context.Background(), sess.ID, responder, "answer2")
	if !errors.Is(err, ErrSignalingBadTransition) {
		t.Errorf("expected ErrSignalingBadTransition on double-answer, got %v", err)
	}
}

func TestAddICECandidate_Success(t *testing.T) {
	svc, _, _, hub := newTestSignalingService()
	userID := uuid.New()
	initiator := uuid.New()
	responder := uuid.New()

	sess, _ := svc.CreateOffer(context.Background(), userID, initiator, responder, "offer")
	svc.SubmitAnswer(context.Background(), sess.ID, responder, "answer")

	hub.mu.Lock()
	hub.delivered = nil
	hub.mu.Unlock()

	err := svc.AddICECandidate(context.Background(), sess.ID, initiator, dto.ICECandidateInput{
		Candidate:     "candidate:1 1 udp 2122260223 192.168.1.5 54321 typ host",
		SDPMid:        "0",
		SDPMLineIndex: 0,
	})
	if err != nil {
		t.Fatalf("AddICECandidate: %v", err)
	}

	// Candidate should have been delivered to the responder.
	hub.mu.Lock()
	n := len(hub.delivered)
	hub.mu.Unlock()
	if n == 0 {
		t.Error("expected ICE candidate delivery to peer")
	}
}

func TestMarkConnected_BothPartiesActivate(t *testing.T) {
	svc, _, _, _ := newTestSignalingService()
	userID := uuid.New()
	initiator := uuid.New()
	responder := uuid.New()

	sess, _ := svc.CreateOffer(context.Background(), userID, initiator, responder, "offer")
	svc.SubmitAnswer(context.Background(), sess.ID, responder, "answer")

	s1, err := svc.MarkConnected(context.Background(), sess.ID, initiator)
	if err != nil {
		t.Fatalf("MarkConnected initiator: %v", err)
	}
	if s1.State == string(signaling.StateActive) {
		t.Error("should not be active with only 1 confirmation")
	}

	s2, err := svc.MarkConnected(context.Background(), sess.ID, responder)
	if err != nil {
		t.Fatalf("MarkConnected responder: %v", err)
	}
	if s2.State != string(signaling.StateActive) {
		t.Errorf("expected active after both confirm, got %q", s2.State)
	}
}

func TestGetSession_NotFound(t *testing.T) {
	svc, _, _, _ := newTestSignalingService()
	_, err := svc.GetSession(context.Background(), "nonexistent", uuid.New())
	if !errors.Is(err, ErrSignalingNotFound) {
		t.Errorf("expected ErrSignalingNotFound, got %v", err)
	}
}

func TestGetSession_WrongParty(t *testing.T) {
	svc, _, _, _ := newTestSignalingService()
	sess, _ := svc.CreateOffer(context.Background(), uuid.New(), uuid.New(), uuid.New(), "offer")

	_, err := svc.GetSession(context.Background(), sess.ID, uuid.New()) // third party
	if !errors.Is(err, ErrSignalingUnauthorized) {
		t.Errorf("expected ErrSignalingUnauthorized, got %v", err)
	}
}

// ── Tests: local peer discovery ───────────────────────────────────────────────

func TestAdvertise_PeersOnSameLAN(t *testing.T) {
	svc, _, _, hub := newTestSignalingService()

	userID := uuid.New()
	devA := uuid.New()
	devB := uuid.New()

	// Device A advertises.
	if err := svc.AdvertiseLocalAddrs(context.Background(), userID, devA, []string{"192.168.1.10"}, 4444); err != nil {
		t.Fatalf("advertise A: %v", err)
	}

	hub.mu.Lock()
	hub.delivered = nil
	hub.mu.Unlock()

	// Device B advertises — should trigger notifications to both.
	if err := svc.AdvertiseLocalAddrs(context.Background(), userID, devB, []string{"192.168.1.20"}, 4444); err != nil {
		t.Fatalf("advertise B: %v", err)
	}

	hub.mu.Lock()
	n := len(hub.delivered)
	hub.mu.Unlock()

	// Two notifications: devA about devB, and devB about devA.
	if n < 2 {
		t.Errorf("expected at least 2 signal.peer deliveries, got %d", n)
	}
}

func TestAdvertise_DifferentSubnets(t *testing.T) {
	svc, _, _, hub := newTestSignalingService()
	userID := uuid.New()
	devA := uuid.New()
	devB := uuid.New()

	svc.AdvertiseLocalAddrs(context.Background(), userID, devA, []string{"192.168.1.10"}, 0)

	hub.mu.Lock()
	hub.delivered = nil
	hub.mu.Unlock()

	// Device B is on a different /24.
	svc.AdvertiseLocalAddrs(context.Background(), userID, devB, []string{"10.0.2.5"}, 0)

	hub.mu.Lock()
	n := len(hub.delivered)
	hub.mu.Unlock()

	if n > 0 {
		t.Errorf("should not send signal.peer for devices on different subnets, got %d messages", n)
	}
}

func TestGetLocalPeers_FiltersBySameSubnet(t *testing.T) {
	svc, _, _, _ := newTestSignalingService()
	userID := uuid.New()
	devA := uuid.New()
	devB := uuid.New()
	devC := uuid.New()

	svc.AdvertiseLocalAddrs(context.Background(), userID, devA, []string{"192.168.1.10"}, 0)
	svc.AdvertiseLocalAddrs(context.Background(), userID, devB, []string{"192.168.1.20"}, 0) // same /24 as A
	svc.AdvertiseLocalAddrs(context.Background(), userID, devC, []string{"10.0.0.5"}, 0)     // different /24

	resp, err := svc.GetLocalPeers(context.Background(), userID, devA, []string{"192.168.1.10"})
	if err != nil {
		t.Fatalf("GetLocalPeers: %v", err)
	}
	if len(resp.Peers) != 1 {
		t.Errorf("expected 1 peer (devB), got %d", len(resp.Peers))
	}
	if resp.Peers[0].DeviceID != devB.String() {
		t.Errorf("expected devB, got %q", resp.Peers[0].DeviceID)
	}
}

func TestRemoveLocalAddr(t *testing.T) {
	svc, _, peerStore, _ := newTestSignalingService()
	userID := uuid.New()
	devA := uuid.New()

	svc.AdvertiseLocalAddrs(context.Background(), userID, devA, []string{"192.168.1.10"}, 0)

	if err := svc.RemoveLocalAddr(context.Background(), devA); err != nil {
		t.Fatalf("RemoveLocalAddr: %v", err)
	}

	peerStore.mu.Lock()
	n := len(peerStore.peers)
	peerStore.mu.Unlock()
	if n != 0 {
		t.Errorf("expected 0 peers after removal, got %d", n)
	}
}

// ── Tests: session cleanup ────────────────────────────────────────────────────

func TestCleanupSessions_RemovesExpired(t *testing.T) {
	store := newStubSignalingStore()
	peers := &stubLocalPeerStore{}
	hub := &stubSignalingHub{}
	svc := NewSignalingService(store, peers, hub, TURNConfig{})
	svc.sessionTTL = time.Millisecond // very short TTL for test

	svc.CreateOffer(context.Background(), uuid.New(), uuid.New(), uuid.New(), "offer")

	time.Sleep(5 * time.Millisecond) // let it expire

	evicted := svc.CleanupSessions()
	if evicted == 0 {
		t.Error("expected at least 1 evicted session")
	}
}
