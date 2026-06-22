package handler

import (
	"context"
	"errors"
	"io"
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/service"
)

// ── fileService interface ─────────────────────────────────────────────────────

type fileService interface {
	InitUpload(ctx context.Context, userID, senderDeviceID uuid.UUID, req dto.FileInitRequest) (*dto.FileInitResponse, error)
	UploadChunk(ctx context.Context, userID, senderDeviceID uuid.UUID, fileID uuid.UUID, chunkIndex int, data []byte, hash string) error
	CompleteUpload(ctx context.Context, userID, fileID uuid.UUID) (*dto.FileResponse, error)
	GetUploadStatus(ctx context.Context, userID, fileID uuid.UUID) (*dto.FileStatusResponse, error)
	GetFile(ctx context.Context, userID, fileID uuid.UUID) (*dto.FileResponse, error)
	ListFiles(ctx context.Context, userID uuid.UUID, limit, offset int) (*dto.FileListResponse, error)
	Download(ctx context.Context, userID, deviceID, fileID uuid.UUID) (io.ReadCloser, int64, string, error)
	DownloadThumbnail(ctx context.Context, userID, fileID uuid.UUID) (io.ReadCloser, int64, error)
	DeleteFile(ctx context.Context, userID, fileID uuid.UUID) error
	SetPinned(ctx context.Context, userID, fileID uuid.UUID, pinned bool) error
	MarkDelivered(ctx context.Context, userID, deviceID, fileID uuid.UUID) error
}

// ── FileHandler ───────────────────────────────────────────────────────────────

// FileHandler exposes the file-synchronisation API.
type FileHandler struct {
	svc fileService
}

// NewFileHandler creates a FileHandler.
func NewFileHandler(svc fileService) *FileHandler {
	return &FileHandler{svc: svc}
}

// ── POST /api/v1/files/init ───────────────────────────────────────────────────

// InitUpload validates file metadata and allocates the upload session.
// The response includes the chunk count and size so the client can split the
// file without guessing.
func (h *FileHandler) InitUpload(c *fiber.Ctx) error {
	userID, deviceID, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	var req dto.FileInitRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}
	if req.Name == "" || req.MimeType == "" || req.TotalSize <= 0 || req.FileHash == "" {
		return fiber.NewError(fiber.StatusBadRequest, "name, mime_type, total_size, and file_hash are required")
	}

	resp, err := h.svc.InitUpload(c.Context(), userID, deviceID, req)
	if err != nil {
		return mapFileError(err)
	}
	return c.Status(fiber.StatusCreated).JSON(resp)
}

// ── PUT /api/v1/files/:id/chunks/:n ──────────────────────────────────────────

// UploadChunk receives a raw chunk body (application/octet-stream).
// X-Chunk-Hash header must contain the SHA-256 hex of the chunk bytes.
func (h *FileHandler) UploadChunk(c *fiber.Ctx) error {
	userID, deviceID, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	fileID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid file id")
	}

	chunkIndex, err := strconv.Atoi(c.Params("n"))
	if err != nil || chunkIndex < 0 {
		return fiber.NewError(fiber.StatusBadRequest, "chunk index must be a non-negative integer")
	}

	data := c.Body()
	if len(data) == 0 {
		return fiber.NewError(fiber.StatusBadRequest, "chunk body must not be empty")
	}

	headerHash := c.Get("X-Chunk-Hash")

	if err := h.svc.UploadChunk(c.Context(), userID, deviceID, fileID, chunkIndex, data, headerHash); err != nil {
		return mapFileError(err)
	}

	return c.Status(fiber.StatusNoContent).Send(nil)
}

// ── POST /api/v1/files/:id/complete ──────────────────────────────────────────

// CompleteUpload triggers assembly, integrity validation, compression, and
// thumbnail generation.  Returns the final file metadata.
func (h *FileHandler) CompleteUpload(c *fiber.Ctx) error {
	userID, _, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	fileID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid file id")
	}

	resp, err := h.svc.CompleteUpload(c.Context(), userID, fileID)
	if err != nil {
		return mapFileError(err)
	}
	return c.JSON(resp)
}

// ── GET /api/v1/files/:id/status ─────────────────────────────────────────────

// GetUploadStatus returns which chunks are still missing so the client can
// resume an interrupted upload.
func (h *FileHandler) GetUploadStatus(c *fiber.Ctx) error {
	userID, _, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	fileID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid file id")
	}

	status, err := h.svc.GetUploadStatus(c.Context(), userID, fileID)
	if err != nil {
		return mapFileError(err)
	}
	return c.JSON(status)
}

// ── GET /api/v1/files ─────────────────────────────────────────────────────────

// ListFiles returns a paginated list of files for the authenticated user.
func (h *FileHandler) ListFiles(c *fiber.Ctx) error {
	userID, _, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	limit, _ := strconv.Atoi(c.Query("limit", "50"))
	offset, _ := strconv.Atoi(c.Query("offset", "0"))
	if offset < 0 {
		offset = 0
	}

	resp, err := h.svc.ListFiles(c.Context(), userID, limit, offset)
	if err != nil {
		return mapFileError(err)
	}
	return c.JSON(resp)
}

// ── GET /api/v1/files/:id ────────────────────────────────────────────────────

