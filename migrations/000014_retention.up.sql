-- Phase 8: Data Retention Policy
--
-- Rules:
--   • All new items expire after the user's chosen retention window (default 2 h).
--   • Pinned items: expires_at = NULL (never auto-deleted).
--   • Cleanup job runs every 10 minutes:
--       DELETE WHERE NOT pinned AND expires_at < NOW()
--
-- Changes:
--   1. clipboard_entries — add pinned_at, fix content_type constraint,
--      set 2-hour default on expires_at.
--   2. files — add is_pinned, pinned_at, set 2-hour default on expires_at.
--   3. user_settings — per-user retention preference.

-- ── 1. clipboard_entries ──────────────────────────────────────────────────────

-- Track when an item was pinned.
ALTER TABLE clipboard_entries
    ADD COLUMN pinned_at TIMESTAMPTZ;

-- Set 2-hour default for new rows (existing rows keep NULL = never purged).
ALTER TABLE clipboard_entries
    ALTER COLUMN expires_at SET DEFAULT now() + INTERVAL '2 hours';

-- Fix the content_type constraint to match the Phase 5 MIME-type values.
ALTER TABLE clipboard_entries
    DROP CONSTRAINT IF EXISTS clipboard_content_type_check;

ALTER TABLE clipboard_entries
    ADD CONSTRAINT clipboard_content_type_check
        CHECK (content_type IN (
            'text/plain', 'text/uri-list', 'text/html', 'text/rtf',
            -- legacy short names (kept for backwards-compat)
            'text', 'image', 'url', 'file_ref', 'html', 'rtf'
        ));

-- Index: fast lookup for the cleanup job.
CREATE INDEX IF NOT EXISTS idx_clipboard_expiry
    ON clipboard_entries (expires_at)
    WHERE pinned = false AND expires_at IS NOT NULL;

-- ── 2. files ─────────────────────────────────────────────────────────────────

ALTER TABLE files
    ADD COLUMN IF NOT EXISTS is_pinned  BOOLEAN   NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS pinned_at  TIMESTAMPTZ;

-- Set 2-hour default for new rows.
ALTER TABLE files
    ALTER COLUMN expires_at SET DEFAULT now() + INTERVAL '2 hours';

-- Index for cleanup job.
CREATE INDEX IF NOT EXISTS idx_files_expiry
    ON files (expires_at)
    WHERE is_pinned = false AND expires_at IS NOT NULL;

-- ── 3. user_settings ─────────────────────────────────────────────────────────

-- Stores per-user preferences (one row per user, upserted on change).
CREATE TABLE user_settings (
    user_id             UUID        PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    -- Retention window in minutes.  Valid: 30 | 60 | 120 | 360 | 1440.
    retention_minutes   INTEGER     NOT NULL DEFAULT 120,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT user_settings_retention_check
        CHECK (retention_minutes IN (30, 60, 120, 360, 1440))
);

COMMENT ON COLUMN user_settings.retention_minutes IS
    '30=30 min, 60=1 h, 120=2 h (default), 360=6 h, 1440=24 h';
