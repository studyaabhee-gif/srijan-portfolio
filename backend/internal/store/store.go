// Package store is a thread-safe embedded JSON store. Read-mostly content
// (profile, publications) comes from the seed; mutable state (gallery
// uploads, contact inquiries) is persisted to JSON files with atomic writes.
package store

import (
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"

	"github.com/srijanlalshrestha/portfolio-backend/data"
	"github.com/srijanlalshrestha/portfolio-backend/internal/models"
)

var imageExts = map[string]bool{".jpg": true, ".jpeg": true, ".png": true, ".webp": true, ".gif": true}

type Store struct {
	seed       models.Seed
	metrics    models.Metrics
	galleryDir string
	dbDir      string

	mu       sync.RWMutex
	uploads  []models.GalleryItem
	contacts []models.ContactInquiry
}

// Open loads the seed (disk copy first, embedded fallback), ensures storage
// folders exist, and loads persisted state.
func Open(seedPath, storageDir string, log *slog.Logger) (*Store, error) {
	raw, err := os.ReadFile(seedPath)
	if err != nil {
		log.Info("using embedded seed", "reason", err.Error())
		raw = data.Seed
	} else {
		log.Info("using on-disk seed", "path", seedPath)
	}

	var seed models.Seed
	if err := json.Unmarshal(raw, &seed); err != nil {
		return nil, fmt.Errorf("parse seed: %w", err)
	}
	if len(seed.Profile) == 0 || len(seed.Publications) == 0 {
		return nil, errors.New("seed is missing profile or publications")
	}
	for i := range seed.Gallery {
		seed.Gallery[i].Source = "seed"
	}

	s := &Store{
		seed:       seed,
		metrics:    ComputeMetrics(seed.Publications, seed.MetricsBase),
		galleryDir: filepath.Join(storageDir, "gallery"),
		dbDir:      filepath.Join(storageDir, "db"),
	}

	// "Migration": make sure every folder the app relies on exists.
	dirs := []string{s.dbDir, filepath.Join(storageDir, "cv")}
	for _, c := range models.GalleryCategories {
		dirs = append(dirs, filepath.Join(s.galleryDir, c))
	}
	for _, d := range dirs {
		if err := os.MkdirAll(d, 0o755); err != nil {
			return nil, fmt.Errorf("create %s: %w", d, err)
		}
	}

	if err := readJSON(s.path("gallery_uploads.json"), &s.uploads); err != nil {
		return nil, err
	}
	if err := readJSON(s.path("contacts.json"), &s.contacts); err != nil {
		return nil, err
	}
	log.Info("store ready",
		"publications", len(seed.Publications),
		"uploads", len(s.uploads),
		"contacts", len(s.contacts))
	return s, nil
}

func (s *Store) path(name string) string { return filepath.Join(s.dbDir, name) }

func (s *Store) Profile() json.RawMessage           { return s.seed.Profile }
func (s *Store) Publications() []models.Publication { return s.seed.Publications }
func (s *Store) Metrics() models.Metrics            { return s.metrics }
func (s *Store) GalleryDir() string                 { return s.galleryDir }

// Gallery merges seed items, recorded uploads, and any image files dropped
// into storage/gallery/<category>/ by hand.
func (s *Store) Gallery() []models.GalleryItem {
	s.mu.RLock()
	uploads := append([]models.GalleryItem(nil), s.uploads...)
	s.mu.RUnlock()

	known := map[string]bool{}
	for _, u := range uploads {
		known[u.URL] = true
	}

	items := append([]models.GalleryItem(nil), s.seed.Gallery...)
	items = append(items, uploads...)

	for _, cat := range models.GalleryCategories {
		entries, err := os.ReadDir(filepath.Join(s.galleryDir, cat))
		if err != nil {
			continue
		}
		for _, e := range entries {
			if e.IsDir() || !imageExts[strings.ToLower(filepath.Ext(e.Name()))] {
				continue
			}
			url := "/static/gallery/" + cat + "/" + e.Name()
			if known[url] {
				continue
			}
			items = append(items, models.GalleryItem{
				ID:       "d-" + cat + "-" + e.Name(),
				Category: cat,
				Caption:  captionFromFilename(e.Name()),
				URL:      url,
				Source:   "discovered",
			})
		}
	}
	return items
}

func (s *Store) AddUpload(item models.GalleryItem) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	next := append(append([]models.GalleryItem(nil), s.uploads...), item)
	if err := writeJSON(s.path("gallery_uploads.json"), next); err != nil {
		return err
	}
	s.uploads = next
	return nil
}

func (s *Store) AddContact(c models.ContactInquiry) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	next := append(append([]models.ContactInquiry(nil), s.contacts...), c)
	if err := writeJSON(s.path("contacts.json"), next); err != nil {
		return err
	}
	s.contacts = next
	return nil
}

// captionFromFilename turns "nast_keynote-2019.jpg" into "Nast keynote 2019".
func captionFromFilename(name string) string {
	base := strings.TrimSuffix(name, filepath.Ext(name))
	base = strings.NewReplacer("_", " ", "-", " ").Replace(base)
	base = strings.Join(strings.Fields(base), " ")
	if base == "" {
		return "Untitled"
	}
	return strings.ToUpper(base[:1]) + base[1:]
}

func readJSON(path string, v any) error {
	b, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	if len(strings.TrimSpace(string(b))) == 0 {
		return nil
	}
	if err := json.Unmarshal(b, v); err != nil {
		return fmt.Errorf("parse %s: %w", path, err)
	}
	return nil
}

// writeJSON writes to a temp file and renames it so a crash never leaves a
// half-written state file behind.
func writeJSON(path string, v any) error {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// ComputeMetrics derives impact metrics from the publication list.
func ComputeMetrics(pubs []models.Publication, base models.MetricsBase) models.Metrics {
	m := models.Metrics{MetricsBase: base, TotalPublications: len(pubs)}

	cites := make([]int, 0, len(pubs))
	byYear := map[int]*models.YearPoint{}
	byCat := map[string]int{}
	byDomain := map[string]int{}

	for _, p := range pubs {
		m.SeededCitations += p.Citations
		cites = append(cites, p.Citations)
		byCat[p.Category]++
		byDomain[p.Domain]++
		if p.Year > 0 {
			yp := byYear[p.Year]
			if yp == nil {
				yp = &models.YearPoint{Year: p.Year}
				byYear[p.Year] = yp
			}
			yp.Publications++
			yp.Citations += p.Citations
		}
	}

	sort.Sort(sort.Reverse(sort.IntSlice(cites)))
	for i, c := range cites {
		if c >= i+1 {
			m.HIndex = i + 1
		}
		if c >= 10 {
			m.I10Index++
		}
	}

	const firstYear, lastYear = 2001, 2026
	cum := 0
	for y := firstYear; y <= lastYear; y++ {
		yp := models.YearPoint{Year: y}
		if v := byYear[y]; v != nil {
			yp = *v
		}
		cum += yp.Citations
		yp.CumulativeCitations = cum
		m.ByYear = append(m.ByYear, yp)
	}

	m.ByCategory = sortedCounts(byCat)
	m.ByDomain = sortedCounts(byDomain)
	return m
}

func sortedCounts(in map[string]int) []models.Count {
	out := make([]models.Count, 0, len(in))
	for k, v := range in {
		out = append(out, models.Count{Label: k, Count: v})
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Count != out[j].Count {
			return out[i].Count > out[j].Count
		}
		return out[i].Label < out[j].Label
	})
	return out
}
