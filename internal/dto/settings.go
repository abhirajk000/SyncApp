package dto

// RetentionSettingsResponse is returned by GET /api/v1/settings/retention.
type RetentionSettingsResponse struct {
	RetentionMinutes int   `json:"retention_minutes"`
	ValidOptions     []int `json:"valid_options"`
}

// RetentionSettingsRequest is the body of PUT /api/v1/settings/retention.
type RetentionSettingsRequest struct {
	// RetentionMinutes must be one of: 30, 60, 120, 360, 1440.
	RetentionMinutes int `json:"retention_minutes"`
}

// RetentionOptions lists the accepted retention values with human labels,
// for use in UI dropdowns.
var RetentionOptions = []RetentionOption{
	{Minutes: 30, Label: "30 minutes"},
	{Minutes: 60, Label: "1 hour"},
	{Minutes: 120, Label: "2 hours (default)"},
	{Minutes: 360, Label: "6 hours"},
	{Minutes: 1440, Label: "24 hours"},
}

// RetentionOption is one entry in the settings dropdown.
type RetentionOption struct {
	Minutes int    `json:"minutes"`
	Label   string `json:"label"`
}
