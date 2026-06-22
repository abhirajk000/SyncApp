package handler

import (
	"context"
	"encoding/base64"
	"errors"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/repository"
	"github.com/syncbridge/api/internal/service"
)

// deviceService is the interface the handler requires.
type deviceService interface {
	Register(ctx context.Context, userID uuid.UUID, in service.DeviceInput) (*repository.Device, error)
	List(ctx context.Context, userID uuid.UUID) ([]*repository.Device, error)
	Get(ctx context.Context, userID, deviceID uuid.UUID) (*repository.Device, error)
	Revoke(ctx context.Context, userID, deviceID uuid.UUID) error
	Trust(ctx context.Context, userID, deviceID uuid.UUID) error
	Rename(ctx context.Context, userID, deviceID uuid.UUID, name string) error
	InitiatePairing(ctx context.Context, initiatorDeviceID, userID uuid.UUID) (*service.PairInitiateResult, error)
	ConfirmPairing(ctx context.Context, in service.PairConfirmInput) (*service.AuthResult, error)
}

type devicePresence interface {
	IsDeviceOnline(deviceID uuid.UUID) bool
}

// DeviceHandler handles HTTP requests for device management endpoints.
type DeviceHandler struct {
	svc      deviceService
	presence devicePresence
}

// NewDeviceHandler constructs a DeviceHandler.
func NewDeviceHandler(svc deviceService, presence devicePresence) *DeviceHandler {
	return &DeviceHandler{svc: svc, presence: presence}
}

// List handles GET /api/v1/devices.
//
//	@Summary     List all devices for the authenticated user
//	@Tags        devices
//	@Security    BearerAuth
//	@Produce     json
//	@Param       trusted query bool false "Only trusted devices active recently"
//	@Success     200 {object} dto.DeviceListResponse
//	@Failure     401 {object} dto.ErrorResponse
//	@Router      /api/v1/devices [get]
func (h *DeviceHandler) List(c *fiber.Ctx) error {
	userID, ok := UserIDFromCtx(c)
	if !ok {
		return fiber.NewError(fiber.StatusUnauthorized, "unauthorized")
	}
	currentDeviceID, _ := DeviceIDFromCtx(c)
	trustedOnly := c.Query("trusted") == "1" || strings.EqualFold(c.Query("trusted"), "true")

	devices, err := h.svc.List(c.UserContext(), userID)
	if err != nil {
		return err
	}

	now := time.Now()
	resp := dto.DeviceListResponse{
		Devices: make([]dto.DeviceResponse, 0, len(devices)),
		Total:   0,
	}
	for _, d := range devices {
		if trustedOnly && !isTrustedActiveDevice(d, now) {
			continue
		}
		resp.Devices = append(resp.Devices, toDeviceResponse(d, currentDeviceID, h.presence))
	}
	resp.Total = len(resp.Devices)
	return c.JSON(resp)
}

// Get handles GET /api/v1/devices/:id.
//
//	@Summary     Get a single device
//	@Tags        devices
//	@Security    BearerAuth
//	@Produce     json
//	@Param       id  path string true "Device UUID"
//	@Success     200 {object} dto.DeviceResponse
//	@Failure     404 {object} dto.ErrorResponse
//	@Router      /api/v1/devices/{id} [get]
func (h *DeviceHandler) Get(c *fiber.Ctx) error {
	userID, ok := UserIDFromCtx(c)
	if !ok {
		return fiber.NewError(fiber.StatusUnauthorized, "unauthorized")
	}
	currentDeviceID, _ := DeviceIDFromCtx(c)

	deviceID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid device id")
	}

	device, err := h.svc.Get(c.UserContext(), userID, deviceID)
	if err != nil {
		switch {
		case errors.Is(err, repository.ErrNotFound):
			return fiber.NewError(fiber.StatusNotFound, "device not found")
		case errors.Is(err, service.ErrNotOwner):
			return fiber.NewError(fiber.StatusForbidden, "access denied")
		}
		return err
	}

	return c.JSON(toDeviceResponse(device, currentDeviceID, h.presence))
}

