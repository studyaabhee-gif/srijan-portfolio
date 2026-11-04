# Prof. Dr. Srijan Lal Shrestha: Academic Portfolio

Portfolio site for **Prof. Dr. Srijan Lal Shrestha**, Professor of Statistics and former Head of the Central Department of Statistics (CDS), Tribhuvan University, and Editor-in-Chief of the *Nepalese Journal of Statistics*.

- **Backend:** Go 1.26 · chi · slog · per-IP rate limiting · graceful shutdown · embedded JSON store, so no database setup is needed
- **Frontend:** Flutter Web · Riverpod 3 · go_router (clean URLs) · Dio · fl_chart · Google Fonts
- **Resilient by design:** the site renders fully from bundled seed data when the API is offline or not deployed

```
.
├── backend/
│   ├── main.go                     # router, CORS, rate limits, static files, graceful shutdown
│   ├── data/portfolio_seed.json    # ← single source of truth for all content
│   ├── internal/{handlers,store,models,middleware}
│   └── storage/
│       ├── gallery/{conferences,lectures,research,milestones}/   # drop photos here (live)
│       ├── cv/Prof_Dr_Srijan_Lal_Shrestha_CV.pdf
│       └── db/                     # contact enquiries + upload metadata (git-ignored)
├── frontend/
│   ├── lib/{models,services,providers,screens,widgets,theme}
│   ├── assets/data/portfolio_seed.json   # copy of the backend seed (offline fallback)
│   ├── assets/images/{profile,awards,logos,gallery/*}
│   └── assets/docs/Prof_Dr_Srijan_Lal_Shrestha_CV.pdf
├── Dockerfile · docker-compose.yml · Makefile
```

## Quick start

```bash
make run-backend      # API on http://localhost:8080  (ADMIN_TOKEN=change-me by default)
make run-frontend     # Flutter dev server in Chrome, talking to the API
```

Other targets: `make build`, `make serve` (builds the site and serves site + API together on :8080), `make test`, `make analyze`, `make sync-seed`, `make build-static`, `make docker-up`.

**Windows without `make`.** Install it with `winget install GnuWin32.Make`, or run the commands directly:

```powershell
cd backend;  $env:ADMIN_TOKEN="change-me"; go run .
cd frontend; flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

## Adding photos in VS Code

Every image slot that has no file yet shows a branded placeholder card with the **exact path to drop the file at**, so you can read it straight off the page.

> The images currently in `frontend/assets/images/` (portrait, awards, NJS cover, TU logo, office photo) and the CV PDF are **placeholders**. Replace them with real files **using the same file names**.

| What | Where to put the file | Rebuild? |
|---|---|---|
| Hero portrait | `frontend/assets/images/profile/hero_portrait.jpg` (4:5, about 1200×1500) | yes |
| Award photos | `frontend/assets/images/awards/nabil_award.jpg`, `bidhya_bhushan.jpg` | yes |
| NJS cover / TU logo | `frontend/assets/images/logos/njs_cover.jpg`, `tu_logo.jpg` | yes |
| Pre-listed gallery slots | the paths shown on the placeholder cards, e.g. `frontend/assets/images/gallery/research/fieldwork_01.jpg` | yes |
| **Any new gallery photo** | `backend/storage/gallery/<conferences\|lectures\|research\|milestones>/any_name.jpg` | **no, it appears live** |
| CV | `frontend/assets/docs/…CV.pdf` **and** `backend/storage/cv/…CV.pdf` | frontend: yes |

Photos dropped into `backend/storage/gallery/` are auto-discovered. The caption comes from the file name, so `nast_keynote-2019.jpg` becomes "Nast keynote 2019". To give a photo a proper caption, date and location, upload it through the API instead:

```bash
curl -X POST http://localhost:8080/api/v1/gallery/upload \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  -F file=@keynote.jpg -F category=conferences \
  -F caption="Keynote at NAST" -F date="March 2025" -F location="Lalitpur"
