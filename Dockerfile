# Single image: Go API + built Flutter web app, served same-origin on :8080.
# Build:  docker build -t srijan-portfolio .
# Run:    docker compose up -d   (see docker-compose.yml)

# ---- 1. Flutter web ---------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS web
WORKDIR /src/frontend
COPY frontend/pubspec.yaml frontend/pubspec.lock ./
RUN flutter pub get
COPY frontend/ ./
# Same-origin API: the browser calls /api/v1 on whatever host serves the page.
RUN flutter build web --release --dart-define=API_BASE_URL=/api/v1

# ---- 2. Go backend ----------------------------------------------------------
FROM golang:1.26-alpine AS api
WORKDIR /src/backend
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY backend/ ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server .

# ---- 3. Runtime -------------------------------------------------------------
FROM alpine:3.22
RUN apk add --no-cache ca-certificates tzdata && adduser -D -u 10001 app
WORKDIR /app
COPY --from=api /out/server ./server
COPY backend/data ./data
COPY --from=web /src/frontend/build/web ./web
COPY --chown=app:app backend/storage ./storage
ENV ADDR=:8080 STORAGE_DIR=/app/storage SEED_PATH=/app/data/portfolio_seed.json WEB_DIR=/app/web
USER app
EXPOSE 8080
VOLUME ["/app/storage"]
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:8080/api/v1/health || exit 1
CMD ["./server"]
