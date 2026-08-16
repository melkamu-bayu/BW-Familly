# BW-Familly / AssetFlow

Two projects, meant to be deployed and run together:

- **`assetflow-backend/`** — FastAPI + PostgreSQL API. See its README for
  local Docker setup, or deploy it to [Render](https://render.com) using the
  included `render.yaml` Blueprint (New + → Blueprint → point at this repo).
- **`assetflow_mobile/`** — Flutter client. See its README and `CLAUDE.md`
  for build instructions. Needs `API_BASE_URL` pointed at wherever the
  backend is running (local Docker, or the Render URL once deployed).

## Quick start

1. Deploy `assetflow-backend/` (Render Blueprint, or `docker compose up`
   locally — see `assetflow-backend/README.md`).
2. Run migrations + seed data against it (`alembic upgrade head` then
   `python -m app.seed`).
3. Build the mobile app against that backend's URL:
   ```bash
   cd assetflow_mobile
   flutter create .
   flutter pub get
   flutter analyze
   ./scripts/build_android.sh   # or set API_BASE_URL and run manually
   ```

Seeded login once the backend is up: `admin@assetflow.local` / `ChangeMe123!`
— change this before using the app for anything real.
