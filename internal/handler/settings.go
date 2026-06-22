package handler

// SettingsHandler exposes the per-user retention settings API.
//
// Endpoints:
//   GET  /api/v1/settings/retention   → current preference + valid options
//   PUT  /api/v1/settings/retention   → update preference

import (
	"context"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/repository"
)

// userSettingsRepo is the repository interface expected by SettingsHandler.
type userSettingsRepo interface {
	Get(ctx context.Context, userID uuid.UUID) (*repository.UserSettings, error)
	Upsert(ctx context.Context, userID uuid.UUID, minutes int) error
}

// SettingsHandler manages user-scoped retention settings.
type SettingsHandler struct {
	repo userSettingsRepo
}

// NewSettingsHandler creates a SettingsHandler.
func NewSettingsHandler(repo userSettingsRepo) *SettingsHandler {
	return &SettingsHandler{repo: repo}
}

// GetRetention returns the current retention preference and the list of valid options.
//
//	GET /api/v1/settings/retention
func (h *SettingsHandler) GetRetention(c *fiber.Ctx) error {
	userID, ok := UserIDFromCtx(c)
	if !ok {
		return fiber.ErrUnauthorized
	}

	s, err := h.repo.Get(c.Context(), userID)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load settings")
	}

	options := make([]int, 0, len(dto.RetentionOptions))
	for _, o := range dto.RetentionOptions {
		options = append(options, o.Minutes)
	}

	return c.JSON(dto.RetentionSettingsResponse{
		RetentionMinutes: s.RetentionMinutes,
		ValidOptions:     options,
	})
}

// UpdateRetention sets the user's preferred retention window.
//
//	PUT /api/v1/settings/retention
func (h *SettingsHandler) UpdateRetention(c *fiber.Ctx) error {
	userID, ok := UserIDFromCtx(c)
	if !ok {
		return fiber.ErrUnauthorized
	}

	var req dto.RetentionSettingsRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}

	if !repository.ValidRetentionMinutes[req.RetentionMinutes] {
		return fiber.NewError(fiber.StatusBadRequest,
			"retention_minutes must be one of: 30, 60, 120, 360, 1440")
	}

	if err := h.repo.Upsert(c.Context(), userID, req.RetentionMinutes); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to save settings")
	}

	return h.GetRetention(c)
}

// RegisterRoutes attaches the settings endpoints to the given router group.
func (h *SettingsHandler) RegisterRoutes(api fiber.Router) {
	settings := api.Group("/settings")
	settings.Get("/retention", h.GetRetention)
	settings.Put("/retention", h.UpdateRetention)
}