// GetFile returns metadata for a single file.
func (h *FileHandler) GetFile(c *fiber.Ctx) error {
	userID, _, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	fileID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid file id")
	}

	resp, err := h.svc.GetFile(c.Context(), userID, fileID)
	if err != nil {
		return mapFileError(err)
	}
	return c.JSON(resp)
}

// ── GET /api/v1/files/:id/download ───────────────────────────────────────────

// Download streams the file content to the client.
// The response Content-Type is set to the file's MIME type.
func (h *FileHandler) Download(c *fiber.Ctx) error {
	userID, deviceID, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	fileID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid file id")
	}

	rc, size, mimeType, err := h.svc.Download(c.Context(), userID, deviceID, fileID)
	if err != nil {
		return mapFileError(err)
	}
	defer rc.Close()

	c.Set(fiber.HeaderContentType, mimeType)
	if size > 0 {
		c.Set(fiber.HeaderContentLength, strconv.FormatInt(size, 10))
	}
	c.Status(fiber.StatusOK)
	_, copyErr := io.Copy(c.Response().BodyWriter(), rc)
	return copyErr
}

// ── GET /api/v1/files/:id/thumbnail ──────────────────────────────────────────

// DownloadThumbnail streams the 256×256 JPEG thumbnail.
// Returns 404 for non-image files or files not yet processed.
func (h *FileHandler) DownloadThumbnail(c *fiber.Ctx) error {
	userID, _, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	fileID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid file id")
	}

	rc, size, err := h.svc.DownloadThumbnail(c.Context(), userID, fileID)
	if err != nil {
		return mapFileError(err)
	}
	defer rc.Close()

	c.Set(fiber.HeaderContentType, "image/jpeg")
	if size > 0 {
		c.Set(fiber.HeaderContentLength, strconv.FormatInt(size, 10))
	}
	c.Status(fiber.StatusOK)
	_, copyErr := io.Copy(c.Response().BodyWriter(), rc)
	return copyErr
}

// ── DELETE /api/v1/files/:id ─────────────────────────────────────────────────

// DeleteFile soft-deletes a file.
func (h *FileHandler) DeleteFile(c *fiber.Ctx) error {
	userID, _, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	fileID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid file id")
	}

	if err := h.svc.DeleteFile(c.Context(), userID, fileID); err != nil {
		return mapFileError(err)
	}
	return c.SendStatus(fiber.StatusNoContent)
}

// ── POST /api/v1/files/:id/pin ────────────────────────────────────────────────

// SetPinned pins or unpins a file.  Body: {"pinned": true|false}.
func (h *FileHandler) SetPinned(c *fiber.Ctx) error {
	userID, _, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}

	fileID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid file id")
	}

	var body struct {
		Pinned bool `json:"pinned"`
	}
	if err := c.BodyParser(&body); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}

	if err := h.svc.SetPinned(c.Context(), userID, fileID, body.Pinned); err != nil {
		return mapFileError(err)
	}
	return c.SendStatus(fiber.StatusNoContent)
}

// ── POST /api/v1/files/:id/delivered ─────────────────────────────────────────

// MarkDelivered records that this device received the file (P2P or download ack).
func (h *FileHandler) MarkDelivered(c *fiber.Ctx) error {
	userID, deviceID, err := extractIdentity(c)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "missing auth context")
	}
	fileID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid file id")
	}
	if err := h.svc.MarkDelivered(c.Context(), userID, deviceID, fileID); err != nil {
		return mapFileError(err)
	}
	return c.SendStatus(fiber.StatusNoContent)
}

// ── error mapping ─────────────────────────────────────────────────────────────

func mapFileError(err error) *fiber.Error {
	switch {
	case errors.Is(err, service.ErrFileNotFound):
		return fiber.NewError(fiber.StatusNotFound, "file not found")
	case errors.Is(err, service.ErrUnsupportedMIME):
		return fiber.NewError(fiber.StatusBadRequest, err.Error())
	case errors.Is(err, service.ErrFileTooLarge):
		return fiber.NewError(fiber.StatusRequestEntityTooLarge, err.Error())
	case errors.Is(err, service.ErrChunkOutOfRange):
		return fiber.NewError(fiber.StatusBadRequest, err.Error())
	case errors.Is(err, service.ErrChunkHashMismatch):
		return fiber.NewError(fiber.StatusUnprocessableEntity, err.Error())
	case errors.Is(err, service.ErrChunkAlreadyExists):
		return fiber.NewError(fiber.StatusConflict, err.Error())
	case errors.Is(err, service.ErrNotAllChunks):
		return fiber.NewError(fiber.StatusConflict, err.Error())
	case errors.Is(err, service.ErrFileHashMismatch):
		return fiber.NewError(fiber.StatusUnprocessableEntity, err.Error())
	case errors.Is(err, service.ErrAutoCloudBlocked):
		return fiber.NewError(fiber.StatusUnprocessableEntity, err.Error())
	case errors.Is(err, service.ErrStorageQuotaExceeded):
		return fiber.NewError(fiber.StatusInsufficientStorage, err.Error())
	default:
		return fiber.NewError(fiber.StatusInternalServerError, "internal error")
	}
}
