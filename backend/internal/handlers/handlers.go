// Package handlers implements the /api/v1 REST endpoints.
package handlers

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/mail"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/srijanlalshrestha/portfolio-backend/internal/models"
	"github.com/srijanlalshrestha/portfolio-backend/internal/store"
)

const maxUploadBytes = 10 << 20 // 10 MB

type API struct {
	Store      *store.Store
	Log        *slog.Logger
	AdminToken string
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, status int, msg string, fields map[string]string) {
	body := map[string]any{"error": msg}
	if len(fields) > 0 {
		body["fields"] = fields
	}
	writeJSON(w, status, body)
}

func newID(prefix string) string {
	b := make([]byte, 6)
	_, _ = rand.Read(b)
	return prefix + "-" + hex.EncodeToString(b)
}

// GET /api/v1/health
func (a *API) Health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok", "time": time.Now().UTC().Format(time.RFC3339)})
}

// GET /api/v1/profile
func (a *API) Profile(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "public, max-age=300")
	_, _ = w.Write(a.Store.Profile())
}

// GET /api/v1/publications?search=&category=&year=&sort=citations|year|year_asc
func (a *API) Publications(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	search := strings.ToLower(strings.TrimSpace(q.Get("search")))
	category := strings.TrimSpace(q.Get("category"))
	year := 0
	if ys := q.Get("year"); ys != "" {
		y, err := strconv.Atoi(ys)
		if err != nil {
			writeErr(w, http.StatusBadRequest, "year must be an integer", nil)
			return
		}
		year = y
	}
	sortBy := q.Get("sort")
	if sortBy != "" && !slices.Contains([]string{"citations", "year", "year_asc"}, sortBy) {
		writeErr(w, http.StatusBadRequest, "sort must be one of citations, year, year_asc", nil)
		return
	}

	out := make([]models.Publication, 0)
	for _, p := range a.Store.Publications() {
		if category != "" && !strings.EqualFold(category, "all") && !strings.EqualFold(p.Category, category) {
			continue
		}
		if year != 0 && p.Year != year {
			continue
		}
		if search != "" && !matches(p, search) {
			continue
		}
		out = append(out, p)
	}

	switch sortBy {
	case "citations":
		sort.SliceStable(out, func(i, j int) bool { return out[i].Citations > out[j].Citations })
	case "year":
		sort.SliceStable(out, func(i, j int) bool { return dateKey(out[i]) > dateKey(out[j]) })
	case "year_asc":
		sort.SliceStable(out, func(i, j int) bool { return dateKey(out[i]) < dateKey(out[j]) })
	}

	writeJSON(w, http.StatusOK, map[string]any{"count": len(out), "items": out})
}

func dateKey(p models.Publication) int { return p.Year*100 + p.Month }

func matches(p models.Publication, needle string) bool {
	hay := []string{p.Title, p.Journal, p.Category, p.Summary, strings.Join(p.Authors, " "), strings.Join(p.Keywords, " ")}
	for _, h := range hay {
		if strings.Contains(strings.ToLower(h), needle) {
			return true
		}
	}
	return false
}

// GET /api/v1/metrics
func (a *API) Metrics(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, a.Store.Metrics())
}

// GET /api/v1/gallery?category=
func (a *API) Gallery(w http.ResponseWriter, r *http.Request) {
	filter := strings.ToLower(r.URL.Query().Get("category"))
	all := a.Store.Gallery()

	grouped := map[string][]models.GalleryItem{"all": {}}
	for _, c := range models.GalleryCategories {
		grouped[c] = []models.GalleryItem{}
	}
	items := make([]models.GalleryItem, 0, len(all))
	for _, it := range all {
		grouped[it.Category] = append(grouped[it.Category], it)
		grouped["all"] = append(grouped["all"], it)
		if filter == "" || filter == "all" || filter == it.Category {
			items = append(items, it)
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"categories": append([]string{"all"}, models.GalleryCategories...),
		"items":      items,
		"grouped":    grouped,
	})
}

var unsafeChars = regexp.MustCompile(`[^a-z0-9_-]+`)

