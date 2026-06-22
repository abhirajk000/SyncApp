package handler

import (
	"runtime"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/syncbridge/api/internal/database"
)

// Build metadata — overridden at compile time via -ldflags.
var (
	Version   = "dev"
	Commit    = "unknown"
	BuildDate = "unknown"
)

var startTime = time.Now()

// HealthHandler serves the three infrastructure endpoints that load
// balancers and orchestrators rely on.
type HealthHandler struct {
	db *database.DB
}

func NewHealthHandler(db *database.DB) *HealthHandler {
	return &HealthHandler{db: db}
}

// Liveness — GET /health
// Fast path: returns 200 as long as the process is alive.
// No dependency checks — used by load-balancer HTTP health probes.
func (h *HealthHandler) Liveness(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{
		"status": "ok",
	})
}

// Readiness — GET /ready
// Deep check: verifies every required dependency is reachable.
// Returns 503 if any dependency is unhealthy.
// Used by Kubernetes readiness probes.
func (h *HealthHandler) Readiness(c *fiber.Ctx) error {
	checks := fiber.Map{}
	allOK := true

	if err := h.db.Ping(c.Context()); err != nil {
		checks["database"] = fiber.Map{
			"status": "error",
			"error":  err.Error(),
		}
		allOK = false
	} else {
		stat := h.db.Stats()
		checks["database"] = fiber.Map{
			"status":          "ok",
			"total_conns":     stat.TotalConns(),
			"acquired_conns":  stat.AcquiredConns(),
			"idle_conns":      stat.IdleConns(),
			"max_conns":       stat.MaxConns(),
		}
	}

	code := fiber.StatusOK
	status := "ready"
	if !allOK {
		code = fiber.StatusServiceUnavailable
		status = "not_ready"
	}

	return c.Status(code).JSON(fiber.Map{
		"status": status,
		"checks": checks,
	})
}

// Version — GET /version
// Returns immutable build metadata. Safe to expose publicly.
func (h *HealthHandler) Version(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{
		"version":    Version,
		"commit":     Commit,
		"build_date": BuildDate,
		"go_version": runtime.Version(),
		"uptime":     time.Since(startTime).Round(time.Second).String(),
	})
}
