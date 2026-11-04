# API-only image, for when the Flutter site is hosted separately
# (Cloudflare Pages / Vercel). Build from the backend/ folder:
#   docker build -t srijan-portfolio-api ./backend
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server .

FROM alpine:3.22
RUN apk add --no-cache ca-certificates tzdata && adduser -D -u 10001 app
WORKDIR /app
COPY --from=build /out/server ./server
COPY data ./data
COPY --chown=app:app storage ./storage
ENV ADDR=:8080 STORAGE_DIR=/app/storage SEED_PATH=/app/data/portfolio_seed.json
USER app
EXPOSE 8080
VOLUME ["/app/storage"]
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:8080/api/v1/health || exit 1
CMD ["./server"]
