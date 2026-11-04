package handlers

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/srijanlalshrestha/portfolio-backend/internal/store"
)

func newAPI(t *testing.T) *API {
	t.Helper()
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	dir := t.TempDir()
	st, err := store.Open(filepath.Join(dir, "missing.json"), dir, log) // forces embedded seed
	if err != nil {
		t.Fatal(err)
	}
	return &API{Store: st, Log: log}
}

func TestPublicationsFilterAndSort(t *testing.T) {
	api := newAPI(t)
	rec := httptest.NewRecorder()
	api.Publications(rec, httptest.NewRequest("GET", "/api/v1/publications?sort=citations", nil))
	var body struct {
		Count int `json:"count"`
		Items []struct {
			ID        string `json:"id"`
			Citations int    `json:"citations"`
		} `json:"items"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Count != 22 {
		t.Fatalf("want 22 publications, got %d", body.Count)
	}
	if body.Items[0].ID != "p20" {
		t.Fatalf("most cited should be p20, got %s", body.Items[0].ID)
	}

	rec = httptest.NewRecorder()
	api.Publications(rec, httptest.NewRequest("GET", "/api/v1/publications?search=banjade&category=HDI+%26+Socio-Economic+Modeling", nil))
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	if body.Count != 3 {
		t.Fatalf("want 3 Banjade HDI papers, got %d", body.Count)
	}
}

func TestMetrics(t *testing.T) {
	m := newAPI(t).Store.Metrics()
	if m.HIndex != 7 || m.I10Index != 7 || m.TotalPublications != 22 {
		t.Fatalf("unexpected metrics h=%d i10=%d n=%d", m.HIndex, m.I10Index, m.TotalPublications)
	}
	if first, last := m.ByYear[0].Year, m.ByYear[len(m.ByYear)-1].Year; first != 2004 || last != 2026 {
		t.Fatalf("year range %d-%d", first, last)
	}
}

func TestContactValidation(t *testing.T) {
	api := newAPI(t)
	rec := httptest.NewRecorder()
	api.Contact(rec, httptest.NewRequest("POST", "/api/v1/contact", bytes.NewBufferString(`{"name":"A","email":"bad"}`)))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("want 422, got %d", rec.Code)
	}

	ok := `{"name":"Asha Rai","email":"asha@example.com","role":"phd","subject":"PhD supervision","message":"I would like to work on distributed lag models for PM2.5."}`
	rec = httptest.NewRecorder()
	api.Contact(rec, httptest.NewRequest("POST", "/api/v1/contact", bytes.NewBufferString(ok)))
	if rec.Code != http.StatusCreated {
		t.Fatalf("want 201, got %d: %s", rec.Code, rec.Body)
	}
}

func TestGalleryDiscoversDroppedFiles(t *testing.T) {
	api := newAPI(t)
	if err := os.WriteFile(filepath.Join(api.Store.GalleryDir(), "conferences", "nast_keynote-2019.jpg"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	found := false
	for _, it := range api.Store.Gallery() {
		if it.Source == "discovered" && it.Caption == "Nast keynote 2019" {
			found = true
		}
	}
	if !found {
		t.Fatal("dropped file was not discovered")
	}
}

func TestUploadRequiresToken(t *testing.T) {
	api := newAPI(t)
	api.AdminToken = "secret"
	rec := httptest.NewRecorder()
	api.GalleryUpload(rec, httptest.NewRequest("POST", "/api/v1/gallery/upload", nil))
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("want 401, got %d", rec.Code)
	}
}
