package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

// Config holds every runtime setting for the SyncBridge API.
// Values are populated from environment variables; .env is auto-loaded
// when present (ignored if the file does not exist).
type Config struct {
	// ── Server ───────────────────────────────────────────────────────────────
	Host        string
	Port        int
	Environment string // development | staging | production

	// ── Database ─────────────────────────────────────────────────────────────
	DatabaseURL         string
	DBMaxConns          int
	DBMinConns          int
	DBConnMaxLifetime   time.Duration
	DBConnMaxIdleTime   time.Duration
	DBHealthCheckPeriod time.Duration

	// ── Migrations ────────────────────────────────────────────────────────────
	RunMigrationsOnStartup bool
	MigrationsPath         string

	// ── Logging ───────────────────────────────────────────────────────────────
	LogLevel  string // debug | info | warn | error
	LogFormat string // json | pretty

	// ── Object Storage (Phase 7) ─────────────────────────────────────────────
	ObjectStorageType string // local | s3 | minio
	ObjectStoragePath string // root dir for local backend
	S3Bucket          string
	S3Region          string
	S3Endpoint        string
	S3AccessKey       string
	S3SecretKey       string
	S3UseSSL          bool

	// ── Limits ────────────────────────────────────────────────────────────────
	MaxClipboardSizeMB          int
	MaxFileSizeMB               int
	DefaultChunkSizeMB          int // chunk size for file uploads (default 4 MiB)
	// DefaultRetentionMinutes is the server-level fallback for new items when the
	// user has not set a custom retention preference.
	// Accepted values: 30 | 60 | 120 | 360 | 1440.  Default: 120 (2 hours).
	DefaultRetentionMinutes     int
	// Deprecated: kept for migration compatibility.  Use DefaultRetentionMinutes.
	FileRetentionDays           int
	HistoryRetentionDays        int

	// ── WebSocket (Phase 6) ──────────────────────────────────────────────────
	WSPingIntervalSec int

	// ── CORS ──────────────────────────────────────────────────────────────────
	CORSOrigins []string

	// ── TLS ───────────────────────────────────────────────────────────────────
	TLSMode string // auto | manual | off

	// ── Device trust (PIN auth) ───────────────────────────────────────────────
	// DeviceTrustDays is how long a device stays trusted after a successful PIN entry.
	DeviceTrustDays int

	// ── JWT (device session tokens) ───────────────────────────────────────────
	// JWTSecret is the HMAC-SHA256 signing key.  Must be ≥32 bytes.
	// Upgrade to RS256 in Phase 8 by replacing this with an RSA private key path.
	JWTSecret          string
	JWTAccessTokenTTL  time.Duration
	JWTRefreshTokenTTL time.Duration

	// ── Rate limiting (Phase 3) ───────────────────────────────────────────────
	// General API rate limit (requests per window per IP).
	RateLimitMax        int
	RateLimitWindowSecs int
	// Stricter limit applied to /auth/* endpoints only.
	AuthRateLimitMax int

	// ── Storage quota & transfer thresholds ───────────────────────────────────
	MaxUnpinnedStorageGB int // default 1 GB unpinned cap
	RelayAutoMaxMB       int // auto relay OK up to this size (100 MB)
	AutoCloudMaxMB         int // never auto cloud above this without force (1024 MB)

	// ── mDNS / local network (Phase 6) ───────────────────────────────────────
	// MDNSEnabled controls whether the server announces itself via mDNS/DNS-SD.
	// Disable in Docker or cloud environments where multicast is not available.
	MDNSEnabled bool
	// MDNSInstanceName is the human-readable service name in mDNS announcements.
	// Defaults to "SyncBridge@<hostname>" when empty.
	MDNSInstanceName string
	// MDNSInstanceID is a stable UUID that persists across restarts for mDNS TXT.
	// Auto-generated if empty.
	MDNSInstanceID string

	// ── WebRTC STUN/TURN (Phase 6) ────────────────────────────────────────────
	// STUNURLs is a comma-separated list of STUN server URIs.
	STUNURLs string
	// TURNURLs is a comma-separated list of TURN server URIs.
	TURNURLs string
	// TURNSecret is the HMAC-SHA1 shared secret for coturn time-limited credentials.
	// Generate with: openssl rand -hex 32
	// Left empty means TURN credentials are not generated (STUN only).
	TURNSecret string

	// LanAdvertiseTTLMin is how long (minutes) a local-peer advertisement is valid.
	// Devices must re-advertise within this window or they become invisible.
	LanAdvertiseTTLMin int
}

