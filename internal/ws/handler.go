package ws

import (
	"strings"

	"github.com/gofiber/fiber/v2"
	fiberws "github.com/gofiber/websocket/v2"
	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/auth"
)

// Compile-time assertion: *fiberws.Conn must satisfy the ws.Conn interface.
// This will fail at compile time if gofiber/websocket/v2 ever changes its API.
var _ Conn = (*fiberws.Conn)(nil)

// ── Fiber locals keys (private to this package) ───────────────────────────────

const (
	localUserID   = "ws_uid"
	localDeviceID = "ws_did"
	localPlatform = "ws_platform"
)

// ── WSAuth middleware ─────────────────────────────────────────────────────────

// WSAuth is a Fiber middleware that validates the access token before allowing
// a WebSocket upgrade.  Must be mounted before websocket.New().
//
// Token sources (checked in order):
//  1. Authorization: Bearer <token> header  — native clients (macOS, Android, iOS)
//  2. ?token=<access_token> query param     — browsers (WebSocket API cannot set headers)
//
// On success it writes user/device UUIDs into Fiber locals so ServeWS can read
// them via conn.Locals() after the upgrade.
func WSAuth(tokens *auth.TokenService) fiber.Handler {
	return func(c *fiber.Ctx) error {
		raw := extractBearer(c)
		if raw == "" {
			raw = c.Query("token")
		}
		if raw == "" {
			return fiber.NewError(fiber.StatusUnauthorized, "WebSocket token required")
		}

		claims, err := tokens.ValidateAccessToken(raw)
		if err != nil {
			if err == auth.ErrTokenExpired {
				return fiber.NewError(fiber.StatusUnauthorized, "token expired")
			}
			return fiber.NewError(fiber.StatusUnauthorized, "invalid token")
		}

		c.Locals(localUserID, claims.UserID)
		c.Locals(localDeviceID, claims.DeviceID)
		return c.Next()
	}
}

// UpgradeGuard rejects non-WebSocket requests to the /ws endpoint with 426.
// Mount this as the first middleware on the /ws path so plain HTTP clients
// receive a meaningful error before auth is checked.
func UpgradeGuard() fiber.Handler {
	return func(c *fiber.Ctx) error {
		if fiberws.IsWebSocketUpgrade(c) {
			return c.Next()
		}
		return fiber.NewError(fiber.StatusUpgradeRequired, "WebSocket upgrade required")
	}
}

// ── Handler ───────────────────────────────────────────────────────────────────

// Handler wraps a Hub and exposes ServeWS for use with fiberws.New().
type Handler struct {
	hub *Hub
}

// NewHandler creates a Handler.
func NewHandler(hub *Hub) *Handler {
	return &Handler{hub: hub}
}

// ServeWS is the Fiber WebSocket handler function.
//
// Connection lifecycle:
//  1. Read identity from Fiber locals (injected by WSAuth).
//  2. Allocate a Client using the *fiberws.Conn directly (it satisfies ws.Conn).
//  3. Send the Client to hub.register; hub.handleRegister spawns writePump.
//  4. readPump blocks in this goroutine until the connection closes.
//  5. readPump's defer sends to hub.unregister.
//  6. hub.handleUnregister closes send → writePump exits → conn.Close() called.
func (h *Handler) ServeWS(conn *fiberws.Conn) {
	userID, ok := conn.Locals(localUserID).(uuid.UUID)
	if !ok || userID == uuid.Nil {
		_ = conn.WriteMessage(CloseMessage, []byte("unauthorized"))
		return
	}
	deviceID, ok := conn.Locals(localDeviceID).(uuid.UUID)
	if !ok || deviceID == uuid.Nil {
		_ = conn.WriteMessage(CloseMessage, []byte("unauthorized"))
		return
	}
	platform, _ := conn.Locals(localPlatform).(string) // optional

	// *fiberws.Conn satisfies ws.Conn (verified by compile-time assertion above).
	client := newClient(h.hub, conn, userID, deviceID, platform)
	h.hub.register <- client
	client.readPump()
}

// ── helpers ───────────────────────────────────────────────────────────────────

func extractBearer(c *fiber.Ctx) string {
	h := c.Get("Authorization")
	if len(h) < 8 || !strings.EqualFold(h[:7], "bearer ") {
		return ""
	}
	return strings.TrimSpace(h[7:])
}
