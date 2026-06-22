CREATE TABLE pairing_requests (
    id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    initiator_device_id  UUID         NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    otp                  TEXT         NOT NULL,    -- 6-digit TOTP, time-bounded
    challenge            BYTEA        NOT NULL,    -- 32-byte random anti-replay challenge
    status               TEXT         NOT NULL DEFAULT 'pending',
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at           TIMESTAMPTZ  NOT NULL,    -- created_at + 5 minutes

    CONSTRAINT pairing_status_check
        CHECK (status IN ('pending', 'accepted', 'expired', 'rejected')),
    CONSTRAINT pairing_challenge_length
        CHECK (octet_length(challenge) = 32),
    CONSTRAINT pairing_expiry_valid
        CHECK (expires_at > created_at)
);
