package service

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	"github.com/syncbridge/api/internal/storage"
)

// CleanupService purges expired unpinned content and deletes storage objects.
type CleanupService struct {
	pool     *pgxpool.Pool
	store    storage.Backend
	interval time.Duration
	logger   zerolog.Logger
}

func NewCleanupService(pool *pgxpool.Pool, store storage.Backend, interval time.Duration) *CleanupService {
	return &CleanupService{
		pool:     pool,
		store:    store,
		interval: interval,
		logger:   log.With().Str("service", "cleanup").Logger(),
	}
}

func (s *CleanupService) Start(ctx context.Context) {
	go func() {
		ticker := time.NewTicker(s.interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				s.logger.Info().Msg("cleanup job stopped")
				return
			case <-ticker.C:
				s.run(ctx)
			}
		}
	}()
	s.logger.Info().Dur("interval", s.interval).Msg("cleanup job started")
}

func (s *CleanupService) RunNow(ctx context.Context) (clipboard, files int64, err error) {
	clipboard, err = s.purgeClipboard(ctx)
	if err != nil {
		return
	}
	files, err = s.purgeFiles(ctx)
	if err != nil {
		return
	}
	_, _ = s.purgeOrphanChunks(ctx)
	return
}

func (s *CleanupService) run(ctx context.Context) {
	clipboard, err1 := s.purgeClipboard(ctx)
	files, err2 := s.purgeFiles(ctx)
	orphans, _ := s.purgeOrphanChunks(ctx)

	if err1 != nil {
		s.logger.Error().Err(err1).Msg("purge clipboard failed")
	}
	if err2 != nil {
		s.logger.Error().Err(err2).Msg("purge files failed")
	}
	if clipboard+files+orphans > 0 {
		s.logger.Info().
			Int64("clipboard_deleted", clipboard).
			Int64("files_deleted", files).
			Int64("orphan_chunks_deleted", orphans).
			Msg("retention cleanup complete")
	}
}

func (s *CleanupService) purgeClipboard(ctx context.Context) (int64, error) {
	const q = `
		DELETE FROM clipboard_entries
		WHERE  pinned    = false
		  AND  expires_at IS NOT NULL
		  AND  expires_at < now()
		RETURNING thumbnail_key`

	rows, err := s.pool.Query(ctx, q)
	if err != nil {
		return 0, err
	}
	defer rows.Close()

	var count int64
	for rows.Next() {
		var thumb *string
		if err := rows.Scan(&thumb); err != nil {
			continue
		}
		count++
		if thumb != nil {
			_ = s.store.Delete(ctx, *thumb)
		}
	}
	return count, rows.Err()
}

func (s *CleanupService) purgeFiles(ctx context.Context) (int64, error) {
	const q = `
		DELETE FROM files
		WHERE  is_pinned  = false
		  AND  expires_at IS NOT NULL
		  AND  expires_at < now()
		RETURNING object_key_prefix, thumbnail_key`

	rows, err := s.pool.Query(ctx, q)
	if err != nil {
		return 0, err
	}
	defer rows.Close()

	var count int64
	gc := newFileObjectDeleter(s.store)
	for rows.Next() {
		var prefix string
		var thumb *string
		if err := rows.Scan(&prefix, &thumb); err != nil {
			continue
		}
		count++
		f := &struct {
			ObjectKeyPrefix string
			ThumbnailKey    *string
		}{prefix, thumb}
		_ = s.store.Delete(ctx, storage.DataKey(f.ObjectKeyPrefix))
		if f.ThumbnailKey != nil {
			_ = s.store.Delete(ctx, *f.ThumbnailKey)
		}
		_ = gc
	}
	return count, rows.Err()
}

func (s *CleanupService) purgeOrphanChunks(ctx context.Context) (int64, error) {
	const q = `DELETE FROM file_chunks WHERE file_id NOT IN (SELECT id FROM files)`
	tag, err := s.pool.Exec(ctx, q)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}
