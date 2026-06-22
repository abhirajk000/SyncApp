CREATE TABLE sessions (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id        UUID         NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    token_hash       TEXT         NOT NULL,    -- SHA-256(JWT) for O(1) revocation
    ws_connection_id TEXT,                     -- active WebSocket connection id
    ip_address       INET,
    issued_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at       TIMESTAMPTZ  NOT NULL,
    revoked_at       TIMESTAMPTZ,

    CONSTRAINT sessions_expiry_after_issue CHECK (expires_at > issued_at)
);
