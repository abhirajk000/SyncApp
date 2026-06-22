package auth

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// Sentinel errors returned by the token service.
var (
	ErrTokenExpired = errors.New("token expired")
	ErrTokenInvalid = errors.New("token invalid")
)

// Token type discriminator stored inside the JWT payload.
const (
	TokenTypeAccess  = "access"
	TokenTypeRefresh = "refresh"
)

// Claims is the payload embedded in every SyncBridge JWT.
type Claims struct {
	jwt.RegisteredClaims
	UserID    uuid.UUID `json:"uid"`
	DeviceID  uuid.UUID `json:"did"`
	TokenType string    `json:"tty"` // "access" | "refresh"
}

// TokenPair holds a freshly issued access/refresh pair.
type TokenPair struct {
	AccessToken        string    `json:"access_token"`
	RefreshToken       string    `json:"refresh_token"`
	AccessExpiresAt    time.Time `json:"access_expires_at"`
	RefreshExpiresAt   time.Time `json:"refresh_expires_at"`
}

// RefreshTokenHash returns the SHA-256 hex hash of the raw refresh token
// string — this is what gets persisted in the sessions table for O(1)
// revocation lookup.
func (p *TokenPair) RefreshTokenHash() string {
	return HashToken(p.RefreshToken)
}

// HashToken returns the SHA-256 hex digest of a token string.
// Used for storing / looking up tokens without persisting the raw JWT.
func HashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}

// ── TokenService ─────────────────────────────────────────────────────────────

// TokenService issues and validates HS256 JWTs.
//
// Algorithm choice: HS256 (HMAC-SHA256) for Phase 3.
// Upgrade path to RS256 (asymmetric) is isolated to this package and
// requires only replacing SigningMethodHS256 with SigningMethodRS256
// and swapping the key type — no other code changes needed.
type TokenService struct {
	secret           []byte
	accessTokenTTL   time.Duration
	refreshTokenTTL  time.Duration
}

// NewTokenService constructs a TokenService.
// secret must be at least 32 bytes (enforced by config validation).
func NewTokenService(secret string, accessTTL, refreshTTL time.Duration) *TokenService {
	return &TokenService{
		secret:          []byte(secret),
		accessTokenTTL:  accessTTL,
		refreshTokenTTL: refreshTTL,
	}
}

// IssueTokenPair mints a new access+refresh token pair for the given user
// and device.
func (s *TokenService) IssueTokenPair(userID, deviceID uuid.UUID) (*TokenPair, error) {
	now := time.Now()

	accessExpiry := now.Add(s.accessTokenTTL)
	access, err := s.sign(userID, deviceID, TokenTypeAccess, accessExpiry)
	if err != nil {
		return nil, fmt.Errorf("sign access token: %w", err)
	}

	refreshExpiry := now.Add(s.refreshTokenTTL)
	refresh, err := s.sign(userID, deviceID, TokenTypeRefresh, refreshExpiry)
	if err != nil {
		return nil, fmt.Errorf("sign refresh token: %w", err)
	}

	return &TokenPair{
		AccessToken:      access,
		RefreshToken:     refresh,
		AccessExpiresAt:  accessExpiry,
		RefreshExpiresAt: refreshExpiry,
	}, nil
}

// ValidateAccessToken parses and validates an access token.
// Returns ErrTokenExpired or ErrTokenInvalid on failure.
func (s *TokenService) ValidateAccessToken(raw string) (*Claims, error) {
	claims, err := s.parse(raw)
	if err != nil {
		return nil, err
	}
	if claims.TokenType != TokenTypeAccess {
		return nil, ErrTokenInvalid
	}
	return claims, nil
}

// ValidateRefreshToken parses and validates a refresh token.
func (s *TokenService) ValidateRefreshToken(raw string) (*Claims, error) {
	claims, err := s.parse(raw)
	if err != nil {
		return nil, err
	}
	if claims.TokenType != TokenTypeRefresh {
		return nil, ErrTokenInvalid
	}
	return claims, nil
}

// ── private ───────────────────────────────────────────────────────────────────

func (s *TokenService) sign(userID, deviceID uuid.UUID, tokenType string, expiry time.Time) (string, error) {
	claims := Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        uuid.NewString(), // jti — unique per token for future revocation lists
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			ExpiresAt: jwt.NewNumericDate(expiry),
		},
		UserID:    userID,
		DeviceID:  deviceID,
		TokenType: tokenType,
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(s.secret)
}

func (s *TokenService) parse(raw string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(raw, &Claims{}, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return s.secret, nil
	})
	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return nil, ErrTokenExpired
		}
		return nil, ErrTokenInvalid
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, ErrTokenInvalid
	}
	return claims, nil
}
