-- pgcrypto provides gen_random_uuid() on PostgreSQL < 13.
-- On PostgreSQL 16 (our target) it is a no-op that keeps the migration
-- portable to older environments.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
