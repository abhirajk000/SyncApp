package dto

import "time"

// ── Supported content types ───────────────────────────────────────────────────

const (
	ContentTypePlain   = "text/plain"
	ContentTypeURL     = "text/uri-list"  // RFC 2483 — one URI per line
	ContentTypeHTML    = "text/html"      // rich text as HTML
	ContentTypeRTF     = "text/rtf"       // rich text as RTF
)

// SupportedContentTypes is the allowlist used for validation.
var SupportedContentTypes = map[string]bool{
	ContentTypePlain: true,
	ContentTypeURL:   true,
	ContentTypeHTML:  true,
	ContentTypeRTF:   true,
}

// ── Requests ──────────────────────────────────────────────────────────────────

// ClipboardSyncRequest is the body for POST /api/v1/clipboard.
type ClipboardSyncRequest struct {
	// ContentType must be one of the SupportedContentTypes.
	ContentType string `json:"content_type" validate:"required"`
	// Content is the raw clipboard payload (plaintext; the server encrypts it).
	Content string `json:"content" validate:"required,min=1"`
}

// ── Responses ─────────────────────────────────────────────────────────────────

// ClipboardEntryResponse is the full representation of one clipboard entry.
type ClipboardEntryResponse struct {
	ID             string            `json:"id"`
	ContentType    string            `json:"content_type"`
	Content        string            `json:"content"`          // decrypted plaintext
	SourceDeviceID string            `json:"source_device_id"`
	PlaintextSize  int               `json:"plaintext_size"`
	VectorClock    map[string]int64  `json:"vector_clock"`
	Pinned         bool              `json:"pinned"`
	PinnedAt       *time.Time        `json:"pinned_at,omitempty"`
	Deduplicated   bool              `json:"deduplicated"`      // true if this entry was not newly created
	CreatedAt      time.Time         `json:"created_at"`
	ExpiresAt      *time.Time        `json:"expires_at,omitempty"`
}

// ClipboardHistoryResponse wraps a paginated list of clipboard entries.
type ClipboardHistoryResponse struct {
	Entries  []ClipboardEntryResponse `json:"entries"`
	Total    int                      `json:"total"`
	Limit    int                      `json:"limit"`
	Offset   int                      `json:"offset"`
	HasMore  bool                     `json:"has_more"`
}

// ClipboardEntryMeta is a lightweight summary for the history list.
// Used internally; the handler returns full entries for text/clipboard types.
type ClipboardEntryMeta struct {
	ID             string     `json:"id"`
	ContentType    string     `json:"content_type"`
	Preview        string     `json:"preview"`          // first 200 chars of decrypted content
	SourceDeviceID string     `json:"source_device_id"`
	PlaintextSize  int        `json:"plaintext_size"`
	Pinned         bool       `json:"pinned"`
	PinnedAt       *time.Time `json:"pinned_at,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	ExpiresAt      *time.Time `json:"expires_at,omitempty"`
}
