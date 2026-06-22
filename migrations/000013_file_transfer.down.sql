DROP INDEX IF EXISTS idx_file_chunks_pending;
DROP INDEX IF EXISTS idx_files_status_created;
DROP INDEX IF EXISTS idx_files_user_created;

ALTER TABLE files
    DROP CONSTRAINT IF EXISTS files_transfer_mode_check,
    DROP CONSTRAINT IF EXISTS files_status_check;

ALTER TABLE files
    ADD CONSTRAINT files_status_check
        CHECK (status IN ('pending', 'uploading', 'complete', 'failed'));

ALTER TABLE files
    DROP COLUMN IF EXISTS original_name_nonce,
    DROP COLUMN IF EXISTS transfer_mode,
    DROP COLUMN IF EXISTS compressed,
    DROP COLUMN IF EXISTS thumbnail_key,
    DROP COLUMN IF EXISTS stored_size,
    DROP COLUMN IF EXISTS chunks_received,
    DROP COLUMN IF EXISTS chunk_size;
