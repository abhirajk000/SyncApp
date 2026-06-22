package dto

import "time"

// ── Device Registration ───────────────────────────────────────────────────────

// DeviceRegisterRequest adds a new device to the authenticated user's account.
// Used for adding devices without QR pairing (e.g. web client registering itself).
type DeviceRegisterRequest struct {
	Name      string `json:"name"       validate:"required,min=1,max=64"`
	Platform  string `json:"platform"   validate:"required,oneof=macos android ios web"`
	PublicKey string `json:"public_key" validate:"required"` // base64-encoded X25519 key
}

// ── QR Pairing ────────────────────────────────────────────────────────────────

// PairInitiateResponse is returned by POST /api/v1/devices/pair/initiate.
// The client encodes this payload as a QR code for the new device to scan.
type PairInitiateResponse struct {
	PairingID  string    `json:"pairing_id"`
	OTP        string    `json:"otp"`       // 6-digit code embedded in QR
	UserID     string    `json:"user_id"`
	ExpiresAt  time.Time `json:"expires_at"`
	// QRPayload is the JSON-serialised string the client should encode into QR.
	// It includes everything the scanning device needs to call /pair/confirm.
	QRPayload  string    `json:"qr_payload"`
}

// PairConfirmRequest is the body for POST /api/v1/devices/pair/confirm.
// Submitted by the device that scanned the QR code.
type PairConfirmRequest struct {
	OTP       string `json:"otp"        validate:"required,len=6"`
	Name      string `json:"name"       validate:"required,min=1,max=64"`
	Platform  string `json:"platform"   validate:"required,oneof=macos android ios web"`
	PublicKey string `json:"public_key" validate:"required"` // base64-encoded X25519 key
}

// DeviceRenameRequest updates the user-visible name of a device.
type DeviceRenameRequest struct {
	Name string `json:"name" validate:"required,min=1,max=64"`
}

// ── Responses ─────────────────────────────────────────────────────────────────

// DeviceResponse is the public representation of a device.
type DeviceResponse struct {
	ID           string     `json:"id"`
	Name         string     `json:"name"`
	Platform     string     `json:"platform"`
	Trusted      bool       `json:"trusted"`
	TrustedUntil *time.Time `json:"trusted_until,omitempty"`
	Online       bool       `json:"online"`
	LastSeenAt   *time.Time `json:"last_seen_at,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
	IsCurrent    bool       `json:"is_current"`
}

// DeviceListResponse wraps the list of devices for a user.
type DeviceListResponse struct {
	Devices []DeviceResponse `json:"devices"`
	Total   int              `json:"total"`
}

// PairConfirmResponse is returned on successful QR pairing.
// It carries auth tokens so the new device is immediately authenticated.
type PairConfirmResponse struct {
	AuthResponse
	Device DeviceResponse `json:"device"`
}
