-- Phase C: file delivery tracking for delete-on-delivery.

CREATE TABLE file_deliveries (
    file_id      UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    device_id    UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    delivered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (file_id, device_id)
);

CREATE INDEX idx_file_deliveries_file_id ON file_deliveries(file_id);
