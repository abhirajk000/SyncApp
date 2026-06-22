package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// User is the domain model for a SyncBridge account.
// PasswordHash stores the Argon2id-encoded string (never the raw password).
type User struct {
	ID           uuid.UUID
	Email        string
	PasswordHash string
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// UserRepository handles all User persistence.
type UserRepository struct {
	Base
}

// NewUserRepository constructs a UserRepository backed by pool.
func NewUserRepository(pool *pgxpool.Pool) *UserRepository {
	return &UserRepository{Base: NewBase(pool)}
}

// Create inserts a new User row.  On duplicate email it returns ErrDuplicate.
func (r *UserRepository) Create(ctx context.Context, user *User) error {
	const q = `
		INSERT INTO users (id, email, password_hash, created_at, updated_at)
		VALUES ($1, $2, $3, now(), now())
		RETURNING created_at, updated_at`

	return mapError(
		r.pool.QueryRow(ctx, q, user.ID, user.Email, user.PasswordHash).
			Scan(&user.CreatedAt, &user.UpdatedAt),
	)
}

// FindByID returns the user with the given primary key, or ErrNotFound.
func (r *UserRepository) FindByID(ctx context.Context, id uuid.UUID) (*User, error) {
	const q = `
		SELECT id, email, password_hash, created_at, updated_at
		FROM   users
		WHERE  id = $1`

	var u User
	err := r.pool.QueryRow(ctx, q, id).Scan(
		(*[16]byte)(&u.ID),
		&u.Email,
		&u.PasswordHash,
		&u.CreatedAt,
		&u.UpdatedAt,
	)
	if err != nil {
		return nil, mapError(err)
	}
	return &u, nil
}

// FindByEmail returns the user with the given email address, or ErrNotFound.
func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	const q = `
		SELECT id, email, password_hash, created_at, updated_at
		FROM   users
		WHERE  email = $1`

	var u User
	err := r.pool.QueryRow(ctx, q, email).Scan(
		(*[16]byte)(&u.ID),
		&u.Email,
		&u.PasswordHash,
		&u.CreatedAt,
		&u.UpdatedAt,
	)
	if err != nil {
		return nil, mapError(err)
	}
	return &u, nil
}

// UpdatePassword replaces the password hash for user id.
func (r *UserRepository) UpdatePassword(ctx context.Context, id uuid.UUID, hash string) error {
	const q = `
		UPDATE users
		SET    password_hash = $1,
		       updated_at    = now()
		WHERE  id = $2`

	tag, err := r.pool.Exec(ctx, q, hash, id)
	if err != nil {
		return mapError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
