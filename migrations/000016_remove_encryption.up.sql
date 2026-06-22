-- Phase B: remove server-side encryption (plaintext at rest).
-- Existing encrypted rows cannot be decrypted without KEK; clear them.

DELETE FROM file_chunks;
DELETE FROM files;
DELETE FROM clipboard_entries;
DROP TABLE IF EXISTS user_keys;

ALTER TABLE clipboard_entries
    ADD COLUMN IF NOT EXISTS content TEXT NOT NULL DEFAULT '';

ALTER TABLE clipboard_entries
    DROP COLUMN IF EXISTS ciphertext,
    DROP COLUMN IF EXISTS nonce;

ALTER TABLE clipboard_entries
    ALTER COLUMN content DROP DEFAULT;

ALTER TABLE clipboard_entries
    RENAME COLUMN ciphertext_hash TO content_hash;

ALTER TABLE clipboard_entries
    DROP CONSTRAINT IF EXISTS clipboard_nonce_length;

ALTER TABLE files
    DROP COLUMN IF EXISTS original_name_nonce;

-- original_name was TEXT since 000007; only convert if a fork used BYTEA
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'files'
          AND column_name = 'original_name'
          AND udt_name = 'bytea'
    ) THEN
        ALTER TABLE files
            ALTER COLUMN original_name TYPE TEXT
            USING COALESCE(convert_from(original_name, 'UTF8'), '');
    END IF;
END $$;
