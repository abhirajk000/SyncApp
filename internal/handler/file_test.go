package handler_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/handler"
	"github.com/syncbridge/api/internal/service"
)

// ── stub file service ─────────────────────────────────────────────────────────

type stubFileService struct {
	initResp     *dto.FileInitResponse
	initErr      error
	chunkErr     error
	completeResp *dto.FileResponse
	completeErr  error
	statusResp   *dto.FileStatusResponse
	statusErr    error
	fileResp     *dto.FileResponse
	fileErr      error
	listResp     *dto.FileListResponse
	listErr      error
	dlReader     io.ReadCloser
	dlSize       int64
	dlMime       string
	dlErr        error
	thumbReader  io.ReadCloser
	thumbSize    int64
	thumbErr     error
	deleteErr    error
	pinErr       error
}

func (s *stubFileService) InitUpload(_ context.Context, _, _ uuid.UUID, _ dto.FileInitRequest) (*dto.FileInitResponse, error) {
	return s.initResp, s.initErr
}
func (s *stubFileService) UploadChunk(_ context.Context, _, _ uuid.UUID, _ uuid.UUID, _ int, _ []byte, _ string) error {
	return s.chunkErr
}
func (s *stubFileService) CompleteUpload(_ context.Context, _ uuid.UUID, _ uuid.UUID) (*dto.FileResponse, error) {
	return s.completeResp, s.completeErr
}
func (s *stubFileService) GetUploadStatus(_ context.Context, _, _ uuid.UUID) (*dto.FileStatusResponse, error) {
	return s.statusResp, s.statusErr
}
func (s *stubFileService) GetFile(_ context.Context, _, _ uuid.UUID) (*dto.FileResponse, error) {
	return s.fileResp, s.fileErr
}
func (s *stubFileService) ListFiles(_ context.Context, _ uuid.UUID, _, _ int) (*dto.FileListResponse, error) {
	return s.listResp, s.listErr
}
func (s *stubFileService) Download(_ context.Context, _, _, _ uuid.UUID) (io.ReadCloser, int64, string, error) {
	return s.dlReader, s.dlSize, s.dlMime, s.dlErr
}
func (s *stubFileService) DownloadThumbnail(_ context.Context, _, _ uuid.UUID) (io.ReadCloser, int64, error) {
	return s.thumbReader, s.thumbSize, s.thumbErr
}
func (s *stubFileService) DeleteFile(_ context.Context, _, _ uuid.UUID) error {
	return s.deleteErr
}
func (s *stubFileService) SetPinned(_ context.Context, _, _ uuid.UUID, _ bool) error {
	return s.pinErr
}
func (s *stubFileService) MarkDelivered(_ context.Context, _, _, _ uuid.UUID) error { return nil }

// ── test app builder ──────────────────────────────────────────────────────────

func newFileApp(svc *stubFileService) *fiber.App {
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

	h := handler.NewFileHandler(svc)

	testUserID := uuid.New()
	testDeviceID := uuid.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("user_id", testUserID)
		c.Locals("device_id", testDeviceID)
		return c.Next()
	})

	app.Post("/api/v1/files/init",                h.InitUpload)
	app.Get("/api/v1/files",                       h.ListFiles)
	app.Get("/api/v1/files/:id",                   h.GetFile)
	app.Get("/api/v1/files/:id/status",            h.GetUploadStatus)
	app.Put("/api/v1/files/:id/chunks/:n",         h.UploadChunk)
	app.Post("/api/v1/files/:id/complete",         h.CompleteUpload)
	app.Get("/api/v1/files/:id/download",          h.Download)
	app.Get("/api/v1/files/:id/thumbnail",         h.DownloadThumbnail)
	app.Post("/api/v1/files/:id/pin",              h.SetPinned)
	app.Delete("/api/v1/files/:id",                h.DeleteFile)
	return app
}

func doFileRequest(t *testing.T, app *fiber.App, method, url string, body any, contentType string) *http.Response {
	t.Helper()
	var bodyReader io.Reader
	if body != nil {
		switch v := body.(type) {
		case []byte:
			bodyReader = bytes.NewReader(v)
		default:
			b, _ := json.Marshal(v)
			bodyReader = bytes.NewReader(b)
		}
	}
	req := httptest.NewRequest(method, url, bodyReader)
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	} else {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	return resp
}

// ── InitUpload tests ──────────────────────────────────────────────────────────