// Load reads configuration from environment variables.
// A .env file in the current working directory is loaded automatically
// if present; errors loading .env are silently ignored (production uses
// real env vars).
func Load() (*Config, error) {
	_ = godotenv.Load()

	cfg := &Config{
		Host:        getEnv("HOST", "0.0.0.0"),
		Port:        getEnvInt("PORT", 8080),
		Environment: getEnv("ENVIRONMENT", "development"),

		DatabaseURL:         getEnv("DATABASE_URL", ""),
		DBMaxConns:          getEnvInt("DB_MAX_CONNS", 25),
		DBMinConns:          getEnvInt("DB_MIN_CONNS", 2),
		DBConnMaxLifetime:   getEnvDuration("DB_CONN_MAX_LIFETIME", 30*time.Minute),
		DBConnMaxIdleTime:   getEnvDuration("DB_CONN_MAX_IDLE_TIME", 5*time.Minute),
		DBHealthCheckPeriod: getEnvDuration("DB_HEALTH_CHECK_PERIOD", 1*time.Minute),

		RunMigrationsOnStartup: getEnvBool("RUN_MIGRATIONS", true),
		MigrationsPath:         getEnv("MIGRATIONS_PATH", "migrations"),

		LogLevel:  getEnv("LOG_LEVEL", "info"),
		LogFormat: getEnv("LOG_FORMAT", "json"),

		ObjectStorageType: getEnv("OBJECT_STORAGE_TYPE", "local"),
		ObjectStoragePath: getEnv("OBJECT_STORAGE_PATH", "/opt/syncbridge/storage"),
		S3Bucket:          getEnv("S3_BUCKET", ""),
		S3Region:          getEnv("S3_REGION", "us-east-1"),
		S3Endpoint:        getEnv("S3_ENDPOINT", ""),
		S3AccessKey:       getEnv("S3_ACCESS_KEY", ""),
		S3SecretKey:       getEnv("S3_SECRET_KEY", ""),
		S3UseSSL:          getEnvBool("S3_USE_SSL", false),

		MaxClipboardSizeMB:   getEnvInt("MAX_CLIPBOARD_SIZE_MB", 10),
		MaxFileSizeMB:        getEnvInt("MAX_FILE_SIZE_MB", 1024),
		DefaultChunkSizeMB:   getEnvInt("DEFAULT_CHUNK_SIZE_MB", 4),
		DefaultRetentionMinutes: getEnvInt("DEFAULT_RETENTION_MINUTES", 120),
		FileRetentionDays:       getEnvInt("FILE_RETENTION_DAYS", 0),
		HistoryRetentionDays:    getEnvInt("HISTORY_RETENTION_DAYS", 0),

		WSPingIntervalSec: getEnvInt("WS_PING_INTERVAL_SEC", 30),

		CORSOrigins: getEnvStringSlice("CORS_ORIGINS", []string{"http://localhost:3000"}),

		TLSMode:    getEnv("TLS_MODE", "auto"),

		JWTSecret:          getEnv("JWT_SECRET", "syncbridge-dev-session-secret-32chars!!"),
		JWTAccessTokenTTL:  getEnvDuration("JWT_ACCESS_TOKEN_TTL", 7*24*time.Hour),
		JWTRefreshTokenTTL: getEnvDuration("JWT_REFRESH_TOKEN_TTL", 7*24*time.Hour),

		DeviceTrustDays: getEnvInt("DEVICE_TRUST_DAYS", 7),

		RateLimitMax:        getEnvInt("RATE_LIMIT_MAX", 60),
		RateLimitWindowSecs: getEnvInt("RATE_LIMIT_WINDOW_SEC", 60),
		AuthRateLimitMax:    getEnvInt("AUTH_RATE_LIMIT_MAX", 10),

		MaxUnpinnedStorageGB: getEnvInt("MAX_UNPINNED_STORAGE_GB", 1),
		RelayAutoMaxMB:       getEnvInt("RELAY_AUTO_MAX_MB", 100),
		AutoCloudMaxMB:       getEnvInt("AUTO_CLOUD_MAX_MB", 1024),

		MDNSEnabled:      getEnvBool("MDNS_ENABLED", true),
		MDNSInstanceName: getEnv("MDNS_INSTANCE_NAME", ""),
		MDNSInstanceID:   getEnv("MDNS_INSTANCE_ID", ""),

		STUNURLs:   getEnv("STUN_URLS", "stun:stun.l.google.com:19302"),
		TURNURLs:   getEnv("TURN_URLS", ""),
		TURNSecret: getEnv("TURN_SECRET", ""),

		LanAdvertiseTTLMin: getEnvInt("LAN_ADVERTISE_TTL_MIN", 10),
	}

	if err := cfg.validate(); err != nil {
		return nil, err
	}
	return cfg, nil
}

