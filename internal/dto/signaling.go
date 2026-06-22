package dto

import "time"

// ── WebRTC / ICE configuration ────────────────────────────────────────────────

// ICEServer describes one STUN or TURN server returned in RTCConfigResponse.
type ICEServer struct {
	// URLs is the list of server URIs (stun:... or turn:...).
	URLs []string `json:"urls"`
	// Username is set only for TURN servers (time-limited credential).
	Username string `json:"username,omitempty"`
	// Credential is set only for TURN servers (HMAC-SHA1 of Username).
	Credential string `json:"credential,omitempty"`
}

// RTCConfigResponse is returned by GET /api/v1/rtc/config.
// Clients feed this directly into RTCPeerConnection({ iceServers }).
type RTCConfigResponse struct {
	ICEServers []ICEServer `json:"ice_servers"`
}

// ── Signaling session ─────────────────────────────────────────────────────────

// CreateOfferRequest is the body for POST /api/v1/signal.
type CreateOfferRequest struct {
	// ResponderDeviceID is the UUID of the device that should answer.
	ResponderDeviceID string `json:"responder_device_id" validate:"required"`
	// SDPOffer is the WebRTC SDP offer string from the initiating device.
	SDPOffer string `json:"sdp_offer" validate:"required"`
}

// ICECandidateInput carries one ICE candidate from a device.
type ICECandidateInput struct {
	Candidate     string `json:"candidate"      validate:"required"`
	SDPMid        string `json:"sdp_mid"`
	SDPMLineIndex int    `json:"sdp_mline_index"`
}

// SubmitAnswerRequest is the body for POST /api/v1/signal/:id/answer.
type SubmitAnswerRequest struct {
	SDPAnswer string `json:"sdp_answer" validate:"required"`
}

// ICECandidateRequest is the body for POST /api/v1/signal/:id/ice.
type ICECandidateRequest struct {
	ICECandidateInput
}

// ICECandidateResponse mirrors ICECandidateInput for session snapshot output.
type ICECandidateResponse struct {
	DeviceID      string    `json:"device_id"`
	Candidate     string    `json:"candidate"`
	SDPMid        string    `json:"sdp_mid"`
	SDPMLineIndex int       `json:"sdp_mline_index"`
	AddedAt       time.Time `json:"added_at"`
}

// SessionResponse is the shape of GET /api/v1/signal/:id.
type SessionResponse struct {
	ID            string                 `json:"id"`
	State         string                 `json:"state"`
	InitiatorID   string                 `json:"initiator_id"`
	ResponderID   string                 `json:"responder_id"`
	SDPOffer      string                 `json:"sdp_offer,omitempty"`
	SDPAnswer     string                 `json:"sdp_answer,omitempty"`
	ICECandidates []ICECandidateResponse `json:"ice_candidates"`
	CreatedAt     time.Time              `json:"created_at"`
	ExpiresAt     time.Time              `json:"expires_at"`
}

// ── Local peer discovery ──────────────────────────────────────────────────────

// AdvertiseRequest is the body for POST /api/v1/local/advertise.
type AdvertiseRequest struct {
	// Addrs is a list of bare IPv4/IPv6 addresses (no port), e.g. ["192.168.1.5"].
	Addrs []string `json:"addrs" validate:"required,min=1"`
	// Port is the local port the device is accepting WebRTC connections on.
	Port int `json:"port"`
}

// LocalPeerResponse describes one peer on the same network.
type LocalPeerResponse struct {
	DeviceID  string    `json:"device_id"`
	Addrs     []string  `json:"addrs"`
	Port      int       `json:"port"`
	UpdatedAt time.Time `json:"updated_at"`
}

// LocalPeersResponse is returned by GET /api/v1/local/peers.
type LocalPeersResponse struct {
	Peers []LocalPeerResponse `json:"peers"`
}
