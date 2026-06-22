-- Append-only immutable audit trail for security-sensitive events.
-- Rows are never updated or deleted in normal operation.
-- user_id / device_id use SET NULL on cascade so the audit row survives
-- even if the originating entity is purged.
CREATE TABLE audit_logs (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID         REFERENCES users(id)   ON DELETE SET NULL,
    device_id   UUID         REFERENCES devices(id) ON DELETE SET NULL,
    event_type  TEXT         NOT NULL,
    event_data  JSONB        NOT NULL DEFAULT '{}',
    ip_address  INET,
    user_agent  TEXT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT audit_event_type_not_empty CHECK (event_type <> '')
);

-- Time-range queries (most common: "all events for user X in last 7 days").
CREATE INDEX idx_audit_user_created   ON audit_logs (user_id,   created_at DESC);
CREATE INDEX idx_audit_device_created ON audit_logs (device_id, created_at DESC);
CREATE INDEX idx_audit_event_type     ON audit_logs (event_type, created_at DESC);
