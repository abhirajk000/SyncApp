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

type stubDeviceStore struct {
	devices map[uuid.UUID]*repository.Device
}

func (s *stubDeviceStore) Create(_ context.Context, d *repository.Device) error {
	d.CreatedAt = time.Now()
	s.devices[d.ID] = d
	return nil
}

func (s *stubDeviceStore) FindByID(_ context.Context, id uuid.UUID) (*repository.Device, error) {
	d, ok := s.devices[id]
	if !ok {
		return nil, repository.ErrNotFound
	}
	return d, nil
}

func (s *stubDeviceStore) FindActiveByID(_ context.Context, id uuid.UUID) (*repository.Device, error) {
	d, ok := s.devices[id]
	if !ok || d.RevokedAt != nil {
		return nil, repository.ErrNotFound
	}
	return d, nil
}

func (s *stubDeviceStore) FindByUserID(_ context.Context, userID uuid.UUID) ([]*repository.Device, error) {
	var result []*repository.Device
	for _, d := range s.devices {
		if d.UserID == userID && d.RevokedAt == nil {
			result = append(result, d)
		}
	}
	return result, nil
}

func (s *stubDeviceStore) Revoke(_ context.Context, id uuid.UUID) error {
	d, ok := s.devices[id]
	if !ok || d.RevokedAt != nil {
		return repository.ErrNotFound
	}
	now := time.Now()
	d.RevokedAt = &now
	return nil
}

func (s *stubDeviceStore) UpdateTrust(_ context.Context, id uuid.UUID, trusted bool) error {
	d, ok := s.devices[id]
	if !ok || d.RevokedAt != nil {
		return repository.ErrNotFound
	}
	d.Trusted = trusted
	return nil
}

func (s *stubDeviceStore) UpdateLastSeen(_ context.Context, id uuid.UUID) error {
	now := time.Now()
	if d, ok := s.devices[id]; ok {
		d.LastSeenAt = &now
	}
	return nil
}

type stubDeviceSessionStore struct {
	revokedDevices []uuid.UUID
}

func (s *stubDeviceSessionStore) RevokeAllForDevice(_ context.Context, deviceID uuid.UUID) error {
	s.revokedDevices = append(s.revokedDevices, deviceID)
	return nil
}

type stubPairingStore struct {
	requests map[string]*repository.PairingRequest // keyed by OTP
}

func (s *stubPairingStore) Create(_ context.Context, p *repository.PairingRequest) error {
	p.CreatedAt = time.Now()
	p.Status = repository.PairingStatusPending
	s.requests[p.OTP] = p
	return nil
}

func (s *stubPairingStore) FindPendingByOTP(_ context.Context, otp string) (*repository.PairingRequest, error) {
	req, ok := s.requests[otp]
	if !ok {
		return nil, repository.ErrNotFound
	}
	if req.Status != repository.PairingStatusPending {
		return nil, repository.ErrNotFound
	}
	if req.ExpiresAt.Before(time.Now()) {
		return nil, repository.ErrNotFound
	}
	return req, nil
}

func (s *stubPairingStore) UpdateStatus(_ context.Context, id uuid.UUID, status string) error {
	for _, req := range s.requests {
		if req.ID == id {
			req.Status = status
			return nil
		}
	}
	return repository.ErrNotFound
}

// ── factory ───────────────────────────────────────────────────────────────────

func newTestDeviceService() (*service.DeviceService, *stubDeviceStore, *stubDeviceSessionStore, *stubPairingStore) {
	devices := &stubDeviceStore{devices: make(map[uuid.UUID]*repository.Device)}
	sessions := &stubDeviceSessionStore{}
	pairing := &stubPairingStore{requests: make(map[string]*repository.PairingRequest)}
	audit := &stubAuditStore{}
	tokens := auth.NewTokenService("test-secret-32-bytes-long-enough!!", 15*time.Minute, 30*24*time.Hour)

	svc := service.NewDeviceService(devices, sessions, pairing, audit, tokens, 5*time.Minute)
	_ = audit
	return svc, devices, sessions, pairing
}

// ── tests ──────────────────────────────────────────────────────────────────────

func TestDeviceRegister(t *testing.T) {
	svc, store, _, _ := newTestDeviceService()
	userID := uuid.New()

	d, err := svc.Register(context.Background(), userID, service.DeviceInput{
		Name:      "iPhone 16 Pro",
		Platform:  "ios",
		PublicKey: make([]byte, 32),
	})
	if err != nil {
		t.Fatalf("Register() returned unexpected error: %v", err)
	}
	if d.UserID != userID {
		t.Errorf("device UserID = %v, want %v", d.UserID, userID)
	}
	if d.Trusted {
		t.Error("freshly registered device should not be trusted")
	}
	if _, ok := store.devices[d.ID]; !ok {
		t.Error("device not stored in stub")
	}
}

