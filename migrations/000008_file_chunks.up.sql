CREATE TABLE file_chunks (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id      UUID         NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    chunk_index  INTEGER      NOT NULL,    -- 0-based ordering
    chunk_hash   TEXT         NOT NULL,    -- SHA-256(encrypted chunk)
    object_key   TEXT         NOT NULL,    -- full object store path
    size         INTEGER      NOT NULL,    -- chunk byte count
    uploaded_at  TIMESTAMPTZ,              -- NULL = not yet uploaded

    CONSTRAINT file_chunks_unique_index UNIQUE (file_id, chunk_index),
    CONSTRAINT file_chunks_positive_index CHECK (chunk_index >= 0),
    CONSTRAINT file_chunks_positive_size  CHECK (size > 0)
);