// Register handles POST /api/v1/devices.
//
//	@Summary     Register a new device for the authenticated user
//	@Tags        devices
//	@Security    BearerAuth
//	@Accept      json
//	@Produce     json
//	@Param       body body dto.DeviceRegisterRequest true "Device payload"
//	@Success     201 {object} dto.DeviceResponse
//	@Failure     400 {object} dto.ErrorResponse
//	@Router      /api/v1/devices [post]
func (h *DeviceHandler) Register(c *fiber.Ctx) error {
	userID, ok := UserIDFromCtx(c)
	if !ok {
		return fiber.NewError(fiber.StatusUnauthorized, "unauthorized")
	}

	var req dto.DeviceRegisterRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}
	if req.Name == "" {
		return fiber.NewError(fiber.StatusBadRequest, "name is required")
	}

	pubKey, err := base64.StdEncoding.DecodeString(req.PublicKey)
	if err != nil || len(pubKey) != 32 {
		return fiber.NewError(fiber.StatusBadRequest, "public_key must be a 32-byte X25519 key encoded as base64")
	}

	device, err := h.svc.Register(c.UserContext(), userID, service.DeviceInput{
		Name:      req.Name,
		Platform:  req.Platform,
		PublicKey: pubKey,
	})
	if err != nil {
		return err
	}

	return c.Status(fiber.StatusCreated).JSON(toDeviceResponse(device, uuid.Nil, h.presence))
}

// Rename handles PATCH /api/v1/devices/:id.
func (h *DeviceHandler) Rename(c *fiber.Ctx) error {
	userID, ok := UserIDFromCtx(c)
	if !ok {
		return fiber.NewError(fiber.StatusUnauthorized, "unauthorized")
	}
	currentDeviceID, _ := DeviceIDFromCtx(c)

	deviceID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid device id")
	}

	var req dto.DeviceRenameRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}
	name := strings.TrimSpace(req.Name)
	if name == "" {
		return fiber.NewError(fiber.StatusBadRequest, "name is required")
	}

	if err := h.svc.Rename(c.UserContext(), userID, deviceID, name); err != nil {
		switch {
		case errors.Is(err, repository.ErrNotFound):
			return fiber.NewError(fiber.StatusNotFound, "device not found")
		case errors.Is(err, service.ErrNotOwner):
			return fiber.NewError(fiber.StatusForbidden, "access denied")
		}
		return err
	}

	device, err := h.svc.Get(c.UserContext(), userID, deviceID)
	if err != nil {
		return err
	}

	return c.JSON(toDeviceResponse(device, currentDeviceID, h.presence))
}

// Revoke handles DELETE /api/v1/devices/:id.
//
//	@Summary     Revoke a device (and all its sessions)
//	@Tags        devices
//	@Security    BearerAuth
//	@Param       id  path string true "Device UUID"
//	@Success     200 {object} dto.MessageResponse
//	@Failure     403 {object} dto.ErrorResponse
//	@Failure     404 {object} dto.ErrorResponse
//	@Router      /api/v1/devices/{id} [delete]
func (h *DeviceHandler) Revoke(c *fiber.Ctx) error {
	userID, ok := UserIDFromCtx(c)
	if !ok {
		return fiber.NewError(fiber.StatusUnauthorized, "unauthorized")
	}

	deviceID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid device id")
	}

	if err := h.svc.Revoke(c.UserContext(), userID, deviceID); err != nil {
		switch {
		case errors.Is(err, repository.ErrNotFound):
			return fiber.NewError(fiber.StatusNotFound, "device not found")
		case errors.Is(err, service.ErrNotOwner):
			return fiber.NewError(fiber.StatusForbidden, "access denied")
		}
		return err
	}

	return c.JSON(dto.MessageResponse{Message: "device revoked"})
}

// Trust handles POST /api/v1/devices/:id/trust.
//
//	@Summary     Mark a device as trusted
//	@Tags        devices
//	@Security    BearerAuth
//	@Param       id  path string true "Device UUID"
//	@Success     200 {object} dto.MessageResponse
//	@Router      /api/v1/devices/{id}/trust [post]
func (h *DeviceHandler) Trust(c *fiber.Ctx) error {
	userID, ok := UserIDFromCtx(c)
	if !ok {
		return fiber.NewError(fiber.StatusUnauthorized, "unauthorized")
	}

	deviceID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid device id")
	}

	if err := h.svc.Trust(c.UserContext(), userID, deviceID); err != nil {
		switch {
		case errors.Is(err, repository.ErrNotFound):
			return fiber.NewError(fiber.StatusNotFound, "device not found")
		case errors.Is(err, service.ErrNotOwner):
			return fiber.NewError(fiber.StatusForbidden, "access denied")
		}
		return err
	}

	return c.JSON(dto.MessageResponse{Message: "device trusted"})
}

