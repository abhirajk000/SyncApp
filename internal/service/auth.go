package service

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"github.com/syncbridge/api/internal/auth"
	"github.com/syncbridge/api/internal/repository"
)

// ── Sentinel errors ───────────────────────────────────────────────────────────

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrInvalidPIN         = errors.New("invalid pin")
	ErrDeviceRevoked      = errors.New("device has been revoked")
	ErrSessionExpired     = errors.New("session expired or revoked")
	ErrTooManyDevices     = errors.New("maximum number of devices reached")
)

// MaxDevices is the per-owner device limit.
const MaxDevices = 5

// ── Store interfaces ──────────────────────────────────────────────────────────

type globalSettingsStore interface {
	Get(ctx context.Context) (*repository.GlobalSettings, error)
}

type sessionStore interface {
	Create(ctx context.Context, s *repository.Session) error
	FindByTokenHash(ctx context.Context, hash string) (*repository.Session, error)
	Revoke(ctx context.Context, tokenHash string) error
	RevokeAllForDevice(ctx context.Context, deviceID uuid.UUID) error
}

type authDeviceStore interface {
	Create(ctx context.Context, d *repository.Device) error
	FindActiveByID(ctx context.Context, id uuid.UUID) (*repository.Device, error)
	FindByUserID(ctx context.Context, userID uuid.UUID) ([]*repository.Device, error)
	CountActiveByUserID(ctx context.Context, userID uuid.UUID) (int, error)
	UpdateTrustedUntil(ctx context.Context, id uuid.UUID, until time.Time) error
	UpdateLastSeen(ctx context.Context, id uuid.UUID) error
}

type auditStore interface {
	Log(ctx context.Context, event *repository.AuditEvent) error
}

// ── AuthService ───────────────────────────────────────────────────────────────

// AuthService implements PIN unlock, session status, and logout.
type AuthService struct {
	settings   globalSettingsStore
	sessions   sessionStore
	devices    authDeviceStore
	audit      auditStore
	tokens     *auth.TokenService
	trustTTL   time.Duration
}

// NewAuthService constructs an AuthService wired to its dependencies.
func NewAuthService(
	settings globalSettingsStore,
	sessions sessionStore,
	devices authDeviceStore,
	audit auditStore,
	tokens *auth.TokenService,
	trustTTL time.Duration,
) *AuthService {
	return &AuthService{
		settings: settings,
		sessions: sessions,
		devices:  devices,
		audit:    audit,
		tokens:   tokens,
		trustTTL: trustTTL,
	}
}

// ── Input / output ────────────────────────────────────────────────────────────

// UnlockInput is the internal input for PIN unlock.
type UnlockInput struct {
	PIN        string
	DeviceID   uuid.UUID
	DeviceName string
	Platform   string
	IPAddress  *string
	UserAgent  *string
}

// AuthResult carries identity and issued tokens after a successful unlock.
type AuthResult struct {
	UserID       uuid.UUID
	DeviceID     uuid.UUID
	Tokens       *auth.TokenPair
	TrustedUntil time.Time
}

// TrustStatus reports whether a device still has an active trust window.
type TrustStatus struct {
	DeviceID     uuid.UUID
	TrustedUntil *time.Time
	NeedsPIN     bool
}

// ── Unlock ────────────────────────────────────────────────────────────────────

// Unlock validates the master PIN on the server and issues a 7-day device token.
// New devices are registered automatically (up to MaxDevices).
func (s *AuthService) Unlock(ctx context.Context, in UnlockInput) (*AuthResult, error) {
	gs, err := s.settings.Get(ctx)
	if err != nil {
		return nil, fmt.Errorf("load global settings: %w", err)
	}

	if err := auth.ValidatePIN(in.PIN, gs.MasterPIN); err != nil {
		s.logAudit(ctx, &gs.OwnerUserID, &in.DeviceID, repository.EventUserLoginFailed,
			map[string]any{"reason": "bad_pin"}, in.IPAddress, in.UserAgent)
		return nil, ErrInvalidPIN
	}

	device, err := s.devices.FindActiveByID(ctx, in.DeviceID)
	if err != nil && !errors.Is(err, repository.ErrNotFound) {
		return nil, fmt.Errorf("find device: %w", err)
	}

	if device == nil {
		count, err := s.devices.CountActiveByUserID(ctx, gs.OwnerUserID)
		if err != nil {
			return nil, fmt.Errorf("count devices: %w", err)
		}
		if count >= MaxDevices {
			return nil, ErrTooManyDevices
		}
		device, err = s.createPINDevice(ctx, gs.OwnerUserID, in.DeviceID, in.DeviceName, in.Platform)
		if err != nil {
			return nil, err
		}
	} else if device.UserID != gs.OwnerUserID {
		return nil, ErrDeviceRevoked
	}

	trustedUntil := time.Now().Add(s.trustTTL)
	if err := s.devices.UpdateTrustedUntil(ctx, device.ID, trustedUntil); err != nil {
		return nil, fmt.Errorf("extend trust: %w", err)
	}

	tokens, err := s.tokens.IssueTokenPair(gs.OwnerUserID, device.ID)
	if err != nil {
		return nil, fmt.Errorf("issue tokens: %w", err)
	}

	if err := s.persistSession(ctx, device.ID, tokens, in.IPAddress); err != nil {
		return nil, err
	}

	go func() {
		if updateErr := s.devices.UpdateLastSeen(context.Background(), device.ID); updateErr != nil {
			log.Warn().Err(updateErr).Str("device_id", device.ID.String()).Msg("update last_seen failed")
		}
	}()

	s.logAudit(ctx, &gs.OwnerUserID, &device.ID, repository.EventUserLogin,
		map[string]any{"platform": device.Platform, "method": "pin"}, in.IPAddress, in.UserAgent)

	return &AuthResult{
		UserID:       gs.OwnerUserID,
		DeviceID:     device.ID,
		Tokens:       tokens,
		TrustedUntil: trustedUntil,
	}, nil
}

