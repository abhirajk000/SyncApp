package storage

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// LocalBackend stores objects as files under a root directory.
// The key is treated as a relative path; any missing parent directories are
// created automatically on Put.
//
// Thread safety: all operations are goroutine-safe (backed by OS syscalls).
type LocalBackend struct {
	root string // absolute path to the storage root
}

// NewLocalBackend creates a LocalBackend rooted at basePath.
// basePath is created if it does not exist, along with standard subdirectories.
func NewLocalBackend(basePath string) (*LocalBackend, error) {
	abs, err := filepath.Abs(basePath)
	if err != nil {
		return nil, fmt.Errorf("storage local: resolve path %q: %w", basePath, err)
	}
	if err := os.MkdirAll(abs, 0o750); err != nil {
		return nil, fmt.Errorf("storage local: mkdir %q: %w", abs, err)
	}
	for _, sub := range []string{"clipboard", "images", "screenshots", "files", "temp", "pinned"} {
		if err := os.MkdirAll(filepath.Join(abs, sub), 0o750); err != nil {
			return nil, fmt.Errorf("storage local: mkdir %q: %w", sub, err)
		}
	}
	return &LocalBackend{root: abs}, nil
}

// Type returns "local".
func (b *LocalBackend) Type() string { return "local" }

// Put writes r to <root>/<key>, creating intermediate directories as needed.
// size is informational (not checked); pass -1 if unknown.
func (b *LocalBackend) Put(_ context.Context, key string, r io.Reader, _ int64, _ string) error {
	dst := b.path(key)
	if err := os.MkdirAll(filepath.Dir(dst), 0o750); err != nil {
		return fmt.Errorf("storage local put mkdir: %w", err)
	}
	f, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o640)
	if err != nil {
		return fmt.Errorf("storage local put open: %w", err)
	}
	defer f.Close()

	if _, err := io.Copy(f, r); err != nil {
		// Attempt cleanup so partial files don't linger.
		_ = os.Remove(dst)
		return fmt.Errorf("storage local put write: %w", err)
	}
	return f.Sync()
}

// Get opens the file at key for reading.
// Returns ErrNotFound if the file does not exist.
func (b *LocalBackend) Get(_ context.Context, key string) (io.ReadCloser, int64, error) {
	dst := b.path(key)
	f, err := os.Open(dst)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, 0, ErrNotFound
		}
		return nil, 0, fmt.Errorf("storage local get: %w", err)
	}
	info, err := f.Stat()
	if err != nil {
		f.Close()
		return nil, 0, fmt.Errorf("storage local stat: %w", err)
	}
	return f, info.Size(), nil
}

// Delete removes the file at key.  No-ops if the file does not exist.
func (b *LocalBackend) Delete(_ context.Context, key string) error {
	dst := b.path(key)
	err := os.Remove(dst)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("storage local delete: %w", err)
	}
	return nil
}

// Exists reports whether the file at key exists.
func (b *LocalBackend) Exists(_ context.Context, key string) (bool, error) {
	_, err := os.Stat(b.path(key))
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}
	return false, fmt.Errorf("storage local exists: %w", err)
}

// path returns the absolute filesystem path for key.
// It sanitises key to prevent directory traversal.
func (b *LocalBackend) path(key string) string {
	// filepath.Join cleans "../" sequences; the result is always under b.root.
	return filepath.Join(b.root, filepath.FromSlash(key))
}