func TestFileHandler_InitUpload_Created(t *testing.T) {
	fileID := uuid.New()
	svc := &stubFileService{initResp: &dto.FileInitResponse{
		FileID:     fileID.String(),
		ChunkSize:  4 * 1024 * 1024,
		ChunkCount: 1,
		ExpiresAt:  time.Now().Add(30 * 24 * time.Hour).Format(time.RFC3339),
	}}
	app := newFileApp(svc)

	body := dto.FileInitRequest{
		Name:      "doc.txt",
		MimeType:  "text/plain",
		TotalSize: 100,
		FileHash:  strings.Repeat("a", 64),
	}
	resp := doFileRequest(t, app, "POST", "/api/v1/files/init", body, "")
	if resp.StatusCode != http.StatusCreated {
		t.Errorf("want 201, got %d", resp.StatusCode)
	}
	var out dto.FileInitResponse
	parseBody(t, resp, &out)
	if out.FileID != fileID.String() {
		t.Errorf("FileID mismatch")
	}
}

func TestFileHandler_InitUpload_MissingFields(t *testing.T) {
	svc := &stubFileService{}
	app := newFileApp(svc)

	resp := doFileRequest(t, app, "POST", "/api/v1/files/init", map[string]any{
		"name": "only-name",
	}, "")
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("want 400, got %d", resp.StatusCode)
	}
}

func TestFileHandler_InitUpload_UnsupportedMIME(t *testing.T) {
	svc := &stubFileService{initErr: service.ErrUnsupportedMIME}
	app := newFileApp(svc)

	body := dto.FileInitRequest{
		Name:      "bad.exe",
		MimeType:  "application/x-executable",
		TotalSize: 100,
		FileHash:  strings.Repeat("b", 64),
	}
	resp := doFileRequest(t, app, "POST", "/api/v1/files/init", body, "")
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("want 400, got %d", resp.StatusCode)
	}
}

// ── UploadChunk tests ─────────────────────────────────────────────────────────

func TestFileHandler_UploadChunk_NoContent(t *testing.T) {
	svc := &stubFileService{}
	app := newFileApp(svc)

	resp := doFileRequest(t, app, "PUT",
		fmt.Sprintf("/api/v1/files/%s/chunks/0", uuid.New()),
		nil, "application/octet-stream",
	)
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("want 400, got %d", resp.StatusCode)
	}
}

func TestFileHandler_UploadChunk_Success(t *testing.T) {
	svc := &stubFileService{}
	app := newFileApp(svc)

	data := []byte("chunk bytes")
	resp := doFileRequest(t, app, "PUT",
		fmt.Sprintf("/api/v1/files/%s/chunks/0", uuid.New()),
		data, "application/octet-stream",
	)
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("want 204, got %d", resp.StatusCode)
	}
}

func TestFileHandler_UploadChunk_HashMismatch(t *testing.T) {
	svc := &stubFileService{chunkErr: service.ErrChunkHashMismatch}
	app := newFileApp(svc)

	req := httptest.NewRequest("PUT",
		fmt.Sprintf("/api/v1/files/%s/chunks/0", uuid.New()),
		bytes.NewReader([]byte("data")),
	)
	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("X-Chunk-Hash", strings.Repeat("0", 64))
	resp, _ := app.Test(req, -1)
	if resp.StatusCode != http.StatusUnprocessableEntity {
		t.Errorf("want 422, got %d", resp.StatusCode)
	}
}

// ── CompleteUpload tests ──────────────────────────────────────────────────────

func TestFileHandler_CompleteUpload_Success(t *testing.T) {
	fileID := uuid.New()
	svc := &stubFileService{completeResp: &dto.FileResponse{
		ID:     fileID.String(),
		Status: "ready",
	}}
	app := newFileApp(svc)

	resp := doFileRequest(t, app, "POST",
		fmt.Sprintf("/api/v1/files/%s/complete", fileID), nil, "")
	if resp.StatusCode != http.StatusOK {
		t.Errorf("want 200, got %d", resp.StatusCode)
	}
	var out dto.FileResponse
	parseBody(t, resp, &out)
	if out.Status != "ready" {
		t.Errorf("want status 'ready', got %q", out.Status)
	}
}

func TestFileHandler_CompleteUpload_NotAllChunks(t *testing.T) {
	svc := &stubFileService{completeErr: service.ErrNotAllChunks}
	app := newFileApp(svc)

	resp := doFileRequest(t, app, "POST",
		fmt.Sprintf("/api/v1/files/%s/complete", uuid.New()), nil, "")
	if resp.StatusCode != http.StatusConflict {
		t.Errorf("want 409, got %d", resp.StatusCode)
	}
}

