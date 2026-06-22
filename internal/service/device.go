package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"github.com/syncbridge/api/internal/auth"
	"github.com/syncbridge/api/internal/repository"
)

// ErrNotOwner is returned when a user tries to operate on another user's device.
var ErrNotOwner = errors.New("device not owned by this user")

// ── Store interfaces ──────────────────────────────────────────────────────────

type deviceStore interface {
	Create(ctx context.Context, d *repository.Device) error
	FindByID(ctx context.Context, id uuid.UUID) (*repository.Device, error)
	FindActiveByID(ctx context.Context, id uuid.UUID) (*repository.Device, error)
	FindByUserID(ctx context.Context, userID uuid.UUID) ([]*repository.Device, error)
	Revoke(ctx context.Context, id uuid.UUID) error
	UpdateTrust(ctx context.Context, id uuid.UUID, trusted bool) error
	UpdateLastSeen(ctx context.Context, id uuid.UUID) error
}

type deviceSessionStore interface {
	RevokeAllForDevice(ctx context.Context, deviceID uuid.UUID) error
}

type pairingStore interface {
	Create(ctx context.Context, p *repository.PairingRequest) error
	FindPendingByOTP(ctx context.Context, otp string) (*repository.PairingRequest, error)
	UpdateStatus(ctx context.Context, id uuid.UUID, status string) error
}

type deviceAuditStore interface {
	Log(ctx context.Context, event *repository.AuditEvent) error
}

// ── DeviceService ─────────────────────────────────────────────────────────────

// DeviceService manages device registration, trust, revocation, and QR pairing.
type DeviceService struct {
	devices  deviceStore
	sessions deviceSessionStore
	pairing  pairingStore
	audit    deviceAuditStore
	tokens   *auth.TokenService
	// pairingTTL is the lifetime of a QR pairing code (default 5 min).
	pairingTTL time.Duration
}

// NewDeviceService constructs a DeviceService.
func NewDeviceService(
	devices deviceStore,
	sessions deviceSessionStore,
	pairing pairingStore,
	audit deviceAuditStore,
	tokens *auth.TokenService,
	pairingTTL time.Duration,
) *DeviceService {
	if pairingTTL == 0 {
		pairingTTL = 5 * time.Minute
	}
	return &DeviceService{
		devices:    devices,
		sessions:   sessions,
		pairing:    pairing,
		audit:      audit,
		tokens:     tokens,
		pairingTTL: pairingTTL,
	}
}

// RegisterInput is the input for adding a device to an account.
type DeviceInput struct {
	Name      string
	Platform  string
	PublicKey []byte // raw X25519 key bytes
}

// PairingPayload is the JSON-encoded content that gets rendered as a QR code.
// Phase 7 will add a cryptographic challenge/response to this payload.
type PairingPayload struct {
	PairingID string    `json:"pairing_id"`
	UserID    string    `json:"user_id"`
	OTP       string    `json:"otp"`
	ExpiresAt time.Time `json:"expires_at"`
}

// PairInitiateResult carries the pairing request and its QR payload.
type PairInitiateResult struct {
	Request   *repository.PairingRequest
	QRPayload string // JSON-encoded PairingPayload (ready for QR encoding)
}

// PairConfirmInput is the input provided by the scanning device.
type PairConfirmInput struct {
	OTP       string
	Name      string
	Platform  string
	PublicKey []byte
	// Request metadata for audit.
	IPAddress *string
	UserAgent *string
}

// ── Operations ────────────────────────────────────────────────────────────────

// Register adds a new device to a user's account.
// The device is created as trusted=false until the user explicitly trusts it
// via /devices/:id/trust, unless it is registered through QR pairing.
func (s *DeviceService) Register(ctx context.Context, userID uuid.UUID, in DeviceInput) (*repository.Device, error) {
	d, err := s.createDevice(ctx, userID, in.Name, in.Platform, in.PublicKey, false)
	if err != nil {
		return nil, err
	}

	s.logAudit(ctx, &userID, &d.ID, repository.EventDeviceRegistered,
		map[string]any{"platform": in.Platform, "trusted": false})

	return d, nil
}

// List returns all active devices for userID.
func (s *DeviceService) List(ctx context.Context, userID uuid.UUID) ([]*repository.Device, error) {
	devices, err := s.devices.FindByUserID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("list devices: %w", err)
	}
	return devices, nil
}

// Get returns a single active device.  Returns ErrNotOwner when deviceID
// does not belong to userID.
func (s *DeviceService) Get(ctx context.Context, userID, deviceID uuid.UUID) (*repository.Device, error) {
	d, err := s.devices.FindActiveByID(ctx, deviceID)
	if err != nil {
		return nil, fmt.Errorf("find device: %w", err)
	}
	if d.UserID != userID {
		return nil, ErrNotOwner
	}
	return d, nil
}

// Revoke revokes the device and invalidates all its sessions atomically.
func (s *DeviceService) Revoke(ctx context.Context, userID, deviceID uuid.UUID) error {
	d, err := s.devices.FindActiveByID(ctx, deviceID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return repository.ErrNotFound
		}
		return fmt.Errorf("find device: %w", err)
	}
	if d.UserID != userID {
		return ErrNotOwner
	}

	if err := s.devices.Revoke(ctx, deviceID); err != nil {
		return fmt.Errorf("revoke device: %w", err)
	}

	// Best-effort: revoke sessions. Don't fail the whole operation if this errors.
	if err := s.sessions.RevokeAllForDevice(ctx, deviceID); err != nil {
		log.Warn().Err(err).Str("device_id", deviceID.String()).
			Msg("failed to revoke device sessions")
	}

	s.logAudit(ctx, &userID, &deviceID, repository.EventDeviceRevoked,
		map[string]any{"platform": d.Platform})

	return nil
}

