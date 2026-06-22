package handler

import (
	"context"
	"errors"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/service"
)

// ── signalingService interface ────────────────────────────────────────────────

// signalingService is the subset of service.SignalingService the handler uses.
type signalingService interface {
	GetRTCConfig(deviceID uuid.UUID) *dto.RTCConfigResponse
	CreateOffer(ctx context.Context, userID, initiatorID, responderID uuid.UUID, sdpOffer string) (*dto.SessionResponse, error)
	SubmitAnswer(ctx context.Context, sessionID string, responderID uuid.UUID, sdpAnswer string) (*dto.SessionResponse, error)
	AddICECandidate(ctx context.Context, sessionID string, deviceID uuid.UUID, in dto.ICECandidateInput) error
	MarkConnected(ctx context.Context, sessionID string, deviceID uuid.UUID) (*dto.SessionResponse, error)
	GetSession(ctx context.Context, sessionID string, deviceID uuid.UUID) (*dto.SessionResponse, error)
	AdvertiseLocalAddrs(ctx context.Context, userID, deviceID uuid.UUID, addrs []string, port int) error
	GetLocalPeers(ctx context.Context, userID, deviceID uuid.UUID, ownAddrs []string) (*dto.LocalPeersResponse, error)
	RemoveLocalAddr(ctx context.Context, deviceID uuid.UUID) error
}

// ── SignalingHandler ──────────────────────────────────────────────────────────

// SignalingHandler exposes WebRTC signaling and local-peer discovery endpoints.
type SignalingHandler struct {
	svc signalingService
}

// NewSignalingHandler creates a SignalingHandler.
func NewSignalingHandler(svc signalingService) *SignalingHandler {
	return &SignalingHandler{svc: svc}
}

// ── GET /api/v1/rtc/config ────────────────────────────────────────────────────

// GetRTCConfig returns STUN/TURN server URLs and time-limited TURN credentials.
// Clients pass this directly to RTCPeerConnection({ iceServers }).
func (h *SignalingHandler) GetRTCConfig(c *fiber.Ctx) error {
	_, deviceID, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}
	return c.JSON(h.svc.GetRTCConfig(deviceID))
}

// ── POST /api/v1/signal ───────────────────────────────────────────────────────

// CreateOffer creates a signaling session and submits the SDP offer from the
// initiating device.  Returns the new session (state: "offered").
//
// If the responder is online, it receives a "signal.offer" WebSocket push
// immediately.  Offline responders poll GET /api/v1/signal/:id.
func (h *SignalingHandler) CreateOffer(c *fiber.Ctx) error {
	userID, deviceID, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	var req dto.CreateOfferRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}
	if req.ResponderDeviceID == "" || req.SDPOffer == "" {
		return fiber.NewError(fiber.StatusBadRequest, "responder_device_id and sdp_offer are required")
	}

	responderID, err := uuid.Parse(req.ResponderDeviceID)
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid responder_device_id")
	}

	sess, err := h.svc.CreateOffer(c.Context(), userID, deviceID, responderID, req.SDPOffer)
	if err != nil {
		return mapSignalingHTTPError(err)
	}
	return c.Status(fiber.StatusCreated).JSON(sess)
}

// ── GET /api/v1/signal/:id ────────────────────────────────────────────────────

// GetSession returns the current state of a signaling session.
// Used as a REST polling fallback by clients without persistent WebSocket.
func (h *SignalingHandler) GetSession(c *fiber.Ctx) error {
	_, deviceID, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	sess, err := h.svc.GetSession(c.Context(), c.Params("id"), deviceID)
	if err != nil {
		return mapSignalingHTTPError(err)
	}
	return c.JSON(sess)
}

// ── POST /api/v1/signal/:id/answer ───────────────────────────────────────────

// SubmitAnswer records the SDP answer from the responder.
// Delivers the answer to the initiator via WebSocket if online.
func (h *SignalingHandler) SubmitAnswer(c *fiber.Ctx) error {
	_, deviceID, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	var req dto.SubmitAnswerRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}
	if req.SDPAnswer == "" {
		return fiber.NewError(fiber.StatusBadRequest, "sdp_answer is required")
	}

	sess, err := h.svc.SubmitAnswer(c.Context(), c.Params("id"), deviceID, req.SDPAnswer)
	if err != nil {
		return mapSignalingHTTPError(err)
	}
	return c.JSON(sess)
}

