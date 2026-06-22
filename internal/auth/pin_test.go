package auth

import "testing"

func TestValidatePIN_Correct(t *testing.T) {
	if err := ValidatePIN("070901", "070901"); err != nil {
		t.Errorf("expected nil, got %v", err)
	}
}

func TestValidatePIN_Wrong(t *testing.T) {
	if err := ValidatePIN("000000", "070901"); err != ErrInvalidPIN {
		t.Errorf("expected ErrInvalidPIN, got %v", err)
	}
}

func TestValidatePIN_Empty(t *testing.T) {
	if err := ValidatePIN("", "070901"); err != ErrInvalidPIN {
		t.Errorf("expected ErrInvalidPIN, got %v", err)
	}
}
