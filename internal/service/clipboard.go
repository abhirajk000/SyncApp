package service

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"github.com/syncbridge/api/internal/dto"
	"github.com/syncbridge/api/internal/repository"
	"github.com/syncbridge/api/internal/storage"
	"github.com/syncbridge/api/internal/thumbnail"
	"github.com/syncbridge/api/internal/ws"
)

var (
	ErrUnsupportedContentType = errors.New("unsupported content type")
	ErrContentTooLarge        = errors.New("content exceeds maximum allowed size")
	ErrClipboardNotFound      = errors.New("clipboard entry not found")
	ErrStorageQuotaExceeded   = errors.New("unpinned storage quota exceeded")
)

type clipboardStore interface {
	Create(ctx context.Context, e *repository.ClipboardEntry) error
	FindByID(ctx context.Context, id, userID uuid.UUID) (*repository.ClipboardEntry, error)
	FindByContentHash(ctx context.Context, userID uuid.UUID, hash string) (*repository.ClipboardEntry, error)
	FindLatestByUser(ctx context.Context, userID uuid.UUID, limit int) ([]*repository.ClipboardEntry, error)
	FindByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*repository.ClipboardEntry, int, error)
	DeleteByID(ctx context.Context, id, userID uuid.UUID) error
	SetPinned(ctx context.Context, id, userID uuid.UUID, pinned bool, retentionMinutes int) error
	SetThumbnailKey(ctx context.Context, id, userID uuid.UUID, key string) error
	SumUnpinnedBytes(ctx context.Context, userID uuid.UUID) (int64, error)
	FindOldestUnpinned(ctx context.Context, userID uuid.UUID) (*repository.ClipboardEntry, error)
	HardDelete(ctx context.Context, id, userID uuid.UUID) error
}

type userSettingsStore interface {
	Get(ctx context.Context, userID uuid.UUID) (*repository.UserSettings, error)
}

type hubBroadcaster interface {
	Broadcast(userID uuid.UUID, data []byte, excludeDevice *uuid.UUID)
}

// ClipboardService implements clipboard synchronisation (plaintext at rest).
type ClipboardService struct {
	entries                 clipboardStore
	settings                userSettingsStore
	hub                     hubBroadcaster
	store                   storage.Backend
	thumb                   *thumbnail.Generator
	maxContentSize          int
	defaultRetentionMinutes int
	maxUnpinnedBytes        int64
}

func NewClipboardService(
	entries clipboardStore,
	settings userSettingsStore,
	hub hubBroadcaster,
	store storage.Backend,
	thumb *thumbnail.Generator,
	maxContentSizeMB int,
	defaultRetentionMinutes int,
	maxUnpinnedBytes int64,
) *ClipboardService {
	return &ClipboardService{
		entries:                 entries,
		settings:                settings,
		hub:                     hub,
		store:                   store,
		thumb:                   thumb,
		maxContentSize:          maxContentSizeMB * 1024 * 1024,
		defaultRetentionMinutes: defaultRetentionMinutes,
		maxUnpinnedBytes:        maxUnpinnedBytes,
	}
}

func (s *ClipboardService) Sync(
	ctx context.Context,
	userID, sourceDeviceID uuid.UUID,
	contentType, content string,
) (*dto.ClipboardEntryResponse, bool, error) {
	if !dto.SupportedContentTypes[contentType] {
		return nil, false, ErrUnsupportedContentType
	}

	contentBytes := []byte(content)
	if len(contentBytes) > s.maxContentSize {
		return nil, false, ErrContentTooLarge
	}

	hash := contentHash(contentType, contentBytes)
	existing, err := s.entries.FindByContentHash(ctx, userID, hash)
	if err != nil && !errors.Is(err, repository.ErrNotFound) {
		return nil, false, fmt.Errorf("dedup check: %w", err)
	}
	if existing != nil {
		return toEntryResponse(existing, existing.Content, true), true, nil
	}

	if err := s.enforceQuota(ctx, userID, int64(len(contentBytes))); err != nil {
		return nil, false, err
	}

	retentionMins := s.defaultRetentionMinutes
	if s.settings != nil {
		if us, err := s.settings.Get(ctx, userID); err == nil {
			retentionMins = us.RetentionMinutes
		}
	}
	expiresAt := time.Now().Add(time.Duration(retentionMins) * time.Minute)

	isImage := dto.IsImageContentType(contentType)

	entry := &repository.ClipboardEntry{
		ID:             uuid.New(),
		UserID:         userID,
		SourceDeviceID: sourceDeviceID,
		ContentType:    contentType,
		Content:        content,
		ContentHash:    hash,
		PlaintextSize:  len(contentBytes),
		VectorClock:    repository.VectorClock{sourceDeviceID.String(): time.Now().UnixNano()},
		Pinned:         false,
		ExpiresAt:      &expiresAt,
	}

	if err := s.entries.Create(ctx, entry); err != nil {
		return nil, false, fmt.Errorf("create entry: %w", err)
	}

	pushContent := content
	if isImage {
		pushContent = ""
	}
	go s.pushToDevices(userID, sourceDeviceID, entry, pushContent, isImage)

	if isImage {
		contentCopy := append([]byte(nil), contentBytes...)
		go s.generateThumbnailAsync(entry.ID, userID, contentType, contentCopy)
	}

	return toEntryResponse(entry, content, false), false, nil
}

