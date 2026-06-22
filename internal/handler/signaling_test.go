package handler_test

import (
	"context"
	"errors"
	"net/http"
	"testing"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/handler"
	"github.com/syncbridge/api/internal/service"
)

// ── stub signaling service ────────────────────────────────────────────────────

type stubSignalingSvc struct {
	rtcCfg         *dto.RTCConfigResponse
	createOfferResp *dto.SessionResponse
	createOfferErr  error
	answerResp     *dto.SessionResponse
	answerErr      error
	iceErr         error
	connectedResp  *dto.SessionResponse
	connectedErr   error
	sessionResp    *dto.SessionResponse
	sessionErr     error
	advertiseErr   error
	peersResp      *dto.LocalPeersResponse
	peersErr       error
	removeErr      error
}

func (s *stubSignalingSvc) GetRTCConfig(_ uuid.UUID) *dto.RTCConfigResponse { return s.rtcCfg }
func (s *stubSignalingSvc) CreateOffer(_ context.Context, _, _, _ uuid.UUID, _ string) (*dto.SessionResponse, error) {
	return s.createOfferResp, s.createOfferErr
}
func (s *stubSignalingSvc) SubmitAnswer(_ context.Context, _ string, _ uuid.UUID, _ string) (*dto.SessionResponse, error) {
	return s.answerResp, s.answerErr
}
func (s *stubSignalingSvc) AddICECandidate(_ context.Context, _ string, _ uuid.UUID, _ dto.ICECandidateInput) error {
	return s.iceErr
}
func (s *stubSignalingSvc) MarkConnected(_ context.Context, _ string, _ uuid.UUID) (*dto.SessionResponse, error) {
	return s.connectedResp, s.connectedErr
}
func (s *stubSignalingSvc) GetSession(_ context.Context, _ string, _ uuid.UUID) (*dto.SessionResponse, error) {
	return s.sessionResp, s.sessionErr
}
func (s *stubSignalingSvc) AdvertiseLocalAddrs(_ context.Context, _, _ uuid.UUID, _ []string, _ int) error {
	return s.advertiseErr
}
func (s *stubSignalingSvc) GetLocalPeers(_ context.Context, _, _ uuid.UUID, _ []string) (*dto.LocalPeersResponse, error) {
	return s.peersResp, s.peersErr
}
func (s *stubSignalingSvc) RemoveLocalAddr(_ context.Context, _ uuid.UUID) error {
	return s.removeErr
}

// ── app helper ────────────────────────────────────────────────────────────────

func newSignalingApp(svc *stubSignalingSvc) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			code := fiber.StatusInternalServerError
			var e *fiber.Error
			if errors.As(err, &e) {
				code = e.Code
			}
			return c.Status(code).JSON(fiber.Map{"error": err.Error()})
		},
	})

	h := handler.NewSignalingHandler(svc)

	uid, did := uuid.New(), uuid.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("user_id", uid)
		c.Locals("device_id", did)
		return c.Next()
	})

	app.Get("/api/v1/rtc/config",                h.GetRTCConfig)
	app.Post("/api/v1/signal",                   h.CreateOffer)
	app.Get("/api/v1/signal/:id",                h.GetSession)
	app.Post("/api/v1/signal/:id/answer",        h.SubmitAnswer)
	app.Post("/api/v1/signal/:id/ice",           h.AddICECandidate)
	app.Post("/api/v1/signal/:id/connected",     h.MarkConnected)
	app.Post("/api/v1/local/advertise",          h.AdvertiseLocalAddrs)
	app.Get("/api/v1/local/peers",               h.GetLocalPeers)
	app.Delete("/api/v1/local/advertise",        h.RemoveLocalAddr)
	return app
}

// ── Tests: RTC config ─────────────────────────────────────────────────────────

func TestSignalingGetRTCConfig_OK(t *testing.T) {
	svc := &stubSignalingSvc{rtcCfg: &dto.RTCConfigResponse{
		ICEServers: []dto.ICEServer{{URLs: []string{"stun:stun.example.com:3478"}}},
	}}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodGet, "/api/v1/rtc/config", nil)
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
	var cfg dto.RTCConfigResponse
	parseBody(t, resp, &cfg)
	if len(cfg.ICEServers) == 0 {
		t.Error("expected ICE servers in response")
	}
}

// ── Tests: CreateOffer ────────────────────────────────────────────────────────

