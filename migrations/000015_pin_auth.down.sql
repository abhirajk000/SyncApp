ALTER TABLE devices
    ALTER COLUMN device_fingerprint SET NOT NULL,
    DROP CONSTRAINT IF EXISTS devices_public_key_length,
    ADD CONSTRAINT devices_public_key_length
        CHECK (octet_length(public_key) = 32),
    ALTER COLUMN public_key SET NOT NULL,
    DROP COLUMN IF EXISTS trusted_until;

DROP TABLE IF EXISTS global_settings;

-- Owner user row is left in place (harmless singleton).
