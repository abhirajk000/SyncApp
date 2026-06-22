package service

import (
	"context"
	"errors"
	"fmt"
	"net"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/repository"
	"github.com/syncbridge/api/internal/signaling"
	"github.com/syncbridge/api/internal/ws"
)

// ── Sentinel errors ───────────────────────────────────────────────────────────

var (
	ErrSignalingNotFound    = errors.New("signaling session not found or expired")
	ErrSignalingUnauthorized = errors.New("device is not a party to this session")
	ErrSignalingBadTransition = errors.New("invalid state transition for current session state")
)

// ── Store / Hub interfaces ────────────────────────────────────────────────────

// signalingStore is satisfied by *signaling.Store.
type signalingStore interface {
	Create(userID, initiatorID, responderID uuid.UUID, ttl time.Duration) *signaling.Session
	Get(id string) (*signaling.Session, error)
	Delete(id string)
	Cleanup() int
}

// localPeerStore is satisfied by *repository.LocalPeerRepository.
type localPeerStore interface {
	Upsert(ctx context.Context, lp *repository.LocalPeer) error
	FindByUserID(ctx context.Context, userID uuid.UUID) ([]*repository.LocalPeer, error)
	DeleteByDeviceID(ctx context.Context, deviceID uuid.UUID) error
}

// signalingHub is the subset of ws.Hub used by SignalingService.
type signalingHub interface {
	Deliver(deviceID uuid.UUID, data []byte) bool
}

// ── SignalingService ──────────────────────────────────────────────────────────

// SignalingService orchestrates WebRTC signaling and local-peer discovery.
//
// P2P decision rule (enforced client-side, hinted by server):
//   When two devices are on the same /24 subnet, the server pushes a
//   signal.peer notification so clients know they can attempt a direct TCP/UDP
//   connection instead of routing through the WebSocket relay.
//
// TURN credentials use RFC 8489 time-limited HMAC-SHA1 (compatible with coturn).
type SignalingService struct {
	sessions  signalingStore
	peers     localPeerStore
	hub       signalingHub
	turnCfg   TURNConfig
	sessionTTL time.Duration
	peerTTL    time.Duration
}

// TURNConfig holds STUN/TURN server parameters.
type TURNConfig struct {
	STUNURLs []string // e.g. ["stun:stun.syncbridge.io:3478"]
	TURNURLs []string // e.g. ["turn:turn.syncbridge.io:3478"]
	Secret   string   // HMAC-SHA1 shared secret (from config.TURNSecret)
}

// NewSignalingService wires the service.
func NewSignalingService(
	sessions signalingStore,
	peers localPeerStore,
	hub signalingHub,
	turnCfg TURNConfig,
) *SignalingService {
	return &SignalingService{
		sessions:   sessions,
		peers:      peers,
		hub:        hub,
		turnCfg:    turnCfg,
		sessionTTL: 2 * time.Minute,
		peerTTL:    10 * time.Minute,
	}
}

// ── RTC Configuration ─────────────────────────────────────────────────────────

// GetRTCConfig returns ICE server configuration including time-limited TURN
// credentials for the requesting device.  The client plugs this directly into
// RTCPeerConnection({iceServers}).
func (s *SignalingService) GetRTCConfig(deviceID uuid.UUID) *dto.RTCConfigResponse {
	resp := &dto.RTCConfigResponse{}

	for _, u := range s.turnCfg.STUNURLs {
		resp.ICEServers = append(resp.ICEServers, dto.ICEServer{URLs: []string{u}})
	}

	if s.turnCfg.Secret != "" {
		username, credential := generateTURNCredentials(s.turnCfg.Secret, deviceID.String())
		for _, u := range s.turnCfg.TURNURLs {
			resp.ICEServers = append(resp.ICEServers, dto.ICEServer{
				URLs:       []string{u},
				Username:   username,
				Credential: credential,
			})
		}
	}

	// Fallback: at minimum include Google's public STUN server so clients
	// can get external IP candidates even if the operator hasn't configured TURN.
	if len(resp.ICEServers) == 0 {
		resp.ICEServers = []dto.ICEServer{
			{URLs: []string{"stun:stun.l.google.com:19302"}},
		}
	}
	return resp
}

