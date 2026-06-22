package service_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/syncbridge/api/internal/auth"
	"github.com/syncbridge/api/internal/repository"
	"github.com/syncbridge/api/internal/service"
)

// ── in-memory stubs ───────────────────────────────────────────────────────────

type stubGlobalSettingsStore struct {
	settings *repository.GlobalSettings
}

func (s *stubGlobalSettingsStore) Get(_ context.Context) (*repository.GlobalSettings, error) {
	if s.settings == nil {
		return &repository.GlobalSettings{
			MasterPIN:   repository.DefaultMasterPIN,
			OwnerUserID: repository.OwnerUserID,
		}, nil
	}
	return s.settings, nil
}

type stubSessionStore struct {
	sessions map[string]*repository.Session
}

func (s *stubSessionStore) Create(_ context.Context, sess *repository.Session) error {
	s.sessions[sess.TokenHash] = sess
	return nil
}

func (s *stubSessionStore) FindByTokenHash(_ context.Context, hash string) (*repository.Session, error) {
	sess, ok := s.sessions[hash]
	if !ok {
		return nil, repository.ErrNotFound
	}
	return sess, nil
}

func (s *stubSessionStore) Revoke(_ context.Context, hash string) error {
	delete(s.sessions, hash)
	return nil
}

func (s *stubSessionStore) RevokeAllForDevice(_ context.Context, deviceID uuid.UUID) error {
	for k, sess := range s.sessions {
		if sess.DeviceID == deviceID {
			delete(s.sessions, k)
		}
	}
	return nil
}

type stubAuthDeviceStore struct {
	devices map[uuid.UUID]*repository.Device
}

func (s *stubAuthDeviceStore) Create(_ context.Context, d *repository.Device) error {
	d.CreatedAt = time.Now()
	s.devices[d.ID] = d
	return nil
}

func (s *stubAuthDeviceStore) FindActiveByID(_ context.Context, id uuid.UUID) (*repository.Device, error) {
	d, ok := s.devices[id]
	if !ok || d.RevokedAt != nil {
		return nil, repository.ErrNotFound
	}
	return d, nil
}

func (s *stubAuthDeviceStore) FindByUserID(_ context.Context, userID uuid.UUID) ([]*repository.Device, error) {
	var out []*repository.Device
	for _, d := range s.devices {
		if d.UserID == userID && d.RevokedAt == nil {
			out = append(out, d)
		}
	}
	return out, nil
}

func (s *stubAuthDeviceStore) CountActiveByUserID(_ context.Context, userID uuid.UUID) (int, error) {
	n := 0
	for _, d := range s.devices {
		if d.UserID == userID && d.RevokedAt == nil {
			n++
		}
	}
	return n, nil
}

func (s *stubAuthDeviceStore) UpdateTrustedUntil(_ context.Context, id uuid.UUID, until time.Time) error {
	d, ok := s.devices[id]
	if !ok {
		return repository.ErrNotFound
	}
	d.Trusted = true
	d.TrustedUntil = &until
	return nil
}

func (s *stubAuthDeviceStore) UpdateLastSeen(_ context.Context, id uuid.UUID) error {
	now := time.Now()
	if d, ok := s.devices[id]; ok {
		d.LastSeenAt = &now
	}
	return nil
}

func (s *stubAuthDeviceStore) UpdateName(_ context.Context, id uuid.UUID, name string) error {
	d, ok := s.devices[id]
	if !ok {
		return repository.ErrNotFound
	}
	d.Name = name
	return nil
}

type stubAuditStore struct{}

func (s *stubAuditStore) Log(_ context.Context, _ *repository.AuditEvent) error { return nil }

func newTestAuthService() (*service.AuthService, *stubSessionStore, *stubAuthDeviceStore) {
	sessions := &stubSessionStore{sessions: make(map[string]*repository.Session)}
	devices := &stubAuthDeviceStore{devices: make(map[uuid.UUID]*repository.Device)}
	settings := &stubGlobalSettingsStore{}
	tokens := auth.NewTokenService("test-secret-32-bytes-long-enough!!", 7*24*time.Hour, 7*24*time.Hour)
	svc := service.NewAuthService(settings, sessions, devices, &stubAuditStore{}, tokens, 7*24*time.Hour)
	return svc, sessions, devices
}