func (s *ClipboardService) GetCurrent(ctx context.Context, userID uuid.UUID) (*dto.ClipboardEntryResponse, error) {
	candidates, err := s.entries.FindLatestByUser(ctx, userID, 10)
	if err != nil {
		return nil, fmt.Errorf("fetch candidates: %w", err)
	}
	if len(candidates) == 0 {
		return nil, ErrClipboardNotFound
	}
	winner := resolveConflict(candidates)
	return toEntryResponse(winner, winner.Content, false), nil
}

func (s *ClipboardService) GetHistory(ctx context.Context, userID uuid.UUID, limit, offset int) (*dto.ClipboardHistoryResponse, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	entries, total, err := s.entries.FindByUser(ctx, userID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("fetch history: %w", err)
	}
	responses := make([]dto.ClipboardEntryResponse, 0, len(entries))
	for _, e := range entries {
		responses = append(responses, *toHistoryEntryResponse(e))
	}
	return &dto.ClipboardHistoryResponse{
		Entries: responses,
		Total:   total,
		Limit:   limit,
		Offset:  offset,
		HasMore: offset+len(responses) < total,
	}, nil
}

func (s *ClipboardService) GetByID(ctx context.Context, userID, id uuid.UUID) (*dto.ClipboardEntryResponse, error) {
	e, err := s.entries.FindByID(ctx, id, userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrClipboardNotFound
		}
		return nil, fmt.Errorf("find entry: %w", err)
	}
	return toEntryResponse(e, e.Content, false), nil
}

func (s *ClipboardService) Delete(ctx context.Context, userID, id uuid.UUID) error {
	e, err := s.entries.FindByID(ctx, id, userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return ErrClipboardNotFound
		}
		return err
	}
	s.deleteThumbnail(ctx, e.ThumbnailKey)
	err = s.entries.DeleteByID(ctx, id, userID)
	if errors.Is(err, repository.ErrNotFound) {
		return ErrClipboardNotFound
	}
	return err
}

// DownloadThumbnail streams the stored JPEG preview for a clipboard image entry.
func (s *ClipboardService) DownloadThumbnail(
	ctx context.Context,
	userID, id uuid.UUID,
) (io.ReadCloser, int64, error) {
	e, err := s.entries.FindByID(ctx, id, userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, 0, ErrClipboardNotFound
		}
		return nil, 0, err
	}
	if e.ThumbnailKey == nil || s.store == nil {
		return nil, 0, ErrClipboardNotFound
	}
	rc, size, err := s.store.Get(ctx, *e.ThumbnailKey)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return nil, 0, ErrClipboardNotFound
		}
		return nil, 0, err
	}
	return rc, size, nil
}

func (s *ClipboardService) Pin(ctx context.Context, userID, id uuid.UUID, pinned bool) error {
	retentionMins := s.defaultRetentionMinutes
	if s.settings != nil {
		if us, err := s.settings.Get(ctx, userID); err == nil {
			retentionMins = us.RetentionMinutes
		}
	}
	if err := s.entries.SetPinned(ctx, id, userID, pinned, retentionMins); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return ErrClipboardNotFound
		}
		return err
	}
	if s.hub != nil {
		pinnedAt := ""
		if pinned {
			pinnedAt = time.Now().UTC().Format(time.RFC3339)
		}
		if data, err := ws.EncodeClipboardPin(id.String(), pinned, pinnedAt); err == nil {
			s.hub.Broadcast(userID, data, nil)
		}
	}
	return nil
}

func (s *ClipboardService) enforceQuota(ctx context.Context, userID uuid.UUID, incoming int64) error {
	return enforceCombinedQuota(ctx, userID, incoming, s.maxUnpinnedBytes, s.entries, nil, nil, s)
}