// ── Session: create + offer ───────────────────────────────────────────────────

// CreateOffer creates a signaling session and records the SDP offer from the
// initiating device.  The offer is delivered to the responder via WebSocket if
// it is currently online; otherwise it waits for a REST poll.
func (s *SignalingService) CreateOffer(
	ctx context.Context,
	userID, initiatorID, responderID uuid.UUID,
	sdpOffer string,
) (*dto.SessionResponse, error) {
	if initiatorID == responderID {
		return nil, fmt.Errorf("initiator and responder must be different devices")
	}

	sess := s.sessions.Create(userID, initiatorID, responderID, s.sessionTTL)
	if err := sess.SetOffer(sdpOffer); err != nil {
		s.sessions.Delete(sess.ID)
		return nil, err
	}

	// Push offer to responder if online.
	s.deliverOffer(sess)

	return toSessionResponse(sess.Snapshot()), nil
}

// ── Session: answer ───────────────────────────────────────────────────────────

// SubmitAnswer records the SDP answer from the responder and delivers it to
// the initiator.
func (s *SignalingService) SubmitAnswer(
	ctx context.Context,
	sessionID string,
	responderID uuid.UUID,
	sdpAnswer string,
) (*dto.SessionResponse, error) {
	sess, err := s.sessions.Get(sessionID)
	if err != nil {
		return nil, mapSignalingError(err)
	}
	if sess.ResponderID != responderID {
		return nil, ErrSignalingUnauthorized
	}

	if err := sess.SetAnswer(sdpAnswer); err != nil {
		return nil, mapSignalingError(err)
	}

	// Deliver answer to the initiator.
	s.deliverAnswer(sess)

	return toSessionResponse(sess.Snapshot()), nil
}

// ── Session: ICE candidates ───────────────────────────────────────────────────

// AddICECandidate appends a candidate from deviceID and forwards it to the
// peer.  Clients trickle-ICE as candidates are gathered.
func (s *SignalingService) AddICECandidate(
	ctx context.Context,
	sessionID string,
	deviceID uuid.UUID,
	in dto.ICECandidateInput,
) error {
	sess, err := s.sessions.Get(sessionID)
	if err != nil {
		return mapSignalingError(err)
	}
	if !sess.IsParty(deviceID) {
		return ErrSignalingUnauthorized
	}

	if err := sess.AddICECandidate(deviceID.String(), in.Candidate, in.SDPMid, in.SDPMLineIndex); err != nil {
		return mapSignalingError(err)
	}

	// Forward candidate to the other party.
	peerID, _ := sess.PeerOf(deviceID)
	data, err := ws.EncodeSignalICE(sess.ID, deviceID.String(), in.Candidate, in.SDPMid, in.SDPMLineIndex)
	if err != nil {
		log.Error().Err(err).Msg("encode signal.ice")
		return nil // best-effort
	}
	s.hub.Deliver(peerID, data)
	return nil
}

// ── Session: connected ────────────────────────────────────────────────────────

// MarkConnected is called by a party when its P2P link is confirmed live.
// When both parties have reported, the session transitions to "active" and is
// eligible for cleanup.
func (s *SignalingService) MarkConnected(
	ctx context.Context,
	sessionID string,
	deviceID uuid.UUID,
) (*dto.SessionResponse, error) {
	sess, err := s.sessions.Get(sessionID)
	if err != nil {
		return nil, mapSignalingError(err)
	}
	if !sess.IsParty(deviceID) {
		return nil, ErrSignalingUnauthorized
	}

	if becameActive := sess.MarkConnected(); becameActive {
		log.Info().Str("session_id", sess.ID).Msg("webrtc p2p session active")
		// Optionally delete the session now — both parties no longer need the server.
		// Kept for a short grace period for REST poll recovery.
	}
	return toSessionResponse(sess.Snapshot()), nil
}

// ── Session: get ──────────────────────────────────────────────────────────────