// ── POST /api/v1/signal/:id/ice ───────────────────────────────────────────────

// AddICECandidate forwards a trickle-ICE candidate to the peer.
func (h *SignalingHandler) AddICECandidate(c *fiber.Ctx) error {
	_, deviceID, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	var req dto.ICECandidateRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}
	if req.Candidate == "" {
		return fiber.NewError(fiber.StatusBadRequest, "candidate is required")
	}

	if err := h.svc.AddICECandidate(c.Context(), c.Params("id"), deviceID, req.ICECandidateInput); err != nil {
		return mapSignalingHTTPError(err)
	}
	return c.SendStatus(fiber.StatusNoContent)
}

// ── POST /api/v1/signal/:id/connected ────────────────────────────────────────

// MarkConnected is called by a device once its WebRTC DataChannel is open.
// When both parties call it the session moves to state "active".
func (h *SignalingHandler) MarkConnected(c *fiber.Ctx) error {
	_, deviceID, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	sess, err := h.svc.MarkConnected(c.Context(), c.Params("id"), deviceID)
	if err != nil {
		return mapSignalingHTTPError(err)
	}
	return c.JSON(sess)
}

// ── POST /api/v1/local/advertise ─────────────────────────────────────────────

// AdvertiseLocalAddrs registers or refreshes the device's LAN IP addresses.
// The server uses these to detect same-subnet peers and send signal.peer hints.
func (h *SignalingHandler) AdvertiseLocalAddrs(c *fiber.Ctx) error {
	userID, deviceID, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	var req dto.AdvertiseRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}
	if len(req.Addrs) == 0 {
		return fiber.NewError(fiber.StatusBadRequest, "addrs must not be empty")
	}

	if err := h.svc.AdvertiseLocalAddrs(c.Context(), userID, deviceID, req.Addrs, req.Port); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "advertise failed")
	}
	return c.SendStatus(fiber.StatusNoContent)
}

// ── GET /api/v1/local/peers ───────────────────────────────────────────────────

// GetLocalPeers returns known peers on the same LAN segment.
// Query param: addrs (comma-separated own IP addresses, e.g. ?addrs=192.168.1.5)
func (h *SignalingHandler) GetLocalPeers(c *fiber.Ctx) error {
	userID, deviceID, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	var ownAddrs []string
	if a := c.Query("addrs"); a != "" {
		for _, part := range strings.Split(a, ",") {
			if trimmed := strings.TrimSpace(part); trimmed != "" {
				ownAddrs = append(ownAddrs, trimmed)
			}
		}
	}

	resp, err := h.svc.GetLocalPeers(c.Context(), userID, deviceID, ownAddrs)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "peer lookup failed")
	}
	return c.JSON(resp)
}

// ── DELETE /api/v1/local/advertise ───────────────────────────────────────────

// RemoveLocalAddr removes the device's LAN advertisement on clean disconnect.
func (h *SignalingHandler) RemoveLocalAddr(c *fiber.Ctx) error {
	_, deviceID, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}
	if err := h.svc.RemoveLocalAddr(c.Context(), deviceID); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "remove failed")
	}
	return c.SendStatus(fiber.StatusNoContent)
}

// ── error mapping ─────────────────────────────────────────────────────────────

func mapSignalingHTTPError(err error) *fiber.Error {
	switch {
	case errors.Is(err, service.ErrSignalingNotFound):
		return fiber.NewError(fiber.StatusNotFound, err.Error())
	case errors.Is(err, service.ErrSignalingUnauthorized):
		return fiber.NewError(fiber.StatusForbidden, err.Error())
	case errors.Is(err, service.ErrSignalingBadTransition):
		return fiber.NewError(fiber.StatusConflict, err.Error())
	default:
		return fiber.NewError(fiber.StatusInternalServerError, "internal error")
	}
}
