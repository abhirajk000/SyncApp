// Package dto defines the request and response shapes for all HTTP endpoints.
package dto

import "time"

// ── PIN unlock ────────────────────────────────────────────────────────────────

// UnlockRequest is the body for POST /api/v1/auth/unlock.
// The master PIN is validated on the server — never trust client-only checks.
type UnlockRequest struct {
	PIN        string `json:"pin"`
	DeviceID   string `json:"device_id"`
	DeviceName string `json:"device_name"`
	Platform   string `json:"platform"`
}

// ── Logout ────────────────────────────────────────────────────────────────────

// LogoutRequest is the optional body for POST /api/v1/auth/logout.
type LogoutRequest struct {
	AllDevices bool `json:"all_devices"`
}

// ── Responses ─────────────────────────────────────────────────────────────────

// AuthResponse is returned on successful PIN unlock.
type AuthResponse struct {
	AccessToken      string    `json:"access_token"`
	RefreshToken     string    `json:"refresh_token"`
	AccessExpiresAt  time.Time `json:"access_expires_at"`
	RefreshExpiresAt time.Time `json:"refresh_expires_at"`
	UserID           string    `json:"user_id"`
	DeviceID         string    `json:"device_id"`
	TrustedUntil     time.Time `json:"trusted_until"`
}

// AuthStatusResponse is returned by GET /api/v1/auth/status.
type AuthStatusResponse struct {
	DeviceID     string     `json:"device_id"`
	TrustedUntil *time.Time `json:"trusted_until,omitempty"`
	NeedsPIN     bool       `json:"needs_pin"`
}

// MessageResponse is a generic success acknowledgement.
type MessageResponse struct {
	Message string `json:"message"`
}

// ErrorResponse is the standard error envelope returned on failures.
type ErrorResponse struct {
	Error     string `json:"error"`
	RequestID string `json:"request_id,omitempty"`
}
