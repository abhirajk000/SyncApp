-- local_peers stores each device's LAN IP addresses + port so the server can
-- detect when two devices are on the same subnet and hint them to connect directly.
--
-- Design notes:
--   • One row per device (UNIQUE device_id).  Devices UPSERT on every reconnect.
--   • expires_at is set to (now + LAN_ADVERTISE_TTL_MIN minutes).  Devices must
--     re-advertise periodically; expired rows are invisible and purged by cleanup.
--   • addrs is a JSON array of bare IPv4/IPv6 strings (no port), e.g.
--     ["192.168.1.5", "fe80::1"].
--   • port is the device's local WebRTC/direct-connection port (0 = unknown).
--
-- Phase 7 upgrade path:
--   Add per-device DTLS fingerprint column for certificate pinning.
--   Add subnet column (computed) for efficient same-network SQL queries.
CREATE TABLE local_peers (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID         NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
    device_id   UUID         NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    addrs       JSONB        NOT NULL DEFAULT '[]',
    port        INT          NOT NULL DEFAULT 0,
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at  TIMESTAMPTZ  NOT NULL,

    CONSTRAINT local_peers_device_unique UNIQUE (device_id)
);

CREATE INDEX idx_local_peers_user_id   ON local_peers (user_id);
CREATE INDEX idx_local_peers_expires   ON local_peers (expires_at);