func contentHash(contentType string, content []byte) string {
	h := sha256.New()
	h.Write([]byte(contentType))
	h.Write([]byte{0x00})
	h.Write(content)
	return hex.EncodeToString(h.Sum(nil))
}

func resolveConflict(entries []*repository.ClipboardEntry) *repository.ClipboardEntry {
	winner := entries[0]
	for _, e := range entries[1:] {
		eMax := e.VectorClock.MaxTimestamp()
		wMax := winner.VectorClock.MaxTimestamp()
		if eMax > wMax || (eMax == wMax && e.CreatedAt.After(winner.CreatedAt)) {
			winner = e
		}
	}
	return winner
}

func (s *ClipboardService) pushToDevices(
	userID, sourceDeviceID uuid.UUID,
	entry *repository.ClipboardEntry,
	pushContent string,
	hasThumbnail bool,
) {
	if s.hub == nil {
		return
	}
	data, err := ws.EncodeClipboardNew(
		entry.ID.String(),
		entry.ContentType,
		pushContent,
		entry.SourceDeviceID.String(),
		entry.PlaintextSize,
		hasThumbnail,
		map[string]int64(entry.VectorClock),
		entry.CreatedAt,
	)
	if err != nil {
		log.Error().Err(err).Str("entry_id", entry.ID.String()).Msg("encode clipboard.new failed")
		return
	}
	s.hub.Broadcast(userID, data, &sourceDeviceID)
}

func (s *ClipboardService) generateThumbnailAsync(
	entryID, userID uuid.UUID,
	contentType string,
	content []byte,
) {
	ctx := context.Background()
	keyPtr := s.storeImageThumbnail(ctx, entryID, contentType, content)
	if keyPtr == nil {
		return
	}
	if err := s.entries.SetThumbnailKey(ctx, entryID, userID, *keyPtr); err != nil {
		log.Warn().Err(err).Str("entry_id", entryID.String()).Msg("update clipboard thumbnail key failed")
	}
}

func toEntryResponse(e *repository.ClipboardEntry, plain string, deduped bool) *dto.ClipboardEntryResponse {
	return &dto.ClipboardEntryResponse{
		ID:             e.ID.String(),
		ContentType:    e.ContentType,
		Content:        plain,
		HasThumbnail:   e.ThumbnailKey != nil && dto.IsImageContentType(e.ContentType),
		SourceDeviceID: e.SourceDeviceID.String(),
		PlaintextSize:  e.PlaintextSize,
		VectorClock:    map[string]int64(e.VectorClock),
		Pinned:         e.Pinned,
		PinnedAt:       e.PinnedAt,
		Deduplicated:   deduped,
		CreatedAt:      e.CreatedAt,
		ExpiresAt:      e.ExpiresAt,
	}
}

func toHistoryEntryResponse(e *repository.ClipboardEntry) *dto.ClipboardEntryResponse {
	resp := toEntryResponse(e, e.Content, false)
	if resp.HasThumbnail {
		resp.Content = ""
	}
	return resp
}

func (s *ClipboardService) storeImageThumbnail(
	ctx context.Context,
	entryID uuid.UUID,
	contentType string,
	content []byte,
) *string {
	if s.store == nil || s.thumb == nil || !dto.IsImageContentType(contentType) {
		return nil
	}
	raw, err := decodeClipboardImageBytes(content)
	if err != nil {
		return nil
	}
	thumbData, err := s.thumb.Generate(raw, contentType)
	if err != nil {
		return nil
	}
	key := storage.ClipboardThumbnailKey(entryID.String())
	if err := s.store.Put(ctx, key, bytes.NewReader(thumbData), int64(len(thumbData)), "image/jpeg"); err != nil {
		log.Warn().Err(err).Str("entry_id", entryID.String()).Msg("store clipboard thumbnail failed")
		return nil
	}
	return &key
}

func (s *ClipboardService) deleteThumbnail(ctx context.Context, key *string) {
	if s.store == nil || key == nil {
		return
	}
	_ = s.store.Delete(ctx, *key)
}

func (s *ClipboardService) DeleteClipboardObjects(ctx context.Context, e *repository.ClipboardEntry) error {
	s.deleteThumbnail(ctx, e.ThumbnailKey)
	return nil
}

func decodeClipboardImageBytes(content []byte) ([]byte, error) {
	s := string(content)
	if strings.HasPrefix(s, "data:") {
		if idx := strings.Index(s, ","); idx >= 0 {
			s = s[idx+1:]
		}
	}
	return base64.StdEncoding.DecodeString(s)
}
