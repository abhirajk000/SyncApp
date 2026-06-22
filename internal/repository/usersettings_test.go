package repository_test

// usersettings_test.go exercises UserSettingsRepository logic that can be
// validated without a database by using the domain-level helpers.

import (
	"testing"

	"github.com/syncbridge/api/internal/repository"
)

// TestValidRetentionMinutes verifies the accepted set matches the spec.
func TestValidRetentionMinutes(t *testing.T) {
	want := map[int]bool{30: true, 60: true, 120: true, 360: true, 1440: true}
	if len(repository.ValidRetentionMinutes) != len(want) {
		t.Fatalf("ValidRetentionMinutes length = %d; want %d",
			len(repository.ValidRetentionMinutes), len(want))
	}
	for v := range want {
		if !repository.ValidRetentionMinutes[v] {
			t.Errorf("ValidRetentionMinutes[%d] = false; want true", v)
		}
	}
}

// TestInvalidRetentionValues verifies non-accepted values are rejected.
func TestInvalidRetentionValues(t *testing.T) {
	invalid := []int{0, 15, 45, 90, 180, 720, 2880, -1}
	for _, v := range invalid {
		if repository.ValidRetentionMinutes[v] {
			t.Errorf("ValidRetentionMinutes[%d] = true; want false (should be invalid)", v)
		}
	}
}

// TestDefaultRetentionMinutes verifies the server default is 120 (2 hours).
func TestDefaultRetentionMinutes(t *testing.T) {
	if repository.DefaultRetentionMinutes != 120 {
		t.Errorf("DefaultRetentionMinutes = %d; want 120", repository.DefaultRetentionMinutes)
	}
	// Default must also be a valid option.
	if !repository.ValidRetentionMinutes[repository.DefaultRetentionMinutes] {
		t.Errorf("DefaultRetentionMinutes %d is not in ValidRetentionMinutes",
			repository.DefaultRetentionMinutes)
	}
}