// GetSession returns the current state of a session.
// Used by clients as a REST polling fallback when WebSocket is unavailable.
func (s *SignalingService) GetSession(
	ctx context.Context,
	sessionID string,
	deviceID uuid.UUID,
) (*dto.SessionResponse, error) {
	sess, err := s.sessions.Get(sessionID)
	if err != nil {
		return nil, mapSignalingError(err)
	}
	if !sess.IsParty(deviceID) {
		return nil, ErrSignalingUnauthorized
	}
	return toSessionResponse(sess.Snapshot()), nil
}

// ── Local peer discovery ──────────────────────────────────────────────────────

// AdvertiseLocalAddrs registers or refreshes the device's LAN addresses.
// After storing, the service scans for same-subnet peers for the same user and
// pushes a signal.peer notification to both devices so they can attempt a
// direct (non-server-relayed) connection.
func (s *SignalingService) AdvertiseLocalAddrs(
	ctx context.Context,
	userID, deviceID uuid.UUID,
	addrs []string,
	port int,
) error {
	lp := &repository.LocalPeer{
		ID:        uuid.New(),
		UserID:    userID,
		DeviceID:  deviceID,
		Addrs:     addrs,
		Port:      port,
		ExpiresAt: time.Now().Add(s.peerTTL),
	}
	if err := s.peers.Upsert(ctx, lp); err != nil {
		return fmt.Errorf("upsert local peer: %w", err)
	}

	// Find and notify same-network peers.
	s.notifySameNetworkPeers(ctx, userID, deviceID, addrs)
	return nil
}

// GetLocalPeers returns peers of the same user that are on the same LAN segment
// as deviceID.  The caller provides the device's own addresses so the service
// can filter by subnet overlap.
func (s *SignalingService) GetLocalPeers(
	ctx context.Context,
	userID, deviceID uuid.UUID,
	ownAddrs []string,
) (*dto.LocalPeersResponse, error) {
	all, err := s.peers.FindByUserID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("fetch peers: %w", err)
	}

	var out []dto.LocalPeerResponse
	for _, p := range all {
		if p.DeviceID == deviceID {
			continue // skip self
		}
		if sameNetwork(ownAddrs, p.Addrs) {
			out = append(out, dto.LocalPeerResponse{
				DeviceID:  p.DeviceID.String(),
				Addrs:     p.Addrs,
				Port:      p.Port,
				UpdatedAt: p.UpdatedAt,
			})
		}
	}
	return &dto.LocalPeersResponse{Peers: out}, nil
}

// RemoveLocalAddr removes the advertisement when a device cleanly disconnects.
func (s *SignalingService) RemoveLocalAddr(ctx context.Context, deviceID uuid.UUID) error {
	return s.peers.DeleteByDeviceID(ctx, deviceID)
}

// ── Cleanup (called periodically by server) ───────────────────────────────────

// CleanupSessions removes expired in-memory signaling sessions.
// Returns the number of evicted sessions.
func (s *SignalingService) CleanupSessions() int {
	n := s.sessions.Cleanup()
	if n > 0 {
		log.Debug().Int("evicted", n).Msg("signaling session cleanup")
	}
	return n
}

// ── private helpers ───────────────────────────────────────────────────────────

func (s *SignalingService) deliverOffer(sess *signaling.Session) {
	data, err := ws.EncodeSignalOffer(sess.ID, sess.SDPOffer)
	if err != nil {
		log.Error().Err(err).Msg("encode signal.offer")
		return
	}
	if delivered := s.hub.Deliver(sess.ResponderID, data); !delivered {
		log.Debug().
			Str("session_id", sess.ID).
			Str("responder_id", sess.ResponderID.String()).
			Msg("responder offline; sdp offer stored for REST poll")
	}
}

func (s *SignalingService) deliverAnswer(sess *signaling.Session) {
	snap := sess.Snapshot()
	data, err := ws.EncodeSignalAnswer(snap.ID, snap.SDPAnswer)
	if err != nil {
		log.Error().Err(err).Msg("encode signal.answer")
		return
	}
	if delivered := s.hub.Deliver(sess.InitiatorID, data); !delivered {
		log.Debug().
			Str("session_id", snap.ID).
			Str("initiator_id", sess.InitiatorID.String()).
			Msg("initiator offline; sdp answer stored for REST poll")
	}
}

