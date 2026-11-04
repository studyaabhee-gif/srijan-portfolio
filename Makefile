# Prof. Dr. Srijan Lal Shrestha — portfolio monorepo
# Windows: install make with `winget install GnuWin32.Make` or `choco install make`,
# or run the commands shown under each target directly (see README.md).

# Stop Git Bash/MSYS on Windows rewriting "/api/v1" into "C:/Program Files/Git/api/v1".
export MSYS_NO_PATHCONV := 1

API_BASE_URL ?= http://localhost:8080/api/v1
ADMIN_TOKEN  ?= change-me

.PHONY: help run-backend run-frontend run build build-backend build-frontend build-static \
        serve sync-seed test analyze docker-up docker-down clean

help:
	@echo "make run-backend    Go API on :8080 (ADMIN_TOKEN=$(ADMIN_TOKEN))"
	@echo "make run-frontend   Flutter web dev server in Chrome, pointed at the API"
	@echo "make build          Sync seed, test, and build backend + frontend"
	@echo "make serve          Build everything and serve the site + API on :8080"
	@echo "make build-static   Flutter build that runs on bundled seed data only (no API)"
	@echo "make sync-seed      Copy backend/data/portfolio_seed.json into the Flutter assets"
	@echo "make test           Go + Flutter tests;  make analyze: go vet + flutter analyze"
	@echo "make docker-up      Build and start the single-container stack"

run-backend:
	cd backend && ADMIN_TOKEN=$(ADMIN_TOKEN) go run .

run-frontend: sync-seed
	cd frontend && flutter run -d chrome --dart-define=API_BASE_URL=$(API_BASE_URL)

run: run-backend

sync-seed:
	cp backend/data/portfolio_seed.json frontend/assets/data/portfolio_seed.json

build: sync-seed test build-backend build-frontend

build-backend:
	cd backend && CGO_ENABLED=0 go build -trimpath -o bin/server .

build-frontend: sync-seed
	cd frontend && flutter build web --release --dart-define=API_BASE_URL=$(API_BASE_URL)

# For Cloudflare Pages / Vercel without a backend: everything renders from the seed.
build-static: sync-seed
	cd frontend && flutter build web --release --dart-define=API_BASE_URL=

serve: sync-seed
	cd frontend && flutter build web --release --dart-define=API_BASE_URL=/api/v1
	cd backend && ADMIN_TOKEN=$(ADMIN_TOKEN) WEB_DIR=../frontend/build/web go run .

test: sync-seed
	cd backend && go test ./...
	cd frontend && flutter test

analyze:
	cd backend && go vet ./...
	cd frontend && flutter analyze

docker-up:
	docker compose up -d --build

docker-down:
	docker compose down

clean:
	rm -rf backend/bin frontend/build
