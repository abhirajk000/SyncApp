package middleware

import (
	"context"
	"sync"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/handler"
)

// lastSeenStore bumps device activity timestamps.
type lastSeenStore interface {
	UpdateLastSeen(ctx context.Context, id uuid.UUID) error
}

// BumpLastSeen updates last_seen_at at most once per device every 5 minutes.
func BumpLastSeen(devices lastSeenStore) fiber.Handler {
	var throttle sync.Map // uuid.UUID → time.Time

	return func(c *fiber.Ctx) error {
		err := c.Next()

		deviceID, ok := handler.DeviceIDFromCtx(c)
		if !ok {
			return err
		}

		now := time.Now()
		if last, loaded := throttle.Load(deviceID); loaded {
			if now.Sub(last.(time.Time)) < 5*time.Minute {
				return err
			}
		}
		throttle.Store(deviceID, now)

		go func(id uuid.UUID) {
			_ = devices.UpdateLastSeen(context.Background(), id)
		}(deviceID)

		return err
	}
}
