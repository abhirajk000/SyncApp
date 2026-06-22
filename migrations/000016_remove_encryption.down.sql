-- Best-effort rollback (data loss on up migration is not recoverable).

ALTER TABLE files
    ALTER COLUMN original_name TYPE BYTEA USING original_name::bytea;

ALTER TABLE files
    ADD COLUMN IF NOT EXISTS original_name_nonce BYTEA;

ALTER TABLE clipboard_entries
    RENAME COLUMN content_hash TO ciphertext_hash;

ALTER TABLE clipboard_entries
    ADD COLUMN IF NOT EXISTS ciphertext BYTEA NOT NULL DEFAULT '\x'::bytea,
    ADD COLUMN IF NOT EXISTS nonce BYTEA NOT NULL DEFAULT '\x000000000000000000000000'::bytea;

ALTER TABLE clipboard_entries
    DROP COLUMN IF EXISTS content;

CREATE TABLE IF NOT EXISTS user_keys (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    key_enc    BYTEA NOT NULL,
    algorithm  TEXT NOT NULL DEFAULT 'aes-256-gcm',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
