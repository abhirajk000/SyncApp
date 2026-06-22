-- Phase A: PIN authentication + single-user mode
--
-- • One owner account (fixed UUID)
-- • Master PIN stored in global_settings
-- • Device trust window (trusted_until) for 7-day PIN-free access

-- ── Owner user (singleton) ────────────────────────────────────────────────────
INSERT INTO users (id, email, password_hash)
VALUES (
    '00000000-0000-4000-8000-000000000001',
    'owner@syncbridge.local',
    'pin-auth-not-used'
)
ON CONFLICT (id) DO NOTHING;

-- ── Global settings (single row) ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS global_settings (
    id             INT         PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    master_pin     TEXT        NOT NULL DEFAULT '070901',
    owner_user_id  UUID        NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO global_settings (id, master_pin, owner_user_id)
VALUES (1, '070901', '00000000-0000-4000-8000-000000000001')
ON CONFLICT (id) DO NOTHING;

-- ── Device trust window ───────────────────────────────────────────────────────
ALTER TABLE devices
    ADD COLUMN IF NOT EXISTS trusted_until TIMESTAMPTZ;

-- PIN-only devices do not require a public key.
ALTER TABLE devices
    ALTER COLUMN public_key DROP NOT NULL;

ALTER TABLE devices
    DROP CONSTRAINT IF EXISTS devices_public_key_length;

ALTER TABLE devices
    ADD CONSTRAINT devices_public_key_length
        CHECK (public_key IS NULL OR octet_length(public_key) = 32);

-- Allow placeholder fingerprint for PIN-only devices.
ALTER TABLE devices
    ALTER COLUMN device_fingerprint DROP NOT NULL;
