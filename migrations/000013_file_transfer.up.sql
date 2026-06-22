-- Phase 7: extend the existing files table with fields needed for chunked
-- resumable uploads, compression, thumbnails, and transfer-mode tracking.
--
-- The files and file_chunks tables were created in migrations 000007/000008.
-- This migration uses ALTER TABLE so the prior schema is preserved.

-- ── files table additions ─────────────────────────────────────────────────────

ALTER TABLE files
    ADD COLUMN chunk_size      INTEGER  NOT NULL DEFAULT 4194304,  -- 4 MiB
    ADD COLUMN chunks_received INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN stored_size     BIGINT,             -- post-compression stored bytes
    ADD COLUMN thumbnail_key   TEXT,               -- storage key for the thumbnail
    ADD COLUMN compressed      BOOLEAN  NOT NULL DEFAULT FALSE,
    ADD COLUMN transfer_mode   TEXT     NOT NULL DEFAULT 'relay',  -- 'relay' | 'webrtc'
    ADD COLUMN original_name_nonce BYTEA;          -- GCM nonce for filename decryption

-- Widen the status constraint to include 'processing' and 'ready'.
-- Phase 7 lifecycle: pending → uploading → processing → ready | failed
ALTER TABLE files
    DROP CONSTRAINT IF EXISTS files_status_check;

ALTER TABLE files
    ADD CONSTRAINT files_status_check
        CHECK (status IN ('pending', 'uploading', 'processing', 'complete', 'ready', 'failed'));

ALTER TABLE files
    ADD CONSTRAINT files_transfer_mode_check
        CHECK (transfer_mode IN ('relay', 'webrtc'));

-- ── indexes ───────────────────────────────────────────────────────────────────

-- Used when listing a user's files (newest first).
CREATE INDEX idx_files_user_created
    ON files (user_id, created_at DESC);

-- Used for admin/cleanup queries.
CREATE INDEX idx_files_status_created
    ON files (status, created_at DESC);

-- Used to find missing chunks during resume.
CREATE INDEX idx_file_chunks_pending
    ON file_chunks (file_id, chunk_index)
    WHERE uploaded_at IS NULL;
