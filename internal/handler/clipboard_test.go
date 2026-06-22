package handler_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/handler"
	"github.com/syncbridge/api/internal/service"
)

// ── stub clipboard service ────────────────────────────────────────────────────

type stubClipboardService struct {
	syncEntry  *dto.ClipboardEntryResponse
	syncDeduped bool
	syncErr    error

	currentEntry *dto.ClipboardEntryResponse
	currentErr   error

	historyResp *dto.ClipboardHistoryResponse
	historyErr  error

	byIDEntry *dto.ClipboardEntryResponse
	byIDErr   error

	deleteErr error
	pinErr    error
}

func (s *stubClipboardService) Sync(_ context.Context, _, _ uuid.UUID, _, _ string) (*dto.ClipboardEntryResponse, bool, error) {
	return s.syncEntry, s.syncDeduped, s.syncErr
}
func (s *stubClipboardService) GetCurrent(_ context.Context, _ uuid.UUID) (*dto.ClipboardEntryResponse, error) {
	return s.currentEntry, s.currentErr
}
func (s *stubClipboardService) GetHistory(_ context.Context, _ uuid.UUID, _, _ int) (*dto.ClipboardHistoryResponse, error) {
	return s.historyResp, s.historyErr
}
func (s *stubClipboardService) GetByID(_ context.Context, _, _ uuid.UUID) (*dto.ClipboardEntryResponse, error) {
	return s.byIDEntry, s.byIDErr
}
func (s *stubClipboardService) DownloadThumbnail(_ context.Context, _, _ uuid.UUID) (io.ReadCloser, int64, error) {
	return nil, 0, service.ErrClipboardNotFound
}
func (s *stubClipboardService) Delete(_ context.Context, _, _ uuid.UUID) error {
	return s.deleteErr
}
func (s *stubClipboardService) Pin(_ context.Context, _, _ uuid.UUID, _ bool) error {
	return s.pinErr
}

// ── helpers ───────────────────────────────────────────────────────────────────

func newClipboardApp(svc *stubClipboardService) *fiber.App {
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

	h := handler.NewClipboardHandler(svc)

	// Inject fake auth locals to simulate RequireAuth middleware.
	// Values must be uuid.UUID (same type as SetAuthLocals writes).
	userID := uuid.New()
	deviceID := uuid.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("user_id", userID)
		c.Locals("device_id", deviceID)
		return c.Next()
	})

	app.Post("/api/v1/clipboard",            h.Sync)
	app.Get("/api/v1/clipboard/current",     h.GetCurrent)
	app.Get("/api/v1/clipboard",             h.GetHistory)
	app.Get("/api/v1/clipboard/:id",         h.GetByID)
	app.Delete("/api/v1/clipboard/:id",      h.Delete)
	app.Post("/api/v1/clipboard/:id/pin",    h.Pin)
	return app
}

func doRequest(t *testing.T, app *fiber.App, method, url string, body any) *http.Response {
	t.Helper()
	var bodyReader io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		bodyReader = bytes.NewReader(b)
	}
	req := httptest.NewRequest(method, url, bodyReader)
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	return resp
}

func parseBody(t *testing.T, resp *http.Response, v any) {
	t.Helper()
	defer resp.Body.Close()
	if err := json.NewDecoder(resp.Body).Decode(v); err != nil {
		t.Fatalf("parse body: %v", err)
	}
}

func makeEntry() *dto.ClipboardEntryResponse {
	return &dto.ClipboardEntryResponse{
		ID:             uuid.New().String(),
		ContentType:    "text/plain",
		Content:        "test clipboard content",
		SourceDeviceID: uuid.New().String(),
		PlaintextSize:  22,
		VectorClock:    map[string]int64{uuid.New().String(): time.Now().UnixNano()},
		Pinned:         false,
		Deduplicated:   false,
		CreatedAt:      time.Now(),
	}
}

// ── Sync tests ────────────────────────────────────────────────────────────────

func TestClipboardSync_Created(t *testing.T) {
	entry := makeEntry()
	svc := &stubClipboardService{syncEntry: entry, syncDeduped: false}
	app := newClipboardApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/clipboard", map[string]string{
		"content_type": "text/plain",
		"content":      "test clipboard content",
	})

	if resp.StatusCode != http.StatusCreated {
		t.Errorf("expected 201, got %d", resp.StatusCode)
	}
	if resp.Header.Get("X-Deduplicated") == "true" {
		t.Error("should not have X-Deduplicated header on new entry")
	}

	var got dto.ClipboardEntryResponse
	parseBody(t, resp, &got)
	if got.ID != entry.ID {
		t.Errorf("entry ID mismatch: %q vs %q", got.ID, entry.ID)
	}
}

func TestClipboardSync_Deduplicated(t *testing.T) {
	entry := makeEntry()
	entry.Deduplicated = true
	svc := &stubClipboardService{syncEntry: entry, syncDeduped: true}
	app := newClipboardApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/clipboard", map[string]string{
		"content_type": "text/plain",
		"content":      "same content",
	})

	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200 for deduped, got %d", resp.StatusCode)
	}
	if resp.Header.Get("X-Deduplicated") != "true" {
		t.Error("expected X-Deduplicated: true header")
	}
}

