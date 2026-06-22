package auth

import (
	"crypto/subtle"
	"errors"
)

// ErrInvalidPIN is returned when the submitted PIN does not match the master PIN.
var ErrInvalidPIN = errors.New("invalid pin")

// ValidatePIN compares candidate against master using constant-time equality.
// Validation must always happen on the server.
func ValidatePIN(candidate, master string) error {
	if subtle.ConstantTimeCompare([]byte(candidate), []byte(master)) != 1 {
		return ErrInvalidPIN
	}
	return nil
}
