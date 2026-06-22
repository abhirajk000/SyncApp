// Package middleware provides Fiber middleware components for SyncBridge.
package middleware

import (
	"context"
	"errors"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/auth"
	"github.com/syncbridge/api/internal/handler"
	"github.com/syncbridge/api/internal/repository"
)

// sessionValidator checks that a refresh-token hash is still active in the DB.
// The auth middleware uses it to support server-side session revocation.
// Only the session lookup is needed here; we do NOT look up the refresh token
// on every access-token request (that would be a DB hit per request).
// Instead, access tokens are stateless; session invalidation is enforced at
// the Refresh endpoint, which checks the DB before issuing new tokens.
type sessionValidator interface {
	FindByTokenHash(ctx context.Context, hash string) (*repository.Session, error)
}

// RequireAuth returns a Fiber middleware that validates the Bearer JWT in the
// Authorization header and populates c.Locals with the authenticated
// user/device UUIDs.
//
// Flow:
//  1. Extract "Bearer <token>" from Authorization header.
//  2. Parse + validate the JWT signature and expiry.
//  3. Confirm the token type is "access".
//  4. Set user_id and device_id in Fiber locals for downstream handlers.
//
// The middleware does NOT perform a DB round-trip on every request.
// Revocation of access tokens is accepted until they expire (max 24 h);
// for immediate revocation use a short TTL or upgrade to a token blocklist
// in Phase 8 (security hardening).
func RequireAuth(tokens *auth.TokenService) fiber.Handler {
	return func(c *fiber.Ctx) error {
		raw := extractBearerToken(c)
		if raw == "" {
			return fiber.NewError(fiber.StatusUnauthorized, "authorization header required")
		}

		claims, err := tokens.ValidateAccessToken(raw)
		if err != nil {
			switch {
			case errors.Is(err, auth.ErrTokenExpired):
				return fiber.NewError(fiber.StatusUnauthorized, "token expired")
			default:
				return fiber.NewError(fiber.StatusUnauthorized, "invalid token")
			}
		}

		// Populate locals so all downstream handlers can read identity cheaply.
		handler.SetAuthLocals(c, claims.UserID, claims.DeviceID)

		return c.Next()
	}
}

// RequireAuthWithRevocationCheck is a stricter variant that also verifies the
// device has not been revoked since the access token was issued.
// Use this on sensitive endpoints (device revocation, pairing, key operations).
// It trades an extra DB query per request for immediate revocation semantics.
func RequireAuthWithRevocationCheck(tokens *auth.TokenService, devices deviceChecker) fiber.Handler {
	return func(c *fiber.Ctx) error {
		raw := extractBearerToken(c)
		if raw == "" {
			return fiber.NewError(fiber.StatusUnauthorized, "authorization header required")
		}

		claims, err := tokens.ValidateAccessToken(raw)
		if err != nil {
			if errors.Is(err, auth.ErrTokenExpired) {
				return fiber.NewError(fiber.StatusUnauthorized, "token expired")
			}
			return fiber.NewError(fiber.StatusUnauthorized, "invalid token")
		}

		// Fast revocation check — one indexed lookup by primary key.
		device, err := devices.FindActiveByID(c.UserContext(), claims.DeviceID)
		if err != nil {
			if errors.Is(err, repository.ErrNotFound) {
				return fiber.NewError(fiber.StatusUnauthorized, "device revoked")
			}
			return fiber.NewError(fiber.StatusInternalServerError, "authorization check failed")
		}

		// Confirm ownership matches the token claim.
		if device.UserID != claims.UserID {
			return fiber.NewError(fiber.StatusUnauthorized, "token mismatch")
		}

		handler.SetAuthLocals(c, claims.UserID, claims.DeviceID)
		return c.Next()
	}
}

// deviceChecker is the minimal interface used by RequireAuthWithRevocationCheck.
type deviceChecker interface {
	FindActiveByID(ctx context.Context, id uuid.UUID) (*repository.Device, error)
}

// ── helpers ───────────────────────────────────────────────────────────────────

// extractBearerToken reads the Bearer token from the Authorization header.
// Returns an empty string if the header is absent or malformed.
func extractBearerToken(c *fiber.Ctx) string {
	header := c.Get("Authorization")
	if len(header) < 8 {
		return ""
	}
	if !strings.EqualFold(header[:7], "bearer ") {
		return ""
	}
	return strings.TrimSpace(header[7:])
}
