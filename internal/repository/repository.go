// Package repository defines the data access layer for SyncBridge.
//
// Every concrete repository embeds Base, which holds the *pgxpool.Pool.
// Callers receive typed domain errors (ErrNotFound, ErrDuplicate, etc.)
// rather than raw pgx or PostgreSQL error codes.
//
// Pattern used throughout this package:
//
//	type FooRepository struct { Base }
//
//	func (r *FooRepository) FindByID(ctx context.Context, id uuid.UUID) (*Foo, error) {
//	    var f Foo
//	    err := r.pool.QueryRow(ctx, `SELECT … FROM foo WHERE id = $1`, id).Scan(&f.ID, …)
//	    return &f, mapError(err)
//	}
package repository

import (
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ── sentinel errors ───────────────────────────────────────────────────────────

var (
	// ErrNotFound is returned when a SELECT finds no matching row.
	ErrNotFound = errors.New("record not found")

	// ErrDuplicate is returned on a unique-constraint violation (PG 23505).
	ErrDuplicate = errors.New("duplicate record")

	// ErrConstraint is returned on FK or check-constraint violations
	// (PG 23503, 23514).
	ErrConstraint = errors.New("constraint violation")

	// ErrInvalidInput is returned when a caller provides a value outside the
	// accepted enumeration (e.g. an unsupported retention_minutes value).
	ErrInvalidInput = errors.New("invalid input value")
)

// ── Base ──────────────────────────────────────────────────────────────────────

// Base is embedded by every concrete repository. It exposes the pool
// only to sub-types — callers interact with the concrete repository API.
type Base struct {
	pool *pgxpool.Pool
}

// NewBase constructs a Base from a shared connection pool.
func NewBase(pool *pgxpool.Pool) Base {
	return Base{pool: pool}
}

// ── error mapping ─────────────────────────────────────────────────────────────

// mapError translates pgx and PostgreSQL errors into repository sentinel
// errors. Unknown errors are returned unchanged.
func mapError(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		switch pgErr.Code {
		case "23505": // unique_violation
			return fmt.Errorf("%w: %s", ErrDuplicate, pgErr.Detail)
		case "23503": // foreign_key_violation
			return fmt.Errorf("%w: %s", ErrConstraint, pgErr.Detail)
		case "23514": // check_violation
			return fmt.Errorf("%w: %s", ErrConstraint, pgErr.Detail)
		}
	}
	return err
}
