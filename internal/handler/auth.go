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

// authService is the interface the handler requires from the auth service layer.
type authService interface {
	Unlock(ctx context.Context, in service.UnlockInput) (*service.AuthResult, error)
	Status(ctx context.Context, deviceID uuid.UUID) (*service.TrustStatus, error)
	Logout(ctx context.Context, refreshToken string, allDevices bool, deviceID uuid.UUID) error
}

// AuthHandler handles HTTP requests for auth endpoints.
type AuthHandler struct {
	svc authService
}

// NewAuthHandler constructs an AuthHandler.
func NewAuthHandler(svc authService) *AuthHandler {
	return &AuthHandler{svc: svc}
}

// Unlock handles POST /api/v1/auth/unlock.
//
// Validates the master PIN on the server and returns a 7-day device token.
func (h *AuthHandler) Unlock(c *fiber.Ctx) error {
	var req dto.UnlockRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}
	if err := validateUnlockRequest(req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, err.Error())
	}

	deviceID, err := uuid.Parse(req.DeviceID)
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "device_id must be a valid UUID")
	}

	ip := ipAddress(c)
	ua := c.Get("User-Agent")

	result, err := h.svc.Unlock(c.UserContext(), service.UnlockInput{
		PIN:        req.PIN,
		DeviceID:   deviceID,
		DeviceName: strings.TrimSpace(req.DeviceName),
		Platform:   req.Platform,
		IPAddress:  &ip,
		UserAgent:  strPtr(ua),
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidPIN):
			return fiber.NewError(fiber.StatusUnauthorized, "invalid pin")
		case errors.Is(err, service.ErrDeviceRevoked):
			return fiber.NewError(fiber.StatusUnauthorized, "device revoked")
		default:
			return err
		}
	}

	return c.Status(fiber.StatusOK).JSON(toAuthResponse(result))
}

// Status handles GET /api/v1/auth/status (requires auth middleware).
func (h *AuthHandler) Status(c *fiber.Ctx) error {
	deviceID, ok := DeviceIDFromCtx(c)
	if !ok {
		return fiber.NewError(fiber.StatusUnauthorized, "unauthorized")
	}

	st, err := h.svc.Status(c.UserContext(), deviceID)
	if err != nil {
		if errors.Is(err, service.ErrDeviceRevoked) {
			return fiber.NewError(fiber.StatusUnauthorized, "device revoked")
		}
		return err
	}

	return c.JSON(dto.AuthStatusResponse{
		DeviceID:     st.DeviceID.String(),
		TrustedUntil: st.TrustedUntil,
		NeedsPIN:     st.NeedsPIN,
	})
}

// Logout handles POST /api/v1/auth/logout (requires auth middleware).
func (h *AuthHandler) Logout(c *fiber.Ctx) error {
	deviceID, ok := DeviceIDFromCtx(c)
	if !ok {
		return fiber.NewError(fiber.StatusUnauthorized, "unauthorized")
	}

	var req dto.LogoutRequest
	_ = c.BodyParser(&req)

	refreshToken := extractRefreshToken(c)

	if err := h.svc.Logout(c.UserContext(), refreshToken, req.AllDevices, deviceID); err != nil {
		return err
	}

	return c.JSON(dto.MessageResponse{Message: "logged out"})
}

// ── helpers ───────────────────────────────────────────────────────────────────

func toAuthResponse(result *service.AuthResult) dto.AuthResponse {
	return dto.AuthResponse{
		AccessToken:      result.Tokens.AccessToken,
		RefreshToken:     result.Tokens.RefreshToken,
		AccessExpiresAt:  result.Tokens.AccessExpiresAt,
		RefreshExpiresAt: result.Tokens.RefreshExpiresAt,
		UserID:           result.UserID.String(),
		DeviceID:         result.DeviceID.String(),
		TrustedUntil:     result.TrustedUntil,
	}
}

func validateUnlockRequest(req dto.UnlockRequest) error {
	if req.PIN == "" {
		return errors.New("pin is required")
	}
	if req.DeviceID == "" {
		return errors.New("device_id is required")
	}
	if strings.TrimSpace(req.DeviceName) == "" {
		return errors.New("device_name is required")
	}
	switch req.Platform {
	case "macos", "android", "ios", "web":
	default:
		return errors.New("platform must be one of: macos, android, ios, web")
	}
	return nil
}

func ipAddress(c *fiber.Ctx) string {
	if ip := c.Get("X-Forwarded-For"); ip != "" {
		if idx := strings.Index(ip, ","); idx != -1 {
			return strings.TrimSpace(ip[:idx])
		}
		return ip
	}
	return c.IP()
}

func extractRefreshToken(c *fiber.Ctx) string {
	var body struct {
		RefreshToken string `json:"refresh_token"`
	}
	_ = c.BodyParser(&body)
	return body.RefreshToken
}

func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// ── context key helpers shared across handler package ────────────────────────

type contextKey string

const (
	ctxUserID   contextKey = "user_id"
	ctxDeviceID contextKey = "device_id"
)

// UserIDFromCtx extracts the authenticated user UUID from Fiber locals.
func UserIDFromCtx(c *fiber.Ctx) (uuid.UUID, bool) {
	v, ok := c.Locals(string(ctxUserID)).(uuid.UUID)
	return v, ok
}

// DeviceIDFromCtx extracts the authenticated device UUID from Fiber locals.
func DeviceIDFromCtx(c *fiber.Ctx) (uuid.UUID, bool) {
	v, ok := c.Locals(string(ctxDeviceID)).(uuid.UUID)
	return v, ok
}

// SetAuthLocals writes user/device IDs into Fiber locals.
func SetAuthLocals(c *fiber.Ctx, userID, deviceID uuid.UUID) {
	c.Locals(string(ctxUserID), userID)
	c.Locals(string(ctxDeviceID), deviceID)
}