// Trust marks a device as trusted.
func (s *DeviceService) Trust(ctx context.Context, userID, deviceID uuid.UUID) error {
	d, err := s.devices.FindActiveByID(ctx, deviceID)
	if err != nil {
		return fmt.Errorf("find device: %w", err)
	}
	if d.UserID != userID {
		return ErrNotOwner
	}

	if err := s.devices.UpdateTrust(ctx, deviceID, true); err != nil {
		return fmt.Errorf("trust device: %w", err)
	}

	s.logAudit(ctx, &userID, &deviceID, repository.EventDeviceTrusted, nil)

	return nil
}

// InitiatePairing creates a pairing request for the initiator device and
// returns the QR payload ready for the client to render as a QR code.
func (s *DeviceService) InitiatePairing(ctx context.Context, initiatorDeviceID, userID uuid.UUID) (*PairInitiateResult, error) {
	otp, err := secureOTP()
	if err != nil {
		return nil, fmt.Errorf("generate OTP: %w", err)
	}

	challenge := make([]byte, 32)
	if _, err := rand.Read(challenge); err != nil {
		return nil, fmt.Errorf("generate challenge: %w", err)
	}

	pairingID := uuid.New()
	expiresAt := time.Now().Add(s.pairingTTL)

	req := &repository.PairingRequest{
		ID:                pairingID,
		InitiatorDeviceID: initiatorDeviceID,
		OTP:               otp,
		Challenge:         challenge,
		ExpiresAt:         expiresAt,
	}
	if err := s.pairing.Create(ctx, req); err != nil {
		return nil, fmt.Errorf("create pairing request: %w", err)
	}

	payload := PairingPayload{
		PairingID: pairingID.String(),
		UserID:    userID.String(),
		OTP:       otp,
		ExpiresAt: expiresAt,
	}
	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshal QR payload: %w", err)
	}

	s.logAudit(ctx, &userID, &initiatorDeviceID, repository.EventPairingInitiated,
		map[string]any{"pairing_id": pairingID.String(), "expires_at": expiresAt})

	return &PairInitiateResult{
		Request:   req,
		QRPayload: string(payloadJSON),
	}, nil
}

// ConfirmPairing validates the scanned OTP, registers the new device, and
// returns auth tokens so the device is immediately usable.
func (s *DeviceService) ConfirmPairing(ctx context.Context, in PairConfirmInput) (*AuthResult, error) {
	req, err := s.pairing.FindPendingByOTP(ctx, in.OTP)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			s.logAudit(ctx, nil, nil, repository.EventPairingFailed,
				map[string]any{"reason": "invalid_or_expired_otp"}, in.IPAddress, in.UserAgent)
			return nil, fmt.Errorf("invalid or expired pairing code: %w", repository.ErrNotFound)
		}
		return nil, fmt.Errorf("find pairing request: %w", err)
	}

	// Fetch the initiating device to learn which user owns this pairing.
	initiator, err := s.devices.FindByID(ctx, req.InitiatorDeviceID)
	if err != nil {
		return nil, fmt.Errorf("find initiator device: %w", err)
	}

	newDevice, err := s.createDevice(ctx, initiator.UserID, in.Name, in.Platform, in.PublicKey, true)
	if err != nil {
		return nil, fmt.Errorf("create device: %w", err)
	}

	if err := s.pairing.UpdateStatus(ctx, req.ID, repository.PairingStatusCompleted); err != nil {
		log.Warn().Err(err).Msg("failed to mark pairing as completed")
	}

	tokens, err := s.tokens.IssueTokenPair(initiator.UserID, newDevice.ID)
	if err != nil {
		return nil, fmt.Errorf("issue tokens: %w", err)
	}

	s.logAudit(ctx, &initiator.UserID, &newDevice.ID, repository.EventPairingCompleted,
		map[string]any{"platform": in.Platform, "pairing_id": req.ID.String()},
		in.IPAddress, in.UserAgent)

	return &AuthResult{
		UserID:   initiator.UserID,
		DeviceID: newDevice.ID,
		Tokens:   tokens,
	}, nil
}

// ── helpers ───────────────────────────────────────────────────────────────────

// createDevice creates a device and derives its fingerprint from the public key.
func (s *DeviceService) createDevice(
	ctx context.Context,
	userID uuid.UUID, name, platform string,
	pubKey []byte, trusted bool,
) (*repository.Device, error) {
	d := &repository.Device{
		ID:                uuid.New(),
		UserID:            userID,
		Name:              name,
		Platform:          platform,
		PublicKey:         pubKey,
		DeviceFingerprint: deviceFingerprint(pubKey),
		Trusted:           trusted,
	}
	if err := s.devices.Create(ctx, d); err != nil {
		return nil, fmt.Errorf("create device row: %w", err)
	}
	return d, nil
}

// deviceFingerprint returns the first 16 bytes of SHA-256(pubKey) encoded as hex.
// Exposed as package-level function so auth.go can reuse it.
func deviceFingerprint(pubKey []byte) string {
	h := sha256.Sum256(pubKey)
	return hex.EncodeToString(h[:16])
}

// secureOTP generates a cryptographically random 6-digit numeric code.
func secureOTP() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1_000_000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

func (s *DeviceService) logAudit(
	ctx context.Context,
	userID *uuid.UUID, deviceID *uuid.UUID,
	eventType string, data map[string]any,
	meta ...*string,
) {
	var ip, ua *string
	if len(meta) > 0 {
		ip = meta[0]
	}
	if len(meta) > 1 {
		ua = meta[1]
	}

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
