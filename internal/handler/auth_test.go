package handler_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/auth"
	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/handler"
	"github.com/syncbridge/api/internal/service"
)

type stubAuthService struct {
	unlockResult *service.AuthResult
	unlockErr    error
	statusResult *service.TrustStatus
	statusErr    error
	logoutErr    error
}

func (s *stubAuthService) Unlock(_ context.Context, _ service.UnlockInput) (*service.AuthResult, error) {
	return s.unlockResult, s.unlockErr
}

func (s *stubAuthService) Status(_ context.Context, _ uuid.UUID) (*service.TrustStatus, error) {
	return s.statusResult, s.statusErr
}

func (s *stubAuthService) Logout(_ context.Context, _ string, _ bool, _ uuid.UUID) error {
	return s.logoutErr
}

func newTestApp(svc *stubAuthService) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			code := fiber.StatusInternalServerError
			var e *fiber.Error
			if errors.As(err, &e) {
				code = e.Code
			}
			return c.Status(code).JSON(dto.ErrorResponse{Error: err.Error()})
		},
	})
	h := handler.NewAuthHandler(svc)
	app.Post("/api/v1/auth/unlock", h.Unlock)
	app.Get("/api/v1/auth/status", func(c *fiber.Ctx) error {
		handler.SetAuthLocals(c, uuid.New(), uuid.New())
		return h.Status(c)
	})
	app.Post("/api/v1/auth/logout", func(c *fiber.Ctx) error {
		handler.SetAuthLocals(c, uuid.New(), uuid.New())
		return h.Logout(c)
	})
	return app
}

func jsonBody(t *testing.T, v any) *bytes.Buffer {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	return bytes.NewBuffer(b)
}

func TestUnlockHandler_Success(t *testing.T) {
	userID := uuid.New()
	deviceID := uuid.New()
	trustedUntil := time.Now().Add(7 * 24 * time.Hour)
	app := newTestApp(&stubAuthService{
		unlockResult: &service.AuthResult{
			UserID:   userID,
			DeviceID: deviceID,
			Tokens: &auth.TokenPair{
				AccessToken:      "access",
				RefreshToken:     "refresh",
				AccessExpiresAt:  trustedUntil,
				RefreshExpiresAt: trustedUntil,
			},
			TrustedUntil: trustedUntil,
		},
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/unlock",
		jsonBody(t, dto.UnlockRequest{
			PIN: "070901", DeviceID: deviceID.String(),
			DeviceName: "Mac", Platform: "macos",
		}))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("Test: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}

	var body dto.AuthResponse
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body.AccessToken != "access" {
		t.Error("expected access token in response")
	}
}

func TestUnlockHandler_InvalidPIN(t *testing.T) {
	app := newTestApp(&stubAuthService{unlockErr: service.ErrInvalidPIN})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/unlock",
		jsonBody(t, dto.UnlockRequest{
			PIN: "wrong", DeviceID: uuid.New().String(),
			DeviceName: "Mac", Platform: "macos",
		}))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("Test: %v", err)
	}
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", resp.StatusCode)
	}
}

func TestUnlockHandler_MissingFields(t *testing.T) {
	app := newTestApp(&stubAuthService{})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/unlock",
		bytes.NewBufferString(`{"pin":"070901"}`))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("Test: %v", err)
	}
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", resp.StatusCode)
	}
}

func TestStatusHandler_Success(t *testing.T) {
	deviceID := uuid.New()
	until := time.Now().Add(24 * time.Hour)
	app := newTestApp(&stubAuthService{
		statusResult: &service.TrustStatus{
			DeviceID: deviceID, TrustedUntil: &until, NeedsPIN: false,
		},
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/auth/status", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("Test: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}

	var body dto.AuthStatusResponse
	bodyBytes, _ := io.ReadAll(resp.Body)
	if err := json.Unmarshal(bodyBytes, &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body.NeedsPIN {
		t.Error("expected needs_pin=false")
	}
}

func TestLogoutHandler_Success(t *testing.T) {
	app := newTestApp(&stubAuthService{})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/logout", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("Test: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}
}
