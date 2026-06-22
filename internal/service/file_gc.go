package service

import (
	"context"

	"github.com/syncbridge/api/internal/repository"
	"github.com/syncbridge/api/internal/storage"
)

// fileObjectDeleter removes assembled file objects from storage.
type fileObjectDeleter struct {
	store storage.Backend
}

func newFileObjectDeleter(store storage.Backend) *fileObjectDeleter {
	return &fileObjectDeleter{store: store}
}

func (d *fileObjectDeleter) DeleteFileObjects(ctx context.Context, f *repository.File) error {
	if d.store == nil || f == nil {
		return nil
	}
	_ = d.store.Delete(ctx, storage.DataKey(f.ObjectKeyPrefix))
	if f.ThumbnailKey != nil {
		_ = d.store.Delete(ctx, *f.ThumbnailKey)
	}
	return nil
}