```

To add a new **bundled** gallery entry, add an item to `gallery` in `backend/data/portfolio_seed.json` with an `asset` path, then run `make sync-seed`.

## Editing content

All text, including the bio, timeline, honours, publications, teaching and collaborators, lives in **`backend/data/portfolio_seed.json`**. After editing it, run `make sync-seed` so the Flutter fallback gets the same data. A test fails if the two copies drift apart. The backend reads the on-disk seed at startup, so a restart is enough and no rebuild is needed.

**Please verify before publishing:**
- `metricsBase.phdSupervised` / `mscSupervised` are `null` because the numbers weren't available. The dashboard shows "—" until you fill them in.
- Author **order** for co-authored papers is inferred and not verified. Check it against each paper, because BibTeX export uses it.
- Citation counts are the approximate "N+" figures supplied. h-index and i10-index are **computed from those counts**, so they are lower bounds and are labelled as such on the site.
- Publication "summaries" are one-line descriptions written from the titles, not the published abstracts. Replace them with real abstracts where you can.
- No DOIs are recorded yet. Add a `doi` field to a publication and its "View source" button links to `doi.org`. Until then, buttons fall back to NepJOL or a Google Scholar title search.

## REST API (`/api/v1`)

| Method | Path | Notes |
|---|---|---|
| GET | `/health` | liveness |
| GET | `/profile` | bio, appointments, education, honours, timeline, links, collaborators |
| GET | `/publications` | `?search=` `?category=` `?year=` `?sort=citations\|year\|year_asc` |
| GET | `/metrics` | totals, h/i10 index, by-year output and citations (2004–2026), by category, by domain |
| GET | `/gallery` | `?category=`; seed + uploaded + auto-discovered photos, plus a `grouped` map |
| POST | `/gallery/upload` | multipart (`file`, `caption`, `category`, `date?`, `location?`); needs `X-Admin-Token`; 10 MB; JPEG/PNG/WebP/GIF checked by content sniffing |
| POST | `/contact` | JSON (`name`, `email`, `role`, `subject`, `message`, `organization?`); validated; stored in `storage/db/contacts.json` |

Static files: `/static/gallery/*` and `/static/cv/*`. Rate limits are 120 req/min per IP overall, 5/min for the contact form and 30/min for uploads.

| Env var | Default | Purpose |
|---|---|---|
| `ADDR` | `:8080` | listen address |
| `ADMIN_TOKEN` | *(unset → uploads disabled)* | upload auth |
| `STORAGE_DIR` | `storage` | gallery, CV, db |
| `SEED_PATH` | `data/portfolio_seed.json` | falls back to the embedded seed |
| `WEB_DIR` | *(unset)* | serve a built Flutter app with SPA fallback |
| `CORS_ORIGINS` | `*` | comma-separated, e.g. `https://srijan.example.com` |
| `TRUST_PROXY` | `false` | use `X-Forwarded-For` behind Cloudflare/nginx |

Frontend build flag `--dart-define=API_BASE_URL=…`:
- absolute URL: the API is on another host
- `/api/v1`: same origin, as in Docker
- empty: seed-only static site

## Deployment

**Single container (simplest).** One image serves the site and the API on the same origin:

```bash
echo "ADMIN_TOKEN=$(openssl rand -hex 24)" > .env
docker compose up -d --build        # http://localhost:8080
```

`backend/storage` is mounted as a volume, so photos dropped there in VS Code show up immediately and enquiries persist across restarts. Put Cloudflare in front (proxied DNS, SSL "Full") and set `TRUST_PROXY=true`.

**Static site on Cloudflare Pages or Vercel, API elsewhere:**

```bash
cd frontend
flutter build web --release --dart-define=API_BASE_URL=https://api.your-domain.com/api/v1
# Cloudflare Pages: output dir frontend/build/web (SPA rewrites via web/_redirects)
# Vercel:           vercel deploy build/web --prod   (rewrites via web/vercel.json)
```

Deploy the API with `docker build -t srijan-portfolio-api ./backend` on any container host (Fly.io, Render, a VPS) and set `CORS_ORIGINS` to the site's URL.

**Seed-only static site (no backend at all):** run `make build-static` and deploy `frontend/build/web`. Everything renders from bundled data. The contact form then offers a pre-filled email instead.

## Quality checks

```bash
cd backend && go vet ./... && go test ./...     # handler, filter, metrics, upload and discovery tests
cd frontend && flutter analyze && flutter test  # parity tests: offline fallback == API behaviour
```