// ── tests ─────────────────────────────────────────────────────────────────────

func TestUnlock_Success_NewDevice(t *testing.T) {
	svc, sessions, devices := newTestAuthService()
	ctx := context.Background()
	deviceID := uuid.New()

	result, err := svc.Unlock(ctx, service.UnlockInput{
		PIN:        repository.DefaultMasterPIN,
		DeviceID:   deviceID,
		DeviceName: "MacBook",
		Platform:   "macos",
	})
	if err != nil {
		t.Fatalf("Unlock() error: %v", err)
	}
	if result.Tokens.AccessToken == "" {
		t.Error("expected access token")
	}
	if result.UserID != repository.OwnerUserID {
		t.Errorf("userID = %v, want owner", result.UserID)
	}
	if _, ok := devices.devices[deviceID]; !ok {
		t.Error("device not registered")
	}
	if len(sessions.sessions) == 0 {
		t.Error("session not persisted")
	}
	if result.TrustedUntil.Before(time.Now()) {
		t.Error("trusted_until should be in the future")
	}
}

func TestUnlock_InvalidPIN(t *testing.T) {
	svc, _, _ := newTestAuthService()

	_, err := svc.Unlock(context.Background(), service.UnlockInput{
		PIN:        "000000",
		DeviceID:   uuid.New(),
		DeviceName: "Phone",
		Platform:   "android",
	})
	if !errors.Is(err, service.ErrInvalidPIN) {
		t.Errorf("expected ErrInvalidPIN, got %v", err)
	}
}

func TestUnlock_ExistingDevice(t *testing.T) {
	svc, _, devices := newTestAuthService()
	ctx := context.Background()
	deviceID := uuid.New()

	if _, err := svc.Unlock(ctx, service.UnlockInput{
		PIN: repository.DefaultMasterPIN, DeviceID: deviceID,
		DeviceName: "Mac", Platform: "macos",
	}); err != nil {
		t.Fatalf("first unlock: %v", err)
	}

	result, err := svc.Unlock(ctx, service.UnlockInput{
		PIN: repository.DefaultMasterPIN, DeviceID: deviceID,
		DeviceName: "Mac", Platform: "macos",
	})
	if err != nil {
		t.Fatalf("second unlock: %v", err)
	}
	if len(devices.devices) != 1 {
		t.Errorf("expected 1 device, got %d", len(devices.devices))
	}
	if result.TrustedUntil.Before(time.Now()) {
		t.Error("trusted_until should be extended")
	}
}

func TestStatus_NeedsPIN(t *testing.T) {
	svc, _, devices := newTestAuthService()
	ctx := context.Background()
	deviceID := uuid.New()
	past := time.Now().Add(-time.Hour)
	devices.devices[deviceID] = &repository.Device{
		ID: deviceID, UserID: repository.OwnerUserID,
		TrustedUntil: &past,
	}

	st, err := svc.Status(ctx, deviceID)
	if err != nil {
		t.Fatalf("Status: %v", err)
	}
	if !st.NeedsPIN {
		t.Error("expected needs_pin=true for expired trust")
	}
}

func TestLogout_RevokesSessions(t *testing.T) {
	svc, sessions, _ := newTestAuthService()
	ctx := context.Background()

	res, err := svc.Unlock(ctx, service.UnlockInput{
		PIN: repository.DefaultMasterPIN, DeviceID: uuid.New(),
		DeviceName: "iPad", Platform: "ios",
	})
	if err != nil {
		t.Fatalf("Unlock: %v", err)
	}

	if err := svc.Logout(ctx, res.Tokens.RefreshToken, false, res.DeviceID); err != nil {
		t.Fatalf("Logout: %v", err)
	}
	if len(sessions.sessions) != 0 {
		t.Error("sessions should be empty after logout")
	}
}
