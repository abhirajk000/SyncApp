CREATE TABLE devices (
    id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name                TEXT         NOT NULL,
    platform            TEXT         NOT NULL,
    public_key          BYTEA        NOT NULL,    -- X25519 public key (32 bytes)
    device_fingerprint  TEXT         NOT NULL,    -- SHA-256(public_key) as hex
    push_token          TEXT,                     -- APNs / FCM; nullable
    last_seen_at        TIMESTAMPTZ,
    trusted             BOOLEAN      NOT NULL DEFAULT false,
    revoked_at          TIMESTAMPTZ,              -- NULL = active
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT devices_platform_check
        CHECK (platform IN ('macos', 'android', 'ios', 'web')),
    CONSTRAINT devices_public_key_length
        CHECK (octet_length(public_key) = 32)
);
