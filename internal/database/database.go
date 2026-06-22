package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog/log"
	"github.com/syncbridge/api/internal/config"
)

// DB wraps a pgxpool.Pool and exposes health-check helpers.
// All repositories receive the embedded Pool directly.
type DB struct {
	Pool *pgxpool.Pool
}

// Connect creates and validates a pgxpool connection using the supplied config.
// Returns an error if the pool cannot be created or the database is unreachable.
func Connect(ctx context.Context, cfg *config.Config) (*DB, error) {
	poolCfg, err := pgxpool.ParseConfig(cfg.DatabaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse database URL: %w", err)
	}

	poolCfg.MaxConns = int32(cfg.DBMaxConns)
	poolCfg.MinConns = int32(cfg.DBMinConns)
	poolCfg.MaxConnLifetime = cfg.DBConnMaxLifetime
	poolCfg.MaxConnIdleTime = cfg.DBConnMaxIdleTime
	poolCfg.HealthCheckPeriod = cfg.DBHealthCheckPeriod

	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("create connection pool: %w", err)
	}

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	if err := pool.Ping(pingCtx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping database: %w", err)
	}

	stat := pool.Stat()
	log.Info().
		Int32("max_conns", stat.MaxConns()).
		Int32("min_conns", poolCfg.MinConns).
		Msg("database connected")

	return &DB{Pool: pool}, nil
}

// Close gracefully drains and closes all connections in the pool.
func (db *DB) Close() {
	db.Pool.Close()
	log.Info().Msg("database connection pool closed")
}

// Ping checks database reachability within a 3-second timeout.
// Used by the /ready health endpoint.
func (db *DB) Ping(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	return db.Pool.Ping(ctx)
}

// Stats returns a snapshot of pool connection counts.
func (db *DB) Stats() *pgxpool.Stat {
	return db.Pool.Stat()
}
