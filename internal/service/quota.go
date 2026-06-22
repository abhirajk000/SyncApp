package service

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/repository"
)

type quotaClipboardStore interface {
	SumUnpinnedBytes(ctx context.Context, userID uuid.UUID) (int64, error)
	FindOldestUnpinned(ctx context.Context, userID uuid.UUID) (*repository.ClipboardEntry, error)
	HardDelete(ctx context.Context, id, userID uuid.UUID) error
}

type quotaFileStore interface {
	SumUnpinnedBytes(ctx context.Context, userID uuid.UUID) (int64, error)
	FindOldestUnpinned(ctx context.Context, userID uuid.UUID) (*repository.File, error)
	HardDelete(ctx context.Context, id uuid.UUID) (*repository.File, error)
}

type storageDeleter interface {
	DeleteFileObjects(ctx context.Context, f *repository.File) error
}

type clipboardObjectDeleter interface {
	DeleteClipboardObjects(ctx context.Context, e *repository.ClipboardEntry) error
}

func enforceCombinedQuota(
	ctx context.Context,
	userID uuid.UUID,
	incoming int64,
	maxBytes int64,
	clip quotaClipboardStore,
	files quotaFileStore,
	fileGC storageDeleter,
	clipGC clipboardObjectDeleter,
) error {
	if maxBytes <= 0 {
		return nil
	}
	for {
		var used int64
		if clip != nil {
			u, err := clip.SumUnpinnedBytes(ctx, userID)
			if err != nil {
				return err
			}
			used += u
		}
		if files != nil {
			u, err := files.SumUnpinnedBytes(ctx, userID)
			if err != nil {
				return err
			}
			used += u
		}
		if used+incoming <= maxBytes {
			return nil
		}
		if err := evictOldestUnpinnedForUser(ctx, userID, clip, files, fileGC, clipGC); err != nil {
			return err
		}
	}
}

func evictOldestUnpinnedForUser(
	ctx context.Context,
	userID uuid.UUID,
	clip quotaClipboardStore,
	files quotaFileStore,
	fileGC storageDeleter,
	clipGC clipboardObjectDeleter,
) error {
	var clipEntry *repository.ClipboardEntry
	var fileEntry *repository.File

	if clip != nil {
		e, err := clip.FindOldestUnpinned(ctx, userID)
		if err != nil && !errors.Is(err, repository.ErrNotFound) {
			return err
		}
		clipEntry = e
	}
	if files != nil {
		f, err := files.FindOldestUnpinned(ctx, userID)
		if err != nil && !errors.Is(err, repository.ErrNotFound) {
			return err
		}
		fileEntry = f
	}
	if clipEntry == nil && fileEntry == nil {
		return ErrStorageQuotaExceeded
	}

	evictFile := fileEntry != nil && (clipEntry == nil || !fileEntry.CreatedAt.After(clipEntry.CreatedAt))
	if evictFile {
		deleted, err := files.HardDelete(ctx, fileEntry.ID)
		if err != nil {
			return err
		}
		if fileGC != nil {
			_ = fileGC.DeleteFileObjects(ctx, deleted)
		}
		return nil
	}
	if clipGC != nil {
		_ = clipGC.DeleteClipboardObjects(ctx, clipEntry)
	}
	return clip.HardDelete(ctx, clipEntry.ID, userID)
}
