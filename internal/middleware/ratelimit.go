package middleware

import (
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/limiter"

	"github.com/syncbridge/api/internal/config"
)

// RateLimit returns a Fiber middleware that limits requests using an in-process
// sliding-window counter keyed by IP address.
//
// Design:
//   - Storage is in-memory (no Redis dependency for Phase 3).
//   - Default: 60 requests / 60 seconds per IP.
//   - Auth endpoints use a tighter limit (see AuthRateLimit below).
//   - For multi-instance deployments, replace the default store with a
//     Redis-backed store in Phase 8 (scalability hardening).
//
// Configuration comes from config.RateLimitMax and config.RateLimitWindowSecs.
func RateLimit(cfg *config.Config) fiber.Handler {
	return limiter.New(limiter.Config{
		Max:        cfg.RateLimitMax,
		Expiration: time.Duration(cfg.RateLimitWindowSecs) * time.Second,
		KeyGenerator: func(c *fiber.Ctx) string {
			return clientIP(c)
		},
		LimitReached: func(c *fiber.Ctx) error {
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{
				"error": "too many requests, please slow down",
			})
		},
	})
}

// AuthRateLimit applies a stricter limit for authentication endpoints to
// slow down brute-force and credential-stuffing attacks.
// Default: 10 attempts per 60 seconds per IP.
func AuthRateLimit(cfg *config.Config) fiber.Handler {
	max := cfg.AuthRateLimitMax
	if max == 0 {
		max = 10
	}
	window := cfg.RateLimitWindowSecs
	if window == 0 {
		window = 60
	}

	return limiter.New(limiter.Config{
		Max:        max,
		Expiration: time.Duration(window) * time.Second,
		KeyGenerator: func(c *fiber.Ctx) string {
			// Key by IP + path so login and register share separate counters.
			return clientIP(c) + ":" + c.Path()
		},
		LimitReached: func(c *fiber.Ctx) error {
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{
				"error": "too many authentication attempts",
			})
		},
	})
}

// clientIP extracts the best-guess client IP, respecting X-Forwarded-For for
// deployments behind a reverse proxy (Caddy, nginx, etc.).
// NOTE: trust X-Forwarded-For only if the server runs behind a trusted proxy.
// Bind TRUSTED_PROXIES in config to lock this down in Phase 8.
func clientIP(c *fiber.Ctx) string {
	if ip := c.Get("X-Forwarded-For"); ip != "" {
		// First IP in a comma-separated list is the originating client.
		for i := 0; i < len(ip); i++ {
			if ip[i] == ',' {
				return ip[:i]
			}
		}
		return ip
	}
	return c.IP()
}
