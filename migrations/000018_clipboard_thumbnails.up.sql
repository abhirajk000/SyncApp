ALTER TABLE clipboard_entries
    ADD COLUMN IF NOT EXISTS thumbnail_key TEXT;