func TestSignalingCreateOffer_Created(t *testing.T) {
	sess := &dto.SessionResponse{ID: uuid.New().String(), State: "offered"}
	svc := &stubSignalingSvc{createOfferResp: sess}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/signal", map[string]string{
		"responder_device_id": uuid.New().String(),
		"sdp_offer":          "v=0\r\noffer",
	})
	if resp.StatusCode != http.StatusCreated {
		t.Errorf("expected 201, got %d", resp.StatusCode)
	}
	var got dto.SessionResponse
	parseBody(t, resp, &got)
	if got.State != "offered" {
		t.Errorf("expected state=offered, got %q", got.State)
	}
}

func TestSignalingCreateOffer_MissingFields(t *testing.T) {
	svc := &stubSignalingSvc{}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/signal", map[string]string{
		"sdp_offer": "v=0",
		// missing responder_device_id
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
}

func TestSignalingCreateOffer_BadResponderID(t *testing.T) {
	svc := &stubSignalingSvc{}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/signal", map[string]string{
		"responder_device_id": "not-a-uuid",
		"sdp_offer":          "v=0",
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
}

// ── Tests: GetSession ─────────────────────────────────────────────────────────

func TestSignalingGetSession_OK(t *testing.T) {
	sess := &dto.SessionResponse{ID: "sess-1", State: "offered"}
	svc := &stubSignalingSvc{sessionResp: sess}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodGet, "/api/v1/signal/sess-1", nil)
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
}

func TestSignalingGetSession_NotFound(t *testing.T) {
	svc := &stubSignalingSvc{sessionErr: service.ErrSignalingNotFound}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodGet, "/api/v1/signal/unknown", nil)
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("expected 404, got %d", resp.StatusCode)
	}
}

// ── Tests: SubmitAnswer ───────────────────────────────────────────────────────

func TestSignalingSubmitAnswer_OK(t *testing.T) {
	sess := &dto.SessionResponse{ID: "s1", State: "answered"}
	svc := &stubSignalingSvc{answerResp: sess}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/signal/s1/answer", map[string]string{
		"sdp_answer": "v=0\r\nanswer",
	})
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
}

func TestSignalingSubmitAnswer_Forbidden(t *testing.T) {
	svc := &stubSignalingSvc{answerErr: service.ErrSignalingUnauthorized}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/signal/s1/answer", map[string]string{
		"sdp_answer": "v=0",
	})
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("expected 403, got %d", resp.StatusCode)
	}
}

// ── Tests: AddICECandidate ────────────────────────────────────────────────────

func TestSignalingAddICE_NoContent(t *testing.T) {
	svc := &stubSignalingSvc{}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/signal/s1/ice", map[string]any{
		"candidate":       "candidate:1 1 udp ...",
		"sdp_mid":        "0",
		"sdp_mline_index": 0,
	})
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("expected 204, got %d", resp.StatusCode)
	}
}

func TestSignalingAddICE_MissingCandidate(t *testing.T) {
	svc := &stubSignalingSvc{}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/signal/s1/ice", map[string]string{
		"sdp_mid": "0",
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
}

// ── Tests: MarkConnected ──────────────────────────────────────────────────────

func TestSignalingMarkConnected_OK(t *testing.T) {
	sess := &dto.SessionResponse{ID: "s1", State: "answered"}
	svc := &stubSignalingSvc{connectedResp: sess}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/signal/s1/connected", nil)
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
}

// ── Tests: local peer discovery ───────────────────────────────────────────────

func TestSignalingAdvertise_NoContent(t *testing.T) {
	svc := &stubSignalingSvc{}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/local/advertise", map[string]any{
		"addrs": []string{"192.168.1.10"},
		"port":  4444,
	})
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("expected 204, got %d", resp.StatusCode)
	}
}

func TestSignalingAdvertise_MissingAddrs(t *testing.T) {
	svc := &stubSignalingSvc{}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/local/advertise", map[string]any{
		"port": 4444,
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
}

func TestSignalingGetLocalPeers_OK(t *testing.T) {
	svc := &stubSignalingSvc{peersResp: &dto.LocalPeersResponse{
		Peers: []dto.LocalPeerResponse{
			{DeviceID: uuid.New().String(), Addrs: []string{"192.168.1.20"}, Port: 4444},
		},
	}}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodGet, "/api/v1/local/peers?addrs=192.168.1.10", nil)
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
	var got dto.LocalPeersResponse
	parseBody(t, resp, &got)
	if len(got.Peers) != 1 {
		t.Errorf("expected 1 peer, got %d", len(got.Peers))
	}
}

func TestSignalingRemoveLocalAddr_NoContent(t *testing.T) {
	svc := &stubSignalingSvc{}
	app := newSignalingApp(svc)

	resp := doRequest(t, app, http.MethodDelete, "/api/v1/local/advertise", nil)
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("expected 204, got %d", resp.StatusCode)
	}
}