// InitiatePairing handles POST /api/v1/devices/pair/initiate.
//
//	@Summary     Create a QR code pairing session
//	@Tags        devices
//	@Security    BearerAuth
//	@Produce     json
//	@Success     200 {object} dto.PairInitiateResponse
//	@Failure     401 {object} dto.ErrorResponse
//	@Router      /api/v1/devices/pair/initiate [post]
func (h *DeviceHandler) InitiatePairing(c *fiber.Ctx) error {
	userID, ok := UserIDFromCtx(c)
	if !ok {
		return fiber.NewError(fiber.StatusUnauthorized, "unauthorized")
	}
	deviceID, ok := DeviceIDFromCtx(c)
	if !ok {
		return fiber.NewError(fiber.StatusUnauthorized, "unauthorized")
	}

	result, err := h.svc.InitiatePairing(c.UserContext(), deviceID, userID)
	if err != nil {
		return err
	}

	return c.JSON(dto.PairInitiateResponse{
		PairingID: result.Request.ID.String(),
		OTP:       result.Request.OTP,
		UserID:    userID.String(),
		ExpiresAt: result.Request.ExpiresAt,
		QRPayload: result.QRPayload,
	})
}

// ConfirmPairing handles POST /api/v1/devices/pair/confirm (no auth required).
//
//	@Summary     Confirm QR pairing and receive auth tokens for the new device
//	@Tags        devices
//	@Accept      json
//	@Produce     json
//	@Param       body body dto.PairConfirmRequest true "Pairing confirmation"
//	@Success     201 {object} dto.PairConfirmResponse
//	@Failure     400 {object} dto.ErrorResponse
//	@Failure     404 {object} dto.ErrorResponse  "invalid or expired OTP"
//	@Router      /api/v1/devices/pair/confirm [post]
func (h *DeviceHandler) ConfirmPairing(c *fiber.Ctx) error {
	var req dto.PairConfirmRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}
	if len(req.OTP) != 6 {
		return fiber.NewError(fiber.StatusBadRequest, "otp must be 6 digits")
	}

	pubKey, err := base64.StdEncoding.DecodeString(req.PublicKey)
	if err != nil || len(pubKey) != 32 {
		return fiber.NewError(fiber.StatusBadRequest, "public_key must be a 32-byte X25519 key encoded as base64")
	}

	ip := ipAddress(c)
	ua := c.Get("User-Agent")

	result, err := h.svc.ConfirmPairing(c.UserContext(), service.PairConfirmInput{
		OTP:       req.OTP,
		Name:      req.Name,
		Platform:  req.Platform,
		PublicKey: pubKey,
		IPAddress: &ip,
		UserAgent: strPtr(ua),
	})
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "invalid or expired pairing code")
		}
		return err
	}

	return c.Status(fiber.StatusCreated).JSON(dto.PairConfirmResponse{
		AuthResponse: toAuthResponse(result),
		Device: dto.DeviceResponse{
			ID:        result.DeviceID.String(),
			Name:      req.Name,
			Platform:  req.Platform,
			Trusted:   true,
			IsCurrent: true,
		},
	})
}

// ── helpers ───────────────────────────────────────────────────────────────────

const trustedRecentWindow = 30 * 24 * time.Hour

func isTrustedActiveDevice(d *repository.Device, now time.Time) bool {
	if !d.Trusted {
		return false
	}
	if d.TrustedUntil != nil && d.TrustedUntil.After(now) {
		return true
	}
	if d.LastSeenAt != nil && now.Sub(*d.LastSeenAt) <= trustedRecentWindow {
		return true
	}
	return false
}

func toDeviceResponse(d *repository.Device, currentDeviceID uuid.UUID, presence devicePresence) dto.DeviceResponse {
	online := false
	if presence != nil {
		online = presence.IsDeviceOnline(d.ID)
	}
	return dto.DeviceResponse{
		ID:           d.ID.String(),
		Name:         d.Name,
		Platform:     d.Platform,
		Trusted:      d.Trusted,
		TrustedUntil: d.TrustedUntil,
		Online:       online,
		LastSeenAt:   d.LastSeenAt,
		CreatedAt:    d.CreatedAt,
		IsCurrent:    d.ID == currentDeviceID,
	}
}
