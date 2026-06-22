CREATE TABLE clipboard_entries (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source_device_id UUID         NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    content_type     TEXT         NOT NULL,
    ciphertext       BYTEA        NOT NULL,    -- AES-256-GCM encrypted payload
    nonce            BYTEA        NOT NULL,    -- 96-bit GCM nonce
    ciphertext_hash  TEXT         NOT NULL,    -- SHA-256(ciphertext) for dedup
    plaintext_size   INTEGER,                  -- original byte count (untrusted metadata)
    vector_clock     JSONB        NOT NULL DEFAULT '{}',
    pinned           BOOLEAN      NOT NULL DEFAULT false,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at       TIMESTAMPTZ,              -- NULL = never purged automatically

    CONSTRAINT clipboard_content_type_check
        CHECK (content_type IN ('text', 'image', 'url', 'file_ref', 'html', 'rtf')),
    CONSTRAINT clipboard_nonce_length
        CHECK (octet_length(nonce) = 12),
    CONSTRAINT clipboard_positive_size
        CHECK (plaintext_size IS NULL OR plaintext_size > 0)
);
