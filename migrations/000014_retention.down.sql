DROP TABLE IF EXISTS user_settings;

DROP INDEX IF EXISTS idx_files_expiry;
ALTER TABLE files
    ALTER COLUMN expires_at DROP DEFAULT,
    DROP COLUMN IF EXISTS pinned_at,
    DROP COLUMN IF EXISTS is_pinned;

DROP INDEX IF EXISTS idx_clipboard_expiry;
ALTER TABLE clipboard_entries
    ALTER COLUMN expires_at DROP DEFAULT,
    DROP CONSTRAINT IF EXISTS clipboard_content_type_check,
    ADD CONSTRAINT clipboard_content_type_check
        CHECK (content_type IN ('text', 'image', 'url', 'file_ref', 'html', 'rtf')),
    DROP COLUMN IF EXISTS pinned_at;