// notifySameNetworkPeers finds devices on the same /24 and notifies them both
// that a peer is reachable at a local address.
func (s *SignalingService) notifySameNetworkPeers(
	ctx context.Context,
	userID, newDeviceID uuid.UUID,
	newAddrs []string,
) {
	all, err := s.peers.FindByUserID(ctx, userID)
	if err != nil {
		log.Warn().Err(err).Msg("notifySameNetworkPeers: fetch failed")
		return
	}

	for _, p := range all {
		if p.DeviceID == newDeviceID {
			continue
		}
		if !sameNetwork(newAddrs, p.Addrs) {
			continue
		}

		// Notify existing peer about the new device.
		if data, err := ws.EncodeSignalPeer(newDeviceID.String(), newAddrs, 0); err == nil {
			s.hub.Deliver(p.DeviceID, data)
		}
		// Notify new device about the existing peer.
		if data, err := ws.EncodeSignalPeer(p.DeviceID.String(), p.Addrs, p.Port); err == nil {
			s.hub.Deliver(newDeviceID, data)
		}
	}
}

// sameNetwork returns true if any address pair from addrs1 × addrs2 falls in
// the same /24 IPv4 subnet.  IPv6 uses /64.
func sameNetwork(addrs1, addrs2 []string) bool {
	for _, a1 := range addrs1 {
		ip1 := net.ParseIP(a1)
		if ip1 == nil {
			continue
		}
		for _, a2 := range addrs2 {
			ip2 := net.ParseIP(a2)
			if ip2 == nil {
				continue
			}
			if ip1.To4() != nil && ip2.To4() != nil {
				mask := net.CIDRMask(24, 32)
				if ip1.Mask(mask).Equal(ip2.Mask(mask)) {
					return true
				}
			} else {
				mask := net.CIDRMask(64, 128)
				if ip1.Mask(mask).Equal(ip2.Mask(mask)) {
					return true
				}
			}
		}
	}
	return false
}

// generateTURNCredentials produces RFC 8489 time-limited HMAC-SHA1 credentials
// compatible with coturn's --use-auth-secret mode.
//
//	username = "<expiry_unix>:<device_id>"
//	password = base64(HMAC-SHA1(secret, username))
func generateTURNCredentials(secret, deviceID string) (username, credential string) {
	return ws.GenerateTURNCredentials(secret, deviceID)
}

// ── DTO helpers ───────────────────────────────────────────────────────────────

func toSessionResponse(snap signaling.Session) *dto.SessionResponse {
	cands := make([]dto.ICECandidateResponse, len(snap.Candidates))
	for i, c := range snap.Candidates {
		cands[i] = dto.ICECandidateResponse{
			DeviceID:      c.DeviceID,
			Candidate:     c.Candidate,
			SDPMid:        c.SDPMid,
			SDPMLineIndex: c.SDPMLineIndex,
			AddedAt:       c.AddedAt,
		}
	}
	return &dto.SessionResponse{
		ID:            snap.ID,
		State:         string(snap.State),
		InitiatorID:   snap.InitiatorID.String(),
		ResponderID:   snap.ResponderID.String(),
		SDPOffer:      snap.SDPOffer,
		SDPAnswer:     snap.SDPAnswer,
		ICECandidates: cands,
		CreatedAt:     snap.CreatedAt,
		ExpiresAt:     snap.ExpiresAt,
	}
}

func mapSignalingError(err error) error {
	switch {
	case errors.Is(err, signaling.ErrSessionNotFound),
		errors.Is(err, signaling.ErrSessionExpired):
		return ErrSignalingNotFound
	case errors.Is(err, signaling.ErrWrongDevice):
		return ErrSignalingUnauthorized
	case errors.Is(err, signaling.ErrInvalidTransition):
		return ErrSignalingBadTransition
	default:
		return err
	}
}
