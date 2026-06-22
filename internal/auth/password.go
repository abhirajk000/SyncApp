// Package auth provides cryptographic primitives for SyncBridge:
// Argon2id password hashing and JWT token issuance/validation.
package auth

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"fmt"
	"strings"

	"golang.org/x/crypto/argon2"
)

// Argon2id parameters.  Meets OWASP recommended minimum:
//   - Memory: 64 MB
//   - Iterations: 3
//   - Parallelism: 4
//   - Key length: 32 bytes
const (
	a2Memory  uint32 = 64 * 1024 // 64 MB
	a2Time    uint32 = 3
	a2Threads uint8  = 4
	a2KeyLen  uint32 = 32
	a2SaltLen        = 16
)

// HashPassword derives an Argon2id hash of password and returns an encoded
// string in PHC-inspired format:
//
//	$argon2id$v=19$m=65536,t=3,p=4$<salt_hex>$<hash_hex>
func HashPassword(password string) (string, error) {
	salt := make([]byte, a2SaltLen)
	if _, err := rand.Read(salt); err != nil {
		return "", fmt.Errorf("generate salt: %w", err)
	}

	hash := argon2.IDKey([]byte(password), salt, a2Time, a2Memory, a2Threads, a2KeyLen)

	return fmt.Sprintf(
		"$argon2id$v=19$m=%d,t=%d,p=%d$%s$%s",
		a2Memory, a2Time, a2Threads,
		hex.EncodeToString(salt),
		hex.EncodeToString(hash),
	), nil
}

// VerifyPassword checks whether password matches the encoded Argon2id hash.
// It uses a constant-time comparison to prevent timing side-channels.
func VerifyPassword(password, encoded string) (bool, error) {
	memory, time_, threads, salt, expectedHash, err := decodeHash(encoded)
	if err != nil {
		return false, err
	}

	actualHash := argon2.IDKey([]byte(password), salt, time_, memory, threads, uint32(len(expectedHash)))

	return subtle.ConstantTimeCompare(actualHash, expectedHash) == 1, nil
}

// ── private ───────────────────────────────────────────────────────────────────

func decodeHash(encoded string) (memory, time_ uint32, threads uint8, salt, hash []byte, err error) {
	parts := strings.Split(encoded, "$")
	// Expected: ["", "argon2id", "v=19", "m=65536,t=3,p=4", "<salt_hex>", "<hash_hex>"]
	if len(parts) != 6 || parts[1] != "argon2id" {
		err = fmt.Errorf("invalid hash format")
		return
	}

	var p uint32
	if _, scanErr := fmt.Sscanf(parts[3], "m=%d,t=%d,p=%d", &memory, &time_, &p); scanErr != nil {
		err = fmt.Errorf("parse argon2 params: %w", scanErr)
		return
	}
	threads = uint8(p)

	if salt, err = hex.DecodeString(parts[4]); err != nil {
		err = fmt.Errorf("decode salt: %w", err)
		return
	}
	if hash, err = hex.DecodeString(parts[5]); err != nil {
		err = fmt.Errorf("decode hash: %w", err)
	}
	return
}
