-- Per-user data encryption keys for clipboard content.
--
-- Architecture (Phase 5 — server-assisted encryption):
--   Each user gets exactly one AES-256-GCM data key (DEK).
--   The DEK is wrapped (encrypted) with the server's Key Encryption Key (KEK)
--   before storage so the raw key never appears in plaintext in the DB.
--   Stored format in key_enc: nonce (12 bytes) || GCM-ciphertext (48 bytes = 32 + 16 tag)
--
-- Phase 7 upgrade path:
--   Replace server-side key wrap with client-side X25519 ECDH key exchange.
--   At that point key_enc will store the DEK encrypted with each device's public key.
--   The UNIQUE constraint on user_id will be relaxed to allow per-device key envelopes.
CREATE TABLE user_keys (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_enc     BYTEA        NOT NULL,  -- wrapped DEK (nonce || ciphertext)
    algorithm   TEXT         NOT NULL DEFAULT 'aes-256-gcm',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- One active key per user for Phase 5.  Remove in Phase 7 for key rotation.
    CONSTRAINT user_keys_one_per_user UNIQUE (user_id)
);

CREATE INDEX idx_user_keys_user_id ON user_keys (user_id);
