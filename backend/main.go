// Command server runs the portfolio REST API and static file server.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"

	"github.com/srijanlalshrestha/portfolio-backend/internal/handlers"
	"github.com/srijanlalshrestha/portfolio-backend/internal/middleware"
	"github.com/srijanlalshrestha/portfolio-backend/internal/store"
)

func env(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(log)

	addr := env("ADDR", ":8080")
	storageDir := env("STORAGE_DIR", "storage")
	seedPath := env("SEED_PATH", filepath.Join("data", "portfolio_seed.json"))
	origins := strings.Split(env("CORS_ORIGINS", "*"), ",")

	st, err := store.Open(seedPath, storageDir, log)
	if err != nil {
		log.Error("store init failed", "err", err)
		os.Exit(1)
	}

	api := &handlers.API{Store: st, Log: log, AdminToken: os.Getenv("ADMIN_TOKEN")}
	if api.AdminToken == "" {
		log.Warn("ADMIN_TOKEN not set: POST /api/v1/gallery/upload is disabled")
	}

	r := chi.NewRouter()
	r.Use(chimw.RequestID)
	if env("TRUST_PROXY", "false") == "true" {
		r.Use(chimw.RealIP)
	}
	r.Use(middleware.Logger(log))
	r.Use(chimw.Recoverer)
	r.Use(chimw.Compress(5, "application/json"))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins: origins,
		AllowedMethods: []string{"GET", "POST", "OPTIONS"},
		AllowedHeaders: []string{"Accept", "Content-Type", "X-Admin-Token"},
		MaxAge:         600,
	}))

	general := middleware.NewRateLimiter(120, 40) // 120 req/min per IP
	contact := middleware.NewRateLimiter(5, 3)    // public form: tight
	upload := middleware.NewRateLimiter(30, 10)   // token-protected admin uploads

	r.Route("/api/v1", func(r chi.Router) {
		r.Use(general.Middleware)
		r.Get("/health", api.Health)
		r.Get("/profile", api.Profile)
		r.Get("/publications", api.Publications)
		r.Get("/metrics", api.Metrics)
		r.Get("/gallery", api.Gallery)
		r.With(upload.Middleware).Post("/gallery/upload", api.GalleryUpload)
		r.With(contact.Middleware).Post("/contact", api.Contact)
	})

	static := func(prefix, dir string) {
		fs := http.StripPrefix(prefix, http.FileServer(noDirListing{http.Dir(dir)}))
		r.Get(prefix+"*", func(w http.ResponseWriter, req *http.Request) {
			w.Header().Set("Cache-Control", "public, max-age=86400")
			fs.ServeHTTP(w, req)
		})
	}
	static("/static/gallery/", filepath.Join(storageDir, "gallery"))
	static("/static/cv/", filepath.Join(storageDir, "cv"))

	// Optional: serve the built Flutter web app (single-container deploys).
	if webDir := os.Getenv("WEB_DIR"); webDir != "" {
		r.NotFound(spaHandler(webDir))
		log.Info("serving web app", "dir", webDir)
	}

	srv := &http.Server{
		Addr:              addr,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       60 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	go func() {
		log.Info("server listening", "addr", addr, "storage", storageDir)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("listen failed", "err", err)
			os.Exit(1)
		}
	}()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	<-ctx.Done()

	log.Info("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Error("graceful shutdown failed", "err", err)
	}
	log.Info("bye")
}

// spaHandler serves files from dir and falls back to index.html so client-side
// routes such as /research survive a page reload.
func spaHandler(dir string) http.HandlerFunc {
	fs := http.FileServer(noDirListing{http.Dir(dir)})
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			http.NotFound(w, r)
			return
		}
		if strings.HasPrefix(r.URL.Path, "/api/") || strings.HasPrefix(r.URL.Path, "/static/") {
			http.NotFound(w, r)
			return
		}
		p := filepath.Join(dir, filepath.FromSlash(filepath.Clean("/"+r.URL.Path)))
		if st, err := os.Stat(p); err != nil || st.IsDir() {
			w.Header().Set("Cache-Control", "no-cache")
			http.ServeFile(w, r, filepath.Join(dir, "index.html"))
			return
		}
		fs.ServeHTTP(w, r)
	}
}

// noDirListing hides directory indexes from the static file server.
type noDirListing struct{ fs http.FileSystem }

func (n noDirListing) Open(name string) (http.File, error) {
	f, err := n.fs.Open(name)
	if err != nil {
		return nil, err
	}
	if s, err := f.Stat(); err == nil && s.IsDir() {
		f.Close()
		return nil, os.ErrNotExist
	}
	return f, nil
}
