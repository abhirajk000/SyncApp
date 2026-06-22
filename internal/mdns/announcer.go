// Package mdns provides mDNS/DNS-SD service announcement and discovery for
// the SyncBridge server.
//
// mDNS role in SyncBridge:
//
//	Server announces:   _syncbridge._tcp.local
//	  → Devices on the same Wi-Fi find the server without manual IP config.
//	  → Also enables zero-config federation between multiple self-hosted nodes.
//
//	Client devices (macOS/iOS/Android) do their OWN mDNS advertising so peers
//	can find each other without the server.  See Phase 7 client documentation.
//
// Usage:
//
//	ann, err := mdns.NewAnnouncer(mdns.Config{...})
//	ann.Start()
//	defer ann.Shutdown()
package mdns

import (
	"context"
	"fmt"
	"net"
	"os"

	"github.com/grandcat/zeroconf"
	"github.com/rs/zerolog/log"
)

const (
	// ServiceType is the DNS-SD service type registered by SyncBridge servers.
	ServiceType = "_syncbridge._tcp"
	// Domain is the mDNS search domain.
	Domain = "local."
)

// AnnouncerConfig holds all parameters for service announcement.
type AnnouncerConfig struct {
	// InstanceName is the human-readable service name (e.g. "SyncBridge Home").
	// Defaults to the OS hostname.
	InstanceName string
	// Port is the HTTP port the server is listening on.
	Port int
	// TXTRecords are key=value metadata included in the DNS-SD TXT record.
	// SyncBridge uses: version, api_version, instance_id.
	TXTRecords []string
	// Ifaces restricts announcement to specific network interfaces.
	// nil = all interfaces.
	Ifaces []net.Interface
}

// Announcer manages the mDNS service registration lifecycle.
// It is safe to call Shutdown multiple times.
type Announcer struct {
	server *zeroconf.Server
	cfg    AnnouncerConfig
}

// NewAnnouncer creates an Announcer but does not start it.
// Call Start to begin broadcasting.
func NewAnnouncer(cfg AnnouncerConfig) *Announcer {
	if cfg.InstanceName == "" {
		if h, err := os.Hostname(); err == nil {
			cfg.InstanceName = "SyncBridge@" + h
		} else {
			cfg.InstanceName = "SyncBridge"
		}
	}
	return &Announcer{cfg: cfg}
}

// Start registers the mDNS/DNS-SD service on the local network.
// It is non-blocking; the zeroconf server runs in background goroutines.
// If mDNS is unavailable (e.g. no multicast support) the error is logged and
// the function returns nil so the rest of the server can still start.
func (a *Announcer) Start() error {
	srv, err := zeroconf.Register(
		a.cfg.InstanceName,
		ServiceType,
		Domain,
		a.cfg.Port,
		a.cfg.TXTRecords,
		a.cfg.Ifaces,
	)
	if err != nil {
		// mDNS unavailable (Docker bridge, restricted OS, etc.).
		// Log and continue — cloud fallback still works.
		log.Warn().Err(err).Msg("mdns announcement unavailable; devices must use server IP directly")
		return nil
	}
	a.server = srv
	log.Info().
		Str("instance", a.cfg.InstanceName).
		Str("service", ServiceType+"."+Domain).
		Int("port", a.cfg.Port).
		Msg("mdns announced")
	return nil
}

// Shutdown de-registers the mDNS service and sends DNS-SD goodbye packets.
func (a *Announcer) Shutdown() {
	if a.server != nil {
		a.server.Shutdown()
		log.Info().Msg("mdns announcement stopped")
	}
}

// TXTRecords builds the standard SyncBridge TXT record set.
func TXTRecords(apiVersion, instanceID string) []string {
	return []string{
		fmt.Sprintf("api=%s", apiVersion),
		fmt.Sprintf("instance=%s", instanceID),
		"proto=syncbridge",
	}
}

// ── Context-aware wrapper ─────────────────────────────────────────────────────

// RunAnnouncer starts an Announcer and shuts it down when ctx is cancelled.
// Designed to be launched in a goroutine alongside the main server.
func RunAnnouncer(ctx context.Context, cfg AnnouncerConfig) {
	a := NewAnnouncer(cfg)
	if err := a.Start(); err != nil {
		log.Error().Err(err).Msg("mdns announcer failed to start")
		return
	}
	<-ctx.Done()
	a.Shutdown()
}
