package mdns

import (
	"context"

	"github.com/grandcat/zeroconf"
	"github.com/rs/zerolog/log"
)

// ServiceEntry describes one discovered SyncBridge server on the local network.
type ServiceEntry struct {
	InstanceName string
	HostName     string
	AddrIPv4     []string
	AddrIPv6     []string
	Port         int
	Text         []string // raw TXT records
}

// Browser discovers SyncBridge servers on the local network via mDNS.
//
// Typical use: the server discovers neighbouring SyncBridge nodes for
// self-hosted federation.  Phase 7 will use this for automatic node linking.
//
// Usage:
//
//	b, _ := mdns.NewBrowser(ctx)
//	for entry := range b.Results() {
//	    // handle discovered server
//	}
type Browser struct {
	entries chan *ServiceEntry
	cancel  context.CancelFunc
}

// NewBrowser starts browsing for _syncbridge._tcp services on the LAN.
// The returned Browser streams discovered services through its Results channel.
// Call Close to stop browsing and drain the channel.
func NewBrowser(ctx context.Context) (*Browser, error) {
	inner, cancel := context.WithCancel(ctx)

	rawEntries := make(chan *zeroconf.ServiceEntry)
	resolver, err := zeroconf.NewResolver(nil)
	if err != nil {
		cancel()
		return nil, err
	}
	if err := resolver.Browse(inner, ServiceType, Domain, rawEntries); err != nil {
		cancel()
		return nil, err
	}

	b := &Browser{
		entries: make(chan *ServiceEntry, 32),
		cancel:  cancel,
	}

	go func() {
		defer close(b.entries)
		for e := range rawEntries {
			b.entries <- toServiceEntry(e)
		}
	}()

	log.Info().Str("service", ServiceType+"."+Domain).Msg("mdns browser started")
	return b, nil
}

// Results returns the channel of discovered services.
// The channel is closed when the browser stops.
func (b *Browser) Results() <-chan *ServiceEntry { return b.entries }

// Close stops the mDNS browse query and drains the results channel.
func (b *Browser) Close() {
	b.cancel()
	// Drain to unblock any goroutine waiting on Results.
	for range b.entries {
	}
	log.Info().Msg("mdns browser stopped")
}

// toServiceEntry converts a zeroconf entry to our type.
func toServiceEntry(e *zeroconf.ServiceEntry) *ServiceEntry {
	ipv4 := make([]string, 0, len(e.AddrIPv4))
	for _, ip := range e.AddrIPv4 {
		ipv4 = append(ipv4, ip.String())
	}
	ipv6 := make([]string, 0, len(e.AddrIPv6))
	for _, ip := range e.AddrIPv6 {
		ipv6 = append(ipv6, ip.String())
	}
	return &ServiceEntry{
		InstanceName: e.Instance,
		HostName:     e.HostName,
		AddrIPv4:     ipv4,
		AddrIPv6:     ipv6,
		Port:         e.Port,
		Text:         e.Text,
	}
}
