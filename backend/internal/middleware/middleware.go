// Package middleware holds request logging and per-IP rate limiting.
package middleware

import (
	"log/slog"
	"net"
	"net/http"
	"sync"
	"time"

	chimw "github.com/go-chi/chi/v5/middleware"
	"golang.org/x/time/rate"
)

// Logger emits one structured slog line per request.
func Logger(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			ww := chimw.NewWrapResponseWriter(w, r.ProtoMajor)
			next.ServeHTTP(ww, r)
			log.Info("http",
				"method", r.Method,
				"path", r.URL.Path,
				"status", ww.Status(),
				"bytes", ww.BytesWritten(),
				"dur_ms", time.Since(start).Milliseconds(),
				"ip", clientIP(r),
				"req_id", chimw.GetReqID(r.Context()))
		})
	}
}

type visitor struct {
	lim  *rate.Limiter
	seen time.Time
}

// RateLimiter is a token bucket per client IP, with idle entries evicted.
type RateLimiter struct {
	mu       sync.Mutex
	visitors map[string]*visitor
	r        rate.Limit
	burst    int
}

func NewRateLimiter(perMinute float64, burst int) *RateLimiter {
	rl := &RateLimiter{visitors: map[string]*visitor{}, r: rate.Limit(perMinute / 60), burst: burst}
	go rl.cleanup()
	return rl
}

func (rl *RateLimiter) cleanup() {
	for range time.Tick(time.Minute) {
		rl.mu.Lock()
		for ip, v := range rl.visitors {
			if time.Since(v.seen) > 10*time.Minute {
				delete(rl.visitors, ip)
			}
		}
		rl.mu.Unlock()
	}
}

func (rl *RateLimiter) allow(ip string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()
	v, ok := rl.visitors[ip]
	if !ok {
		v = &visitor{lim: rate.NewLimiter(rl.r, rl.burst)}
		rl.visitors[ip] = v
	}
	v.seen = time.Now()
	return v.lim.Allow()
}

func (rl *RateLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !rl.allow(clientIP(r)) {
			w.Header().Set("Retry-After", "60")
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusTooManyRequests)
			_, _ = w.Write([]byte(`{"error":"rate limit exceeded, please retry shortly"}`))
			return
		}
		next.ServeHTTP(w, r)
	})
}

// clientIP relies on chi's RealIP middleware having already rewritten
// RemoteAddr when the server sits behind a trusted proxy.
func clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
