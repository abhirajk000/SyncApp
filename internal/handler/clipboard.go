package handler

import (
	"context"
	"errors"
	"io"
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/service"
)

// ── clipboardSvc interface ────────────────────────────────────────────────────

// clipboardService is the subset of service.ClipboardService the handler needs.
// Defined here (consumer package) so the handler is testable without the full service.
type clipboardService interface {
	Sync(ctx context.Context, userID, sourceDeviceID uuid.UUID, contentType, content string) (*dto.ClipboardEntryResponse, bool, error)
	GetCurrent(ctx context.Context, userID uuid.UUID) (*dto.ClipboardEntryResponse, error)
	GetHistory(ctx context.Context, userID uuid.UUID, limit, offset int) (*dto.ClipboardHistoryResponse, error)
	GetByID(ctx context.Context, userID, id uuid.UUID) (*dto.ClipboardEntryResponse, error)
	DownloadThumbnail(ctx context.Context, userID, id uuid.UUID) (io.ReadCloser, int64, error)
	Delete(ctx context.Context, userID, id uuid.UUID) error
	Pin(ctx context.Context, userID, id uuid.UUID, pinned bool) error
}

// ── ClipboardHandler ──────────────────────────────────────────────────────────

// ClipboardHandler exposes clipboard endpoints over HTTP.
type ClipboardHandler struct {
	svc clipboardService
}

// NewClipboardHandler creates a ClipboardHandler.
func NewClipboardHandler(svc clipboardService) *ClipboardHandler {
	return &ClipboardHandler{svc: svc}
}

// ── POST /api/v1/clipboard ────────────────────────────────────────────────────

// Sync handles clipboard push from a device.
// On deduplication the response carries HTTP 200 + X-Deduplicated: true.
// A fresh entry responds with HTTP 201.
func (h *ClipboardHandler) Sync(c *fiber.Ctx) error {
	userID, deviceID, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	var req dto.ClipboardSyncRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}
	if req.ContentType == "" {
		return fiber.NewError(fiber.StatusBadRequest, "content_type is required")
	}
	if req.Content == "" {
		return fiber.NewError(fiber.StatusBadRequest, "content must not be empty")
	}

	entry, deduped, err := h.svc.Sync(c.Context(), userID, deviceID, req.ContentType, req.Content)
	if err != nil {
		return mapClipboardError(err)
	}

	if deduped {
		c.Set("X-Deduplicated", "true")
		return c.Status(fiber.StatusOK).JSON(entry)
	}
	return c.Status(fiber.StatusCreated).JSON(entry)
}

// ── GET /api/v1/clipboard/current ────────────────────────────────────────────

// GetCurrent returns the active clipboard content (LWW winner).
func (h *ClipboardHandler) GetCurrent(c *fiber.Ctx) error {
	userID, _, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	entry, err := h.svc.GetCurrent(c.Context(), userID)
	if err != nil {
		return mapClipboardError(err)
	}
	return c.JSON(entry)
}

// ── GET /api/v1/clipboard ─────────────────────────────────────────────────────

// GetHistory returns a paginated list of clipboard entries.
// Query params: limit (default 50, max 100) and offset (default 0).
func (h *ClipboardHandler) GetHistory(c *fiber.Ctx) error {
	userID, _, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	limit, _ := strconv.Atoi(c.Query("limit", "50"))
	offset, _ := strconv.Atoi(c.Query("offset", "0"))
	if offset < 0 {
		offset = 0
	}

	resp, err := h.svc.GetHistory(c.Context(), userID, limit, offset)
	if err != nil {
		return mapClipboardError(err)
	}
	return c.JSON(resp)
}

// ── GET /api/v1/clipboard/:id ─────────────────────────────────────────────────

// GetByID returns a single decrypted clipboard entry.
func (h *ClipboardHandler) GetByID(c *fiber.Ctx) error {
	userID, _, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid entry id")
	}

	entry, err := h.svc.GetByID(c.Context(), userID, id)
	if err != nil {
		return mapClipboardError(err)
	}
	return c.JSON(entry)
}

// ── GET /api/v1/clipboard/:id/thumbnail ──────────────────────────────────────

// DownloadThumbnail streams the small JPEG preview for a clipboard image entry.
func (h *ClipboardHandler) DownloadThumbnail(c *fiber.Ctx) error {
	userID, _, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid entry id")
	}

	rc, size, err := h.svc.DownloadThumbnail(c.Context(), userID, id)
	if err != nil {
		return mapClipboardError(err)
	}
	defer rc.Close()

	c.Set(fiber.HeaderContentType, "image/jpeg")
	c.Set("Cache-Control", "public, max-age=86400")
	if size > 0 {
		c.Set(fiber.HeaderContentLength, strconv.FormatInt(size, 10))
	}
	c.Status(fiber.StatusOK)
	_, copyErr := io.Copy(c.Response().BodyWriter(), rc)
	return copyErr
}

// ── DELETE /api/v1/clipboard/:id ─────────────────────────────────────────────

// Delete removes a clipboard entry.  Pinned entries cannot be deleted.
func (h *ClipboardHandler) Delete(c *fiber.Ctx) error {
	userID, _, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid entry id")
	}

	if err := h.svc.Delete(c.Context(), userID, id); err != nil {
		return mapClipboardError(err)
	}
	return c.SendStatus(fiber.StatusNoContent)
}

// ── POST /api/v1/clipboard/:id/pin ───────────────────────────────────────────

// Pin pins or unpins an entry.  Body: {"pinned": true|false}.
func (h *ClipboardHandler) Pin(c *fiber.Ctx) error {
	userID, _, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid entry id")
	}

	var body struct {
		Pinned bool `json:"pinned"`
	}
	if err := c.BodyParser(&body); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}

	if err := h.svc.Pin(c.Context(), userID, id, body.Pinned); err != nil {
		return mapClipboardError(err)
	}
	return c.SendStatus(fiber.StatusNoContent)
}

// ── helpers ───────────────────────────────────────────────────────────────────

// extractIdentity reads the authenticated userID and deviceID from Fiber locals.
// They are written by middleware.RequireAuth via SetAuthLocals.
func extractIdentity(c *fiber.Ctx) (userID, deviceID uuid.UUID, err error) {
	uid, ok1 := UserIDFromCtx(c)
	did, ok2 := DeviceIDFromCtx(c)
	if !ok1 || !ok2 {
		return uuid.Nil, uuid.Nil, errors.New("auth context missing")
	}
	return uid, did, nil
}

// mapClipboardError maps domain errors to HTTP errors.
func mapClipboardError(err error) *fiber.Error {
	switch {
	case errors.Is(err, service.ErrUnsupportedContentType):
		return fiber.NewError(fiber.StatusBadRequest, err.Error())
	case errors.Is(err, service.ErrContentTooLarge):
		return fiber.NewError(fiber.StatusRequestEntityTooLarge, err.Error())
	case errors.Is(err, service.ErrClipboardNotFound):
		return fiber.NewError(fiber.StatusNotFound, "clipboard entry not found")
	default:
		return fiber.NewError(fiber.StatusInternalServerError, "internal error")
	}
}