// ── Status ────────────────────────────────────────────────────────────────────

// Status returns the trust window for an authenticated device.
func (s *AuthService) Status(ctx context.Context, deviceID uuid.UUID) (*TrustStatus, error) {
	device, err := s.devices.FindActiveByID(ctx, deviceID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrDeviceRevoked
		}
		return nil, err
	}

	needsPIN := device.TrustedUntil == nil || device.TrustedUntil.Before(time.Now())
	return &TrustStatus{
		DeviceID:     device.ID,
		TrustedUntil: device.TrustedUntil,
		NeedsPIN:     needsPIN,
	}, nil
}

// ── Logout ────────────────────────────────────────────────────────────────────

// Logout revokes sessions for the requesting device.
func (s *AuthService) Logout(ctx context.Context, refreshToken string, allDevices bool, deviceID uuid.UUID) error {
	if allDevices {
		if err := s.sessions.RevokeAllForDevice(ctx, deviceID); err != nil {
			return fmt.Errorf("revoke all sessions: %w", err)
		}
	} else if refreshToken != "" {
		tokenHash := auth.HashToken(refreshToken)
		if err := s.sessions.Revoke(ctx, tokenHash); err != nil && !errors.Is(err, repository.ErrNotFound) {
			return fmt.Errorf("revoke session: %w", err)
		}
	} else {
		if err := s.sessions.RevokeAllForDevice(ctx, deviceID); err != nil {
			return fmt.Errorf("revoke sessions: %w", err)
		}
	}

	s.logAudit(ctx, nil, &deviceID, repository.EventUserLogout,
		map[string]any{"all_devices": allDevices}, nil, nil)
	return nil
}

// ── helpers ───────────────────────────────────────────────────────────────────

func (s *AuthService) createPINDevice(
	ctx context.Context,
	ownerID, deviceID uuid.UUID,
	name, platform string,
) (*repository.Device, error) {
	until := time.Now().Add(s.trustTTL)
	fp := pinDeviceFingerprint(deviceID)
	d := &repository.Device{
		ID:                deviceID,
		UserID:            ownerID,
		Name:              name,
		Platform:          platform,
		DeviceFingerprint: fp,
		Trusted:           true,
		TrustedUntil:      &until,
	}
	if err := s.devices.Create(ctx, d); err != nil {
		return nil, fmt.Errorf("create device: %w", err)
	}
	return d, nil
}

func pinDeviceFingerprint(deviceID uuid.UUID) string {
	h := sha256.Sum256([]byte("pin:" + deviceID.String()))
	return hex.EncodeToString(h[:])
}

func (s *AuthService) persistSession(ctx context.Context, deviceID uuid.UUID, tokens *auth.TokenPair, ip *string) error {
	session := &repository.Session{
		ID:        uuid.New(),
		DeviceID:  deviceID,
		TokenHash: tokens.RefreshTokenHash(),
		IPAddress: ip,
		ExpiresAt: tokens.RefreshExpiresAt,
	}
	if err := s.sessions.Create(ctx, session); err != nil {
		return fmt.Errorf("persist session: %w", err)
	}
	return nil
}

func (s *AuthService) logAudit(
	ctx context.Context,
	userID *uuid.UUID, deviceID *uuid.UUID,
	eventType string, data map[string]any,
	ip, ua *string,
) {
	event := &repository.AuditEvent{
		ID:        uuid.New(),
		UserID:    userID,
		DeviceID:  deviceID,
		EventType: eventType,
		EventData: data,
		IPAddress: ip,
		UserAgent: ua,
	}
	if err := s.audit.Log(ctx, event); err != nil {
		log.Warn().Err(err).Str("event", eventType).Msg("audit log failed")
	}
}
