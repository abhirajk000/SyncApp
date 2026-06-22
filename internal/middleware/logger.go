package middleware

import (
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

// ZerologLogger returns a Fiber middleware that emits one structured log
// line per request using zerolog. Log level is chosen by HTTP status:
//
//	5xx → error
//	4xx → warn
//	2xx/3xx → info
func ZerologLogger() fiber.Handler {
	return func(c *fiber.Ctx) error {
		start := time.Now()

		chainErr := c.Next()

		status := c.Response().StatusCode()
		latency := time.Since(start)

		var event *zerolog.Event
		switch {
		case status >= 500:
			event = log.Error()
		case status >= 400:
			event = log.Warn()
		default:
			event = log.Info()
		}

		reqID, _ := c.Locals("requestid").(string)

		event.
			Str("method", c.Method()).
			Str("path", c.Path()).
			Int("status", status).
			Dur("latency_ms", latency).
			Str("ip", c.IP()).
			Str("request_id", reqID).
			Int("bytes_sent", len(c.Response().Body())).
			Msg("request")

		return chainErr
	}
}