func TestDeviceList(t *testing.T) {
	svc, _, _, _ := newTestDeviceService()
	ctx := context.Background()
	userID := uuid.New()

	for i := 0; i < 3; i++ {
		_, err := svc.Register(ctx, userID, service.DeviceInput{
			Name:      "device",
			Platform:  "web",
			PublicKey: make([]byte, 32),
		})
		if err != nil {
			t.Fatalf("Register() iteration %d failed: %v", i, err)
		}
	}

	devices, err := svc.List(ctx, userID)
	if err != nil {
		t.Fatalf("List() returned unexpected error: %v", err)
	}
	if len(devices) != 3 {
		t.Errorf("expected 3 devices, got %d", len(devices))
	}
}

func TestDeviceRevoke(t *testing.T) {
	svc, store, sessionStore, _ := newTestDeviceService()
	ctx := context.Background()
	userID := uuid.New()

	d, _ := svc.Register(ctx, userID, service.DeviceInput{
		Name:      "Galaxy S25",
		Platform:  "android",
		PublicKey: make([]byte, 32),
	})

	err := svc.Revoke(ctx, userID, d.ID)
	if err != nil {
		t.Fatalf("Revoke() returned unexpected error: %v", err)
	}

	// Device should be revoked.
	if store.devices[d.ID].RevokedAt == nil {
		t.Error("expected RevokedAt to be set")
	}

	// Sessions should have been invalidated.
	if len(sessionStore.revokedDevices) == 0 {
		t.Error("expected sessions to be revoked")
	}
}

func TestDeviceRevoke_WrongOwner(t *testing.T) {
	svc, _, _, _ := newTestDeviceService()
	ctx := context.Background()

	ownerID := uuid.New()
	attackerID := uuid.New()

	d, _ := svc.Register(ctx, ownerID, service.DeviceInput{
		Name:      "Target Device",
		Platform:  "macos",
		PublicKey: make([]byte, 32),
	})

	err := svc.Revoke(ctx, attackerID, d.ID)
	if !errors.Is(err, service.ErrNotOwner) {
		t.Errorf("expected ErrNotOwner, got %v", err)
	}
}

func TestDeviceTrust(t *testing.T) {
	svc, store, _, _ := newTestDeviceService()
	ctx := context.Background()
	userID := uuid.New()

	d, _ := svc.Register(ctx, userID, service.DeviceInput{
		Name:      "New Device",
		Platform:  "web",
		PublicKey: make([]byte, 32),
	})

	if store.devices[d.ID].Trusted {
		t.Fatal("device should not be trusted initially")
	}

	if err := svc.Trust(ctx, userID, d.ID); err != nil {
		t.Fatalf("Trust() returned unexpected error: %v", err)
	}
	if !store.devices[d.ID].Trusted {
		t.Error("device should be trusted after Trust()")
	}
}

func TestQRPairing_InitiateAndConfirm(t *testing.T) {
	svc, store, _, pairingStore := newTestDeviceService()
	ctx := context.Background()
	userID := uuid.New()

	// Seed an initiator device.
	initiator, _ := svc.Register(ctx, userID, service.DeviceInput{
		Name:      "MacBook Pro",
		Platform:  "macos",
		PublicKey: make([]byte, 32),
	})

	// Initiate pairing from the existing device.
	initResult, err := svc.InitiatePairing(ctx, initiator.ID, userID)
	if err != nil {
		t.Fatalf("InitiatePairing() returned unexpected error: %v", err)
	}
	if initResult.Request.OTP == "" {
		t.Error("OTP should not be empty")
	}
	if initResult.QRPayload == "" {
		t.Error("QRPayload should not be empty")
	}

	// Confirm from the scanning device.
	confirmResult, err := svc.ConfirmPairing(ctx, service.PairConfirmInput{
		OTP:       initResult.Request.OTP,
		Name:      "iPhone 15 Pro",
		Platform:  "ios",
		PublicKey: make([]byte, 32),
	})
	if err != nil {
		t.Fatalf("ConfirmPairing() returned unexpected error: %v", err)
	}

	// New device should be in the store.
	newDevice, ok := store.devices[confirmResult.DeviceID]
	if !ok {
		t.Fatal("new device not found in store after pairing")
	}
	if newDevice.UserID != userID {
		t.Errorf("new device UserID = %v, want %v", newDevice.UserID, userID)
	}
	if !newDevice.Trusted {
		t.Error("device created via QR pairing should be trusted")
	}

	// Pairing request should be marked completed.
	if pairingStore.requests[initResult.Request.OTP].Status != repository.PairingStatusCompleted {
		t.Error("pairing request should be marked as completed")
	}
}

func TestQRPairing_InvalidOTP(t *testing.T) {
	svc, _, _, _ := newTestDeviceService()

	_, err := svc.ConfirmPairing(context.Background(), service.PairConfirmInput{
		OTP:       "000000",
		Name:      "Ghost Device",
		Platform:  "web",
		PublicKey: make([]byte, 32),
	})
	if !errors.Is(err, repository.ErrNotFound) {
		t.Errorf("expected ErrNotFound for invalid OTP, got %v", err)
	}
}
