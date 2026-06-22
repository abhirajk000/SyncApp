package handler_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/handler"
	"github.com/syncbridge/api/internal/repository"
)

// ── stub settings repo ────────────────────────────────────────────────────────

type stubSettingsRepo struct {
	settings *repository.UserSettings
	getErr   error
	upsertErr error
}

func (s *stubSettingsRepo) Get(_ context.Context, userID uuid.UUID) (*repository.UserSettings, error) {
	if s.getErr != nil {
		return nil, s.getErr
	}
	if s.settings != nil {
		return s.settings, nil
	}
	return &repository.UserSettings{UserID: userID, RetentionMinutes: 120}, nil
}

func (s *stubSettingsRepo) Upsert(_ context.Context, _ uuid.UUID, minutes int) error {
	if s.upsertErr != nil {
		return s.upsertErr
	}
	if s.settings == nil {
		s.settings = &repository.UserSettings{}
	}
	s.settings.RetentionMinutes = minutes
	return nil
}

// ── test app ──────────────────────────────────────────────────────────────────

func newSettingsApp(repo *stubSettingsRepo) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			code := fiber.StatusInternalServerError
			var e *fiber.Error
			if errors.As(err, &e) {
				code = e.Code
			}
			return c.Status(code).JSON(fiber.Map{"error": err.Error()})
		},
	})

	testUserID := uuid.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("user_id", testUserID)
		return c.Next()
	})

	h := handler.NewSettingsHandler(repo)
	h.RegisterRoutes(app.Group("/api/v1"))
	return app
}

// ── tests ─────────────────────────────────────────────────────────────────────

func TestSettingsHandler_GetRetention_Default(t *testing.T) {
	app := newSettingsApp(&stubSettingsRepo{})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/settings/retention", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d; want 200", resp.StatusCode)
	}

	var body dto.RetentionSettingsResponse
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body.RetentionMinutes != 120 {
		t.Errorf("RetentionMinutes = %d; want 120", body.RetentionMinutes)
	}
	if len(body.ValidOptions) == 0 {
		t.Error("ValidOptions is empty; want 5 options")
	}
}

func TestSettingsHandler_GetRetention_CustomValue(t *testing.T) {
	repo := &stubSettingsRepo{
		settings: &repository.UserSettings{RetentionMinutes: 360},
	}
	app := newSettingsApp(repo)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/settings/retention", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}

	var body dto.RetentionSettingsResponse
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body.RetentionMinutes != 360 {
		t.Errorf("RetentionMinutes = %d; want 360", body.RetentionMinutes)
	}
}

func TestSettingsHandler_UpdateRetention_Valid(t *testing.T) {
	repo := &stubSettingsRepo{}
	app := newSettingsApp(repo)

	reqBody, _ := json.Marshal(dto.RetentionSettingsRequest{RetentionMinutes: 60})
	req := httptest.NewRequest(http.MethodPut, "/api/v1/settings/retention",
		bytes.NewReader(reqBody))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d; want 200", resp.StatusCode)
	}

	var body dto.RetentionSettingsResponse
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body.RetentionMinutes != 60 {
		t.Errorf("RetentionMinutes = %d; want 60", body.RetentionMinutes)
	}
}

func TestSettingsHandler_UpdateRetention_InvalidValue(t *testing.T) {
	app := newSettingsApp(&stubSettingsRepo{})

	reqBody, _ := json.Marshal(dto.RetentionSettingsRequest{RetentionMinutes: 45})
	req := httptest.NewRequest(http.MethodPut, "/api/v1/settings/retention",
		bytes.NewReader(reqBody))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d; want 400", resp.StatusCode)
	}
}

func TestSettingsHandler_UpdateRetention_AllValidOptions(t *testing.T) {
	valid := []int{30, 60, 120, 360, 1440}
	for _, v := range valid {
		t.Run("minutes="+itoa(v), func(t *testing.T) {
			app := newSettingsApp(&stubSettingsRepo{})
			reqBody, _ := json.Marshal(dto.RetentionSettingsRequest{RetentionMinutes: v})
			req := httptest.NewRequest(http.MethodPut, "/api/v1/settings/retention",
				bytes.NewReader(reqBody))
			req.Header.Set("Content-Type", "application/json")
			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("app.Test: %v", err)
			}
			if resp.StatusCode != http.StatusOK {
				t.Errorf("minutes=%d: status = %d; want 200", v, resp.StatusCode)
			}
		})
	}
}

func TestSettingsHandler_GetRetention_NoAuth(t *testing.T) {
	// App without auth middleware — Locals will be empty.
	app := fiber.New()
	h := handler.NewSettingsHandler(&stubSettingsRepo{})
	h.RegisterRoutes(app.Group("/api/v1"))

	req := httptest.NewRequest(http.MethodGet, "/api/v1/settings/retention", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status = %d; want 401", resp.StatusCode)
	}
}

// ── helpers ───────────────────────────────────────────────────────────────────

func itoa(n int) string { return fmt.Sprintf("%d", n) }
