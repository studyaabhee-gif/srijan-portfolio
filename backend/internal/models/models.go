// Package models defines the API data shapes. JSON field names match the
// shared seed file consumed by both the Go backend and the Flutter fallback.
package models

import "encoding/json"

type Seed struct {
	SchemaVersion int             `json:"schemaVersion"`
	Profile       json.RawMessage `json:"profile"`
	MetricsBase   MetricsBase     `json:"metricsBase"`
	Publications  []Publication   `json:"publications"`
	Gallery       []GalleryItem   `json:"gallery"`
}

type Publication struct {
	ID        string   `json:"id"`
	Title     string   `json:"title"`
	Authors   []string `json:"authors"`
	Journal   string   `json:"journal"`
	Volume    string   `json:"volume,omitempty"`
	Issue     string   `json:"issue,omitempty"`
	Pages     string   `json:"pages,omitempty"`
	ArticleNo string   `json:"articleNo,omitempty"`
	Year      int      `json:"year,omitempty"`
	Month     int      `json:"month,omitempty"`
	Citations int      `json:"citations"`
	Category  string   `json:"category"`
	Domain    string   `json:"domain"`
	Keywords  []string `json:"keywords"`
	Summary   string   `json:"summary"`
	URL       string   `json:"url,omitempty"`
	DOI       string   `json:"doi,omitempty"`
}

type MetricsBase struct {
	YearsOfService    int    `json:"yearsOfService"`
	CoAuthors         int    `json:"coAuthors"`
	ReportedCitations int    `json:"reportedCitations"`
	PhDSupervised     *int   `json:"phdSupervised"`
	MScSupervised     *int   `json:"mscSupervised"`
	Note              string `json:"note"`
}

type YearPoint struct {
	Year                int `json:"year"`
	Publications        int `json:"publications"`
	Citations           int `json:"citations"`
	CumulativeCitations int `json:"cumulativeCitations"`
}

type Count struct {
	Label string `json:"label"`
	Count int    `json:"count"`
}

type Metrics struct {
	MetricsBase
	TotalPublications int         `json:"totalPublications"`
	SeededCitations   int         `json:"seededCitations"`
	HIndex            int         `json:"hIndex"`
	I10Index          int         `json:"i10Index"`
	ByYear            []YearPoint `json:"byYear"`
	ByCategory        []Count     `json:"byCategory"`
	ByDomain          []Count     `json:"byDomain"`
}

// GalleryCategories is the canonical, ordered list of gallery buckets. Each
// one maps to a folder under storage/gallery/.
var GalleryCategories = []string{"conferences", "lectures", "research", "milestones", "personal"}

type GalleryItem struct {
	ID       string `json:"id"`
	Category string `json:"category"`
	Caption  string `json:"caption"`
	Date     string `json:"date,omitempty"`
	Location string `json:"location,omitempty"`
	// Asset is a Flutter bundle path (assets/...). URL is served by this backend.
	Asset  string `json:"asset,omitempty"`
	URL    string `json:"url,omitempty"`
	Source string `json:"source"` // seed | upload | discovered
}

type ContactInquiry struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	Email        string `json:"email"`
	Role         string `json:"role"`
	Organization string `json:"organization,omitempty"`
	Subject      string `json:"subject"`
	Message      string `json:"message"`
	CreatedAt    string `json:"createdAt"`
	RemoteAddr   string `json:"-"`
}

var ContactRoles = map[string]bool{
	"phd":          true,
	"msc":          true,
	"collaborator": true,
	"institution":  true,
	"media":        true,
	"other":        true,
}