// Addr returns the host:port string for the HTTP listener.
func (c *Config) Addr() string {
	return fmt.Sprintf("%s:%d", c.Host, c.Port)
}

// IsDevelopment reports whether the environment is "development".
func (c *Config) IsDevelopment() bool {
	return c.Environment == "development"
}

// IsProduction reports whether the environment is "production".
func (c *Config) IsProduction() bool {
	return c.Environment == "production"
}

// MaxUnpinnedBytes returns the unpinned storage cap in bytes.
func (c *Config) MaxUnpinnedBytes() int64 {
	gb := c.MaxUnpinnedStorageGB
	if gb <= 0 {
		gb = 1
	}
	return int64(gb) * 1024 * 1024 * 1024
}

// ── private ───────────────────────────────────────────────────────────────────

func (c *Config) validate() error {
	if c.DatabaseURL == "" {
		return fmt.Errorf("DATABASE_URL is required")
	}
	if c.Port < 1 || c.Port > 65535 {
		return fmt.Errorf("PORT must be 1–65535, got %d", c.Port)
	}
	if c.JWTSecret == "" {
		return fmt.Errorf("JWT_SECRET is required in production")
	}
	if len(c.JWTSecret) < 32 {
		return fmt.Errorf("JWT_SECRET must be at least 32 characters")
	}
	valid := map[string]bool{"debug": true, "info": true, "warn": true, "error": true}
	if !valid[c.LogLevel] {
		return fmt.Errorf("LOG_LEVEL must be debug|info|warn|error, got %q", c.LogLevel)
	}
	validEnvs := map[string]bool{"development": true, "staging": true, "production": true}
	if !validEnvs[c.Environment] {
		return fmt.Errorf("ENVIRONMENT must be development|staging|production, got %q", c.Environment)
	}
	return nil
}

// ── env helpers ───────────────────────────────────────────────────────────────

func getEnv(key, defaultVal string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultVal
}

func getEnvInt(key string, defaultVal int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return defaultVal
}

func getEnvBool(key string, defaultVal bool) bool {
	if v := os.Getenv(key); v != "" {
		if b, err := strconv.ParseBool(v); err == nil {
			return b
		}
	}
	return defaultVal
}

func getEnvDuration(key string, defaultVal time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return defaultVal
}

func getEnvStringSlice(key string, defaultVal []string) []string {
	if v := os.Getenv(key); v != "" {
		parts := strings.Split(v, ",")
		result := make([]string, 0, len(parts))
		for _, p := range parts {
			if s := strings.TrimSpace(p); s != "" {
				result = append(result, s)
			}
		}
		if len(result) > 0 {
			return result
		}
	}
	return defaultVal
}
