package database

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/rs/zerolog/log"
)

// schemaVersion tracks a single applied migration.
type schemaVersion struct {
	Version   string
	AppliedAt time.Time
	Checksum  string
}

const createTrackingTableSQL = `
CREATE TABLE IF NOT EXISTS schema_migrations (
    version    TEXT        PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    checksum   TEXT        NOT NULL
);`

// RunMigrations applies all pending *.up.sql files in migrations_path in
// lexicographic order. Each migration executes inside its own transaction.
// Already-applied migrations are skipped via the schema_migrations table.
func RunMigrations(ctx context.Context, db *DB, migrationsPath string) error {
	if err := ensureTrackingTable(ctx, db); err != nil {
		return err
	}

	files, err := discoverUpFiles(migrationsPath)
	if err != nil {
		return err
	}

	applied := 0
	for _, name := range files {
		version := strings.TrimSuffix(name, ".up.sql")

		exists, err := isMigrationApplied(ctx, db, version)
		if err != nil {
			return fmt.Errorf("check migration %q: %w", version, err)
		}
		if exists {
			continue
		}

		content, err := os.ReadFile(filepath.Join(migrationsPath, name))
		if err != nil {
			return fmt.Errorf("read migration %q: %w", name, err)
		}

		if err := applyMigration(ctx, db, version, content); err != nil {
			return err
		}
		applied++
	}

	if applied == 0 {
		log.Info().Msg("migrations: schema is up to date")
	} else {
		log.Info().Int("applied", applied).Msg("migrations complete")
	}
	return nil
}

// RollbackMigrations rolls back the most recently applied `steps` migrations.
func RollbackMigrations(ctx context.Context, db *DB, migrationsPath string, steps int) error {
	if err := ensureTrackingTable(ctx, db); err != nil {
		return err
	}

	rows, err := db.Pool.Query(ctx,
		`SELECT version FROM schema_migrations ORDER BY applied_at DESC LIMIT $1`, steps)
	if err != nil {
		return fmt.Errorf("query applied migrations: %w", err)
	}
	defer rows.Close()

	var versions []string
	for rows.Next() {
		var v string
		if err := rows.Scan(&v); err != nil {
			return err
		}
		versions = append(versions, v)
	}
	if err := rows.Err(); err != nil {
		return err
	}

	for _, version := range versions {
		downFile := filepath.Join(migrationsPath, version+".down.sql")
		content, err := os.ReadFile(downFile)
		if err != nil {
			return fmt.Errorf("read down migration %q: %w", version, err)
		}

		tx, err := db.Pool.Begin(ctx)
		if err != nil {
			return fmt.Errorf("begin transaction: %w", err)
		}

		if _, err := tx.Exec(ctx, string(content)); err != nil {
			_ = tx.Rollback(ctx)
			return fmt.Errorf("execute down migration %q: %w", version, err)
		}

		if _, err := tx.Exec(ctx,
			`DELETE FROM schema_migrations WHERE version = $1`, version); err != nil {
			_ = tx.Rollback(ctx)
			return fmt.Errorf("delete migration record %q: %w", version, err)
		}

		if err := tx.Commit(ctx); err != nil {
			return fmt.Errorf("commit rollback %q: %w", version, err)
		}
		log.Info().Str("migration", version).Msg("rolled back migration")
	}
	return nil
}

// MigrationStatus logs which migrations have been applied and which are pending.
func MigrationStatus(ctx context.Context, db *DB, migrationsPath string) error {
	if err := ensureTrackingTable(ctx, db); err != nil {
		return err
	}

	files, err := discoverUpFiles(migrationsPath)
	if err != nil {
		return err
	}

	rows, err := db.Pool.Query(ctx,
		`SELECT version, applied_at FROM schema_migrations ORDER BY applied_at`)
	if err != nil {
		return fmt.Errorf("query schema_migrations: %w", err)
	}
	defer rows.Close()

	applied := map[string]time.Time{}
	for rows.Next() {
		var sv schemaVersion
		if err := rows.Scan(&sv.Version, &sv.AppliedAt); err != nil {
			return err
		}
		applied[sv.Version] = sv.AppliedAt
	}
	if err := rows.Err(); err != nil {
		return err
	}

	for _, f := range files {
		version := strings.TrimSuffix(f, ".up.sql")
		if t, ok := applied[version]; ok {
			log.Info().
				Str("version", version).
				Str("applied_at", t.Format(time.RFC3339)).
				Str("state", "applied").
				Msg("migration")
		} else {
			log.Info().
				Str("version", version).
				Str("state", "pending").
				Msg("migration")
		}
	}
	return nil
}

// ── private helpers ───────────────────────────────────────────────────────────

func ensureTrackingTable(ctx context.Context, db *DB) error {
	if _, err := db.Pool.Exec(ctx, createTrackingTableSQL); err != nil {
		return fmt.Errorf("create schema_migrations table: %w", err)
	}
	return nil
}

func discoverUpFiles(migrationsPath string) ([]string, error) {
	entries, err := os.ReadDir(migrationsPath)
	if err != nil {
		return nil, fmt.Errorf("read migrations directory %q: %w", migrationsPath, err)
	}
	var files []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".up.sql") {
			files = append(files, e.Name())
		}
	}
	sort.Strings(files)
	return files, nil
}

func isMigrationApplied(ctx context.Context, db *DB, version string) (bool, error) {
	var exists bool
	err := db.Pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version = $1)`, version,
	).Scan(&exists)
	return exists, err
}

func applyMigration(ctx context.Context, db *DB, version string, content []byte) error {
	checksum := sha256hex(content)

	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin transaction for %q: %w", version, err)
	}

	if _, err := tx.Exec(ctx, string(content)); err != nil {
		_ = tx.Rollback(ctx)
		return fmt.Errorf("execute migration %q: %w", version, err)
	}

	if _, err := tx.Exec(ctx,
		`INSERT INTO schema_migrations (version, checksum) VALUES ($1, $2)`,
		version, checksum,
	); err != nil {
		_ = tx.Rollback(ctx)
		return fmt.Errorf("record migration %q: %w", version, err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit migration %q: %w", version, err)
	}

	log.Info().Str("migration", version).Msg("applied migration")
	return nil
}

func sha256hex(b []byte) string {
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}