func TestClipboardSync_MissingContentType(t *testing.T) {
	svc := &stubClipboardService{}
	app := newClipboardApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/clipboard", map[string]string{
		"content": "no content type",
	})

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
}

func TestClipboardSync_UnsupportedType(t *testing.T) {
	svc := &stubClipboardService{syncErr: service.ErrUnsupportedContentType}
	app := newClipboardApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/clipboard", map[string]string{
		"content_type": "image/png",
		"content":      "not allowed",
	})

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400 for unsupported type, got %d", resp.StatusCode)
	}
}

func TestClipboardSync_TooLarge(t *testing.T) {
	svc := &stubClipboardService{syncErr: service.ErrContentTooLarge}
	app := newClipboardApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/clipboard", map[string]string{
		"content_type": "text/plain",
		"content":      "oversized",
	})

	if resp.StatusCode != http.StatusRequestEntityTooLarge {
		t.Errorf("expected 413, got %d", resp.StatusCode)
	}
}

// ── GetCurrent tests ──────────────────────────────────────────────────────────

func TestGetCurrent_OK(t *testing.T) {
	entry := makeEntry()
	svc := &stubClipboardService{currentEntry: entry}
	app := newClipboardApp(svc)

	resp := doRequest(t, app, http.MethodGet, "/api/v1/clipboard/current", nil)

	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
	var got dto.ClipboardEntryResponse
	parseBody(t, resp, &got)
	if got.Content != entry.Content {
		t.Errorf("content mismatch: %q", got.Content)
	}
}

func TestGetCurrent_Empty(t *testing.T) {
	svc := &stubClipboardService{currentErr: service.ErrClipboardNotFound}
	app := newClipboardApp(svc)

	resp := doRequest(t, app, http.MethodGet, "/api/v1/clipboard/current", nil)
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("expected 404, got %d", resp.StatusCode)
	}
}

// ── GetHistory tests ──────────────────────────────────────────────────────────

func TestGetHistory_OK(t *testing.T) {
	svc := &stubClipboardService{historyResp: &dto.ClipboardHistoryResponse{
		Entries: []dto.ClipboardEntryResponse{*makeEntry(), *makeEntry()},
		Total:   2, Limit: 50, Offset: 0, HasMore: false,
	}}
	app := newClipboardApp(svc)

	resp := doRequest(t, app, http.MethodGet, "/api/v1/clipboard?limit=50&offset=0", nil)
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
	var got dto.ClipboardHistoryResponse
	parseBody(t, resp, &got)
	if len(got.Entries) != 2 {
		t.Errorf("expected 2 entries, got %d", len(got.Entries))
	}
}

// ── GetByID tests ─────────────────────────────────────────────────────────────

func TestGetByID_OK(t *testing.T) {
	entry := makeEntry()
	svc := &stubClipboardService{byIDEntry: entry}
	app := newClipboardApp(svc)

	resp := doRequest(t, app, http.MethodGet, "/api/v1/clipboard/"+entry.ID, nil)
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
}

func TestGetByID_NotFound(t *testing.T) {
	svc := &stubClipboardService{byIDErr: service.ErrClipboardNotFound}
	app := newClipboardApp(svc)

	resp := doRequest(t, app, http.MethodGet, "/api/v1/clipboard/"+uuid.New().String(), nil)
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("expected 404, got %d", resp.StatusCode)
	}
}

func TestGetByID_BadID(t *testing.T) {
	svc := &stubClipboardService{}
	app := newClipboardApp(svc)

	resp := doRequest(t, app, http.MethodGet, "/api/v1/clipboard/not-a-uuid", nil)
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
}

// ── Delete tests ──────────────────────────────────────────────────────────────

func TestDelete_OK(t *testing.T) {
	svc := &stubClipboardService{}
	app := newClipboardApp(svc)

	resp := doRequest(t, app, http.MethodDelete, "/api/v1/clipboard/"+uuid.New().String(), nil)
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("expected 204, got %d", resp.StatusCode)
	}
}

func TestDelete_NotFound(t *testing.T) {
	svc := &stubClipboardService{deleteErr: service.ErrClipboardNotFound}
	app := newClipboardApp(svc)

	resp := doRequest(t, app, http.MethodDelete, "/api/v1/clipboard/"+uuid.New().String(), nil)
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("expected 404, got %d", resp.StatusCode)
	}
}

// ── Pin tests ─────────────────────────────────────────────────────────────────

func TestPin_OK(t *testing.T) {
	svc := &stubClipboardService{}
	app := newClipboardApp(svc)

	resp := doRequest(t, app, http.MethodPost, "/api/v1/clipboard/"+uuid.New().String()+"/pin",
		map[string]bool{"pinned": true})
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("expected 204, got %d", resp.StatusCode)
	}
}
