-- ── clipboard_entries ──────────────────────────────────────────────────────────
-- Paginated history fetch (most common query pattern).
CREATE INDEX idx_clipboard_user_created
    ON clipboard_entries (user_id, created_at DESC);

-- Insert-time deduplication guard.
CREATE INDEX idx_clipboard_dedup
    ON clipboard_entries (user_id, ciphertext_hash);

-- Per-device history view.
CREATE INDEX idx_clipboard_device
    ON clipboard_entries (source_device_id, created_at DESC);

-- Delta sync by vector clock (JSONB GIN for partial containment queries).
CREATE INDEX idx_clipboard_vector_clock
    ON clipboard_entries USING GIN (vector_clock);

-- Selective index for TTL purge job — only rows with an expiry set.
CREATE INDEX idx_clipboard_expires
    ON clipboard_entries (expires_at)
    WHERE expires_at IS NOT NULL;

-- ── devices ────────────────────────────────────────────────────────────────────
-- Active device lookup (revoked_at IS NULL is the hot path).
CREATE INDEX idx_devices_user_active
    ON devices (user_id, revoked_at);

-- ── sessions ───────────────────────────────────────────────────────────────────
-- O(1) JWT revocation check — unique because token hashes must not repeat.
CREATE UNIQUE INDEX idx_sessions_token
    ON sessions (token_hash);

-- Per-device session listing.
CREATE INDEX idx_sessions_device
    ON sessions (device_id, expires_at);

-- TTL sweep for expired, non-revoked sessions.
CREATE INDEX idx_sessions_expires
    ON sessions (expires_at)
    WHERE revoked_at IS NULL;

-- ── files ──────────────────────────────────────────────────────────────────────
CREATE INDEX idx_files_user_status
    ON files (user_id, status, created_at DESC);

CREATE INDEX idx_files_expires
    ON files (expires_at)
    WHERE expires_at IS NOT NULL;

-- ── file_chunks ────────────────────────────────────────────────────────────────
-- Ordered chunk assembly during download.
CREATE INDEX idx_file_chunks_file
    ON file_chunks (file_id, chunk_index);

-- ── pairing_requests ───────────────────────────────────────────────────────────
CREATE INDEX idx_pairing_otp
    ON pairing_requests (otp, status, expires_at);

-- TTL sweep for expired pending requests.
CREATE INDEX idx_pairing_expires
    ON pairing_requests (expires_at)
    WHERE status = 'pending';