// POST /api/v1/gallery/upload (multipart: file, caption, category, date?, location?)
func (a *API) GalleryUpload(w http.ResponseWriter, r *http.Request) {
	if a.AdminToken == "" {
		writeErr(w, http.StatusServiceUnavailable, "uploads are disabled: set ADMIN_TOKEN on the server", nil)
		return
	}
	got := r.Header.Get("X-Admin-Token")
	if subtle.ConstantTimeCompare([]byte(got), []byte(a.AdminToken)) != 1 {
		writeErr(w, http.StatusUnauthorized, "invalid or missing X-Admin-Token", nil)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxUploadBytes+1<<20)
	if err := r.ParseMultipartForm(maxUploadBytes); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid multipart form or file larger than 10 MB", nil)
		return
	}

	fields := map[string]string{}
	caption := strings.TrimSpace(r.FormValue("caption"))
	category := strings.ToLower(strings.TrimSpace(r.FormValue("category")))
	if caption == "" || len(caption) > 200 {
		fields["caption"] = "required, max 200 characters"
	}
	if !slices.Contains(models.GalleryCategories, category) {
		fields["category"] = "must be one of " + strings.Join(models.GalleryCategories, ", ")
	}
	file, hdr, err := r.FormFile("file")
	if err != nil {
		fields["file"] = "required"
	}
	if len(fields) > 0 {
		writeErr(w, http.StatusBadRequest, "validation failed", fields)
		return
	}
	defer file.Close()

	// Sniff the real content type instead of trusting the filename.
	head := make([]byte, 512)
	n, _ := io.ReadFull(file, head)
	ext := map[string]string{"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp", "image/gif": ".gif"}[http.DetectContentType(head[:n])]
	if ext == "" {
		writeErr(w, http.StatusUnsupportedMediaType, "file must be a JPEG, PNG, WebP or GIF image", nil)
		return
	}
	if _, err := file.Seek(0, io.SeekStart); err != nil {
		writeErr(w, http.StatusInternalServerError, "could not read upload", nil)
		return
	}

	stem := unsafeChars.ReplaceAllString(strings.ToLower(strings.TrimSuffix(hdr.Filename, filepath.Ext(hdr.Filename))), "_")
	stem = strings.Trim(stem, "_")
	if len(stem) > 60 {
		stem = stem[:60]
	}
	if stem == "" {
		stem = "photo"
	}
	name := fmt.Sprintf("%d_%s%s", time.Now().Unix(), stem, ext)
	dst := filepath.Join(a.Store.GalleryDir(), category, name)

	out, err := os.OpenFile(dst, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o644)
	if err != nil {
		a.Log.Error("upload create", "err", err)
		writeErr(w, http.StatusInternalServerError, "could not store file", nil)
		return
	}
	if _, err := io.Copy(out, file); err != nil {
		out.Close()
		os.Remove(dst)
		writeErr(w, http.StatusInternalServerError, "could not store file", nil)
		return
	}
	out.Close()

	item := models.GalleryItem{
		ID:       newID("u"),
		Category: category,
		Caption:  caption,
		Date:     strings.TrimSpace(r.FormValue("date")),
		Location: strings.TrimSpace(r.FormValue("location")),
		URL:      "/static/gallery/" + category + "/" + name,
		Source:   "upload",
	}
	if err := a.Store.AddUpload(item); err != nil {
		os.Remove(dst)
		a.Log.Error("upload persist", "err", err)
		writeErr(w, http.StatusInternalServerError, "could not save metadata", nil)
		return
	}
	a.Log.Info("gallery upload", "id", item.ID, "file", dst)
	writeJSON(w, http.StatusCreated, item)
}

// POST /api/v1/contact (JSON)
func (a *API) Contact(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 32<<10)
	var in struct {
		Name         string `json:"name"`
		Email        string `json:"email"`
		Role         string `json:"role"`
		Organization string `json:"organization"`
		Subject      string `json:"subject"`
		Message      string `json:"message"`
		Website      string `json:"website"` // honeypot: real users leave it empty
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid JSON body", nil)
		return
	}
	if in.Website != "" {
		writeJSON(w, http.StatusAccepted, map[string]string{"status": "received"})
		return
	}

	c := models.ContactInquiry{
		Name:         strings.TrimSpace(in.Name),
		Email:        strings.TrimSpace(in.Email),
		Role:         strings.ToLower(strings.TrimSpace(in.Role)),
		Organization: strings.TrimSpace(in.Organization),
		Subject:      strings.TrimSpace(in.Subject),
		Message:      strings.TrimSpace(in.Message),
	}
	fields := map[string]string{}
	if l := len([]rune(c.Name)); l < 2 || l > 120 {
		fields["name"] = "2–120 characters"
	}
	if addr, err := mail.ParseAddress(c.Email); err != nil || addr.Address != c.Email || len(c.Email) > 254 {
		fields["email"] = "a valid email address is required"
	}
	if !models.ContactRoles[c.Role] {
		fields["role"] = "must be one of phd, msc, collaborator, institution, media, other"
	}
	if l := len([]rune(c.Subject)); l < 3 || l > 200 {
		fields["subject"] = "3–200 characters"
	}
	if l := len([]rune(c.Message)); l < 20 || l > 5000 {
		fields["message"] = "20–5000 characters"
	}
	if len([]rune(c.Organization)) > 200 {
		fields["organization"] = "max 200 characters"
	}
	if len(fields) > 0 {
		writeErr(w, http.StatusUnprocessableEntity, "validation failed", fields)
		return
	}

	c.ID = newID("c")
	c.CreatedAt = time.Now().UTC().Format(time.RFC3339)
	if err := a.Store.AddContact(c); err != nil {
		a.Log.Error("contact persist", "err", err)
		writeErr(w, http.StatusInternalServerError, "could not save your message", nil)
		return
	}
	a.Log.Info("contact received", "id", c.ID, "role", c.Role)
	writeJSON(w, http.StatusCreated, map[string]string{"status": "received", "id": c.ID})
}
