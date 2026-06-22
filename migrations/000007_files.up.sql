CREATE TABLE files (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sender_device_id  UUID         NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    original_name     TEXT         NOT NULL,    -- encrypted filename (AES-GCM)
    mime_type         TEXT,
    total_size        BIGINT       NOT NULL,    -- plaintext byte count
    chunk_count       INTEGER      NOT NULL,
    file_hash         TEXT         NOT NULL,    -- SHA-256 of plaintext for integrity
    object_key_prefix TEXT         NOT NULL,    -- S3 / local FS key prefix
    status            TEXT         NOT NULL DEFAULT 'pending',
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at        TIMESTAMPTZ,

    CONSTRAINT files_status_check
        CHECK (status IN ('pending', 'uploading', 'complete', 'failed')),
    CONSTRAINT files_positive_size
        CHECK (total_size > 0),
    CONSTRAINT files_positive_chunks
        CHECK (chunk_count > 0)
);