// ── GetUploadStatus tests ─────────────────────────────────────────────────────

func TestFileHandler_GetUploadStatus(t *testing.T) {
	fileID := uuid.New()
	svc := &stubFileService{statusResp: &dto.FileStatusResponse{
		FileID:          fileID.String(),
		Status:          "uploading",
		ChunkCount:      2,
		ChunksReceived:  1,
		MissingChunks:   []int{1},
		ProgressPercent: 50,
	}}
	app := newFileApp(svc)

	resp := doFileRequest(t, app, "GET",
		fmt.Sprintf("/api/v1/files/%s/status", fileID), nil, "")
	if resp.StatusCode != http.StatusOK {
		t.Errorf("want 200, got %d", resp.StatusCode)
	}
	var out dto.FileStatusResponse
	parseBody(t, resp, &out)
	if out.ProgressPercent != 50 {
		t.Errorf("progress = %d, want 50", out.ProgressPercent)
	}
}

// ── ListFiles tests ───────────────────────────────────────────────────────────

func TestFileHandler_ListFiles(t *testing.T) {
	svc := &stubFileService{listResp: &dto.FileListResponse{
		Files: []dto.FileResponse{{ID: uuid.New().String(), Status: "ready"}},
		Total: 1, Limit: 50, Offset: 0,
	}}
	app := newFileApp(svc)

	resp := doFileRequest(t, app, "GET", "/api/v1/files", nil, "")
	if resp.StatusCode != http.StatusOK {
		t.Errorf("want 200, got %d", resp.StatusCode)
	}
	var out dto.FileListResponse
	parseBody(t, resp, &out)
	if out.Total != 1 {
		t.Errorf("total = %d, want 1", out.Total)
	}
}

// ── GetFile tests ─────────────────────────────────────────────────────────────

func TestFileHandler_GetFile_NotFound(t *testing.T) {
	svc := &stubFileService{fileErr: service.ErrFileNotFound}
	app := newFileApp(svc)

	resp := doFileRequest(t, app, "GET",
		fmt.Sprintf("/api/v1/files/%s", uuid.New()), nil, "")
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("want 404, got %d", resp.StatusCode)
	}
}

// ── Download tests ────────────────────────────────────────────────────────────

func TestFileHandler_Download_Streams(t *testing.T) {
	content := []byte("file bytes here")
	svc := &stubFileService{
		dlReader: io.NopCloser(bytes.NewReader(content)),
		dlSize:   int64(len(content)),
		dlMime:   "text/plain",
	}
	app := newFileApp(svc)

	resp := doFileRequest(t, app, "GET",
		fmt.Sprintf("/api/v1/files/%s/download", uuid.New()), nil, "")
	if resp.StatusCode != http.StatusOK {
		t.Errorf("want 200, got %d", resp.StatusCode)
	}
	body, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if !bytes.Equal(body, content) {
		t.Errorf("body mismatch: got %q, want %q", body, content)
	}
}

// ── Thumbnail tests ───────────────────────────────────────────────────────────

func TestFileHandler_DownloadThumbnail_NotFound(t *testing.T) {
	svc := &stubFileService{thumbErr: service.ErrFileNotFound}
	app := newFileApp(svc)

	resp := doFileRequest(t, app, "GET",
		fmt.Sprintf("/api/v1/files/%s/thumbnail", uuid.New()), nil, "")
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("want 404, got %d", resp.StatusCode)
	}
}

// ── Delete tests ──────────────────────────────────────────────────────────────

func TestFileHandler_Delete(t *testing.T) {
	svc := &stubFileService{}
	app := newFileApp(svc)

	resp := doFileRequest(t, app, "DELETE",
		fmt.Sprintf("/api/v1/files/%s", uuid.New()), nil, "")
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("want 204, got %d", resp.StatusCode)
	}
}

func TestFileHandler_Delete_NotFound(t *testing.T) {
	svc := &stubFileService{deleteErr: service.ErrFileNotFound}
	app := newFileApp(svc)

	resp := doFileRequest(t, app, "DELETE",
		fmt.Sprintf("/api/v1/files/%s", uuid.New()), nil, "")
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("want 404, got %d", resp.StatusCode)
	}
}

// ── invalid UUID parameter ────────────────────────────────────────────────────

func TestFileHandler_InvalidUUID(t *testing.T) {
	svc := &stubFileService{}
	app := newFileApp(svc)

	resp := doFileRequest(t, app, "GET", "/api/v1/files/not-a-uuid", nil, "")
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("want 400, got %d", resp.StatusCode)
	}
}
