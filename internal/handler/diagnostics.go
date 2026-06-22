package handler

// DiagnosticsHandler exposes a single endpoint that helps users and developers
// understand the current connection topology:
//
//	GET /api/v1/diagnostics
//
// The response includes the server version, the client's visible IP, the number
// of LAN-discovered peers, STUN/TURN configuration flags, and the user's
// retention setting.  All data is read-only; the endpoint never mutates state.

import (
	"context"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/repository"
)

// ── Interfaces ────────────────────────────────────────────────────────────────

// localPeerLister returns LAN-advertised peers for a user.
type localPeerLister interface {
	FindByUserID(ctx context.Context, userID uuid.UUID) ([]*repository.LocalPeer, error)
}

// userSettingsGetter returns the retention preference for a user.
type userSettingsGetter interface {
	Get(ctx context.Context, userID uuid.UUID) (*repository.UserSettings, error)
}

// ── DiagnosticsConfig ─────────────────────────────────────────────────────────

// DiagnosticsConfig carries the static server configuration that the
// diagnostics handler exposes to authenticated clients.
type DiagnosticsConfig struct {
	ServerVersion           string
	MDNSEnabled             bool
	STUNURLs                string // comma-separated
	TURNEnabled             bool
	StorageBackend          string
	DefaultRetentionMinutes int
}

// ── DiagnosticsHandler ────────────────────────────────────────────────────────

// DiagnosticsHandler serves the diagnostics endpoint.
type DiagnosticsHandler struct {
	localPeers localPeerLister
	settings   userSettingsGetter
	cfg        DiagnosticsConfig
}

// NewDiagnosticsHandler constructs a DiagnosticsHandler.
func NewDiagnosticsHandler(
	localPeers localPeerLister,
	settings userSettingsGetter,
	cfg DiagnosticsConfig,
) *DiagnosticsHandler {
	return &DiagnosticsHandler{
		localPeers: localPeers,
		settings:   settings,
		cfg:        cfg,
	}
}

// Get returns the diagnostics snapshot for the authenticated user.
//
//	GET /api/v1/diagnostics
func (h *DiagnosticsHandler) Get(c *fiber.Ctx) error {
	userID, ok := UserIDFromCtx(c)
	if !ok {
		return fiber.ErrUnauthorized
	}

	// Count LAN peers for this user.
	peerCount := 0
	if peers, err := h.localPeers.FindByUserID(c.Context(), userID); err == nil {
		peerCount = len(peers)
	}

	// Fetch user's retention preference.
	retentionMins := h.cfg.DefaultRetentionMinutes
	if us, err := h.settings.Get(c.Context(), userID); err == nil {
		retentionMins = us.RetentionMinutes
	}

	// Parse STUN URLs from comma-separated string.
	var stunURLs []string
	for _, s := range strings.Split(h.cfg.STUNURLs, ",") {
		if s = strings.TrimSpace(s); s != "" {
			stunURLs = append(stunURLs, s)
		}
	}

	return c.JSON(dto.DiagnosticsResponse{
		ServerVersion:           h.cfg.ServerVersion,
		ClientIP:                c.IP(),
		LocalPeers:              peerCount,
		MDNSEnabled:             h.cfg.MDNSEnabled,
		STUNURLs:                stunURLs,
		TURNEnabled:             h.cfg.TURNEnabled,
		StorageBackend:          h.cfg.StorageBackend,
		DefaultRetentionMinutes: h.cfg.DefaultRetentionMinutes,
		RetentionMinutes:        retentionMins,
	})
}
