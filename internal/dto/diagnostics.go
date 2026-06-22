package dto

// DiagnosticsResponse is returned by GET /api/v1/diagnostics.
// It reports the server's view of the requesting connection, the local-network
// peer table, and key runtime flags — useful for debugging transfer routes.
type DiagnosticsResponse struct {
	// ServerVersion is the API build version.
	ServerVersion string `json:"server_version"`

	// ClientIP is the IP address the server sees for this request.
	ClientIP string `json:"client_ip"`

	// LocalPeers is the number of devices currently advertising LAN addresses
	// for the authenticated user.
	LocalPeers int `json:"local_peers"`

	// MDNSEnabled reports whether mDNS is active on the server.
	MDNSEnabled bool `json:"mdns_enabled"`

	// STUNURLs lists the configured STUN server URIs.
	STUNURLs []string `json:"stun_urls"`

	// TURNEnabled reports whether TURN credentials are configured.
	TURNEnabled bool `json:"turn_enabled"`

	// StorageBackend identifies the object storage type ("local", "s3", "minio").
	StorageBackend string `json:"storage_backend"`

	// DefaultRetentionMinutes is the server-level default retention window.
	DefaultRetentionMinutes int `json:"default_retention_minutes"`

	// RetentionMinutes is the retention preference of the authenticated user.
	// Returns the server default when the user has no custom setting.
	RetentionMinutes int `json:"retention_minutes"`
}
