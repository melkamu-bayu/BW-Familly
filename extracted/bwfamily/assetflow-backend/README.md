# AssetFlow Backend — Phase 0–6

Implements the full backend roadmap: **Foundation**, **Identity & Core Data**,
**Financial Core**, **Domain Modules** (Vehicles, Rental Houses, Construction
Shop, Gold-Mining Project), **Reports & Analytics**, **Offline Sync**, and now
**Notifications, Session Security, Rate Limiting & Backup/Restore**.

## Stack

FastAPI + SQLAlchemy 2.0 + PostgreSQL + Alembic, per Section 26 of the architecture plan.

## Quick start (Docker)

```bash
cp .env.example .env
docker compose up --build
```

Then, in a second terminal, run migrations and seed data:

```bash
docker compose exec api alembic upgrade head
docker compose exec api python -m app.seed
```

API is now live at `http://localhost:8000`. Interactive docs: `http://localhost:8000/docs`.

Seeded login: `admin@assetflow.local` / `ChangeMe123!` — **change this immediately**, it's a dev-only default.

## Quick start (local, no Docker)

Requires a running PostgreSQL instance.

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # edit DATABASE_URL to point at your Postgres
alembic upgrade head
python -m app.seed
uvicorn app.main:app --reload
```

## What's implemented

- **Auth**: login, rotating refresh tokens, logout, `/auth/me` — argon2 password hashing, JWT access/refresh.
- **RBAC**: `roles` / `permissions` tables + `require_permission()` FastAPI dependency, seeded per the Section 19 role matrix (super_admin/manager/accountant/staff/viewer).
- **Business structure**: `business_categories` → `business_units` → `vehicles`/`properties`/`projects`, seeded with the exact six vehicles, two houses, one shop, one Gold-Mining Project from Section 31 — as data rows, not hard-coded logic.
- **Financial core**: revenue & expense transaction endpoints with sequential `REV-YYYY-NNNNNN` / `EXP-YYYY-NNNNNN` codes, idempotency-key deduplication, soft delete, and an audit-log entry written in the same DB transaction as every mutation.
- **Accounts**: balance listing + inter-account transfers, with `current_balance` recomputed centrally via `services/financial_calculator.py` (Section 28 — calculations never live in more than one place).
- **Dashboard**: `/dashboard/summary` (today/this-month/all-time revenue-expense-profit + cash & bank total) and `/dashboard/business-performance` (per-category revenue/expense/profit/% contribution), matching Section 3 and Section 34 of the plan.
- **Vehicles** (`/vehicles`): CRUD, `/vehicles/{id}/profitability` (revenue, expenses, profit, cost/profit per km, cost per operating hour), and a maintenance log.
- **Properties / Rental Houses** (`/properties`): CRUD, tenants, `/properties/{id}/rent` for rent collection (full/partial/advance, posts to the shared revenue pipeline automatically), rent history, and `/properties/{id}/dashboard` (collected/outstanding rent, net rental profit, occupancy).
- **Construction Materials Shop** (`/shop`): products (with low-stock filter and live stock valuation), suppliers, customers, `/shop/purchases` (increases stock, optionally posts an expense), `/shop/sales` (validates stock before committing, decreases stock, optionally posts revenue), and `/shop/dashboard` (revenue, COGS, gross profit, net profit, low-stock count).
- **Gold-Mining Project** (`/projects/gold-mining`): investment/expense/revenue transactions (expense/revenue entries post through the shared financial pipeline when an account is given), status transitions, and `/projects/gold-mining/dashboard` (total investment, expenses, revenue, net profit, cash used, ROI).

All domain writes still go through the same idempotency-key + audit-log + centralized-calculation pattern established in Phase 2 — no domain module computes profit or account balances independently.

- **Reports** (`/reports`): consolidated P&L, P&L by category, P&L by every individual asset, cash flow (day/week/month buckets), receivables, payables, and `/reports/export` — the same report data as CSV, Excel (`.xlsx`), or PDF, download-ready via `Content-Disposition`.
- **Analytics** (`/analytics`): `/trends` (revenue/expense/profit bucketed by day/week/month) and `/insights` — rule-based, data-derived observations (highest-revenue/profit/expense vehicle this month, month-over-month expense change, outstanding rent per property, shop gross profit, low-stock alerts). Every figure in an insight is a live query result, never an invented number, per Section 33's "AI must never invent financial figures."
- **Offline Sync** (`/sync`): `/sync/push` accepts a batch of queued revenue/expense records from the mobile outbox, applying each in its own SAVEPOINT so one bad item can't sink the whole batch, and treating a repeated `idempotency_key` as a no-op (`duplicate`) rather than a double-post. `/sync/pull?since=<timestamp>` returns everything created after that watermark, using server time as the authoritative clock the client should store for its next pull.
- **Notifications** (`/notifications`): personal notification inbox (list/mark-read) plus a rule engine (`services/notification_rules.py`) covering rent due/overdue, vehicle maintenance due, insurance/registration expiry, low inventory, unusual (anomalously high) daily expenses, and a daily financial summary. `/notifications/generate` runs every rule now — wire it to an external cron/Celery-beat job in production; every rule is dedup-safe so repeated calls don't spam duplicates.
- **Session security** (`/auth/pin/*`, `/auth/biometric`): device PIN and biometric-unlock toggle, both scoped to unlocking an already-valid local session — neither is a substitute for the password/JWT login flow itself (Section 20).
- **Rate limiting**: Redis-backed fixed-window limiter (`core/rate_limit.py`) applied to every request, configurable via `RATE_LIMIT_PER_MINUTE`. Fails **open** if Redis is unreachable — a limiter outage degrades to "no throttling" rather than taking the API down.
- **Backup/Restore** (`/backup`, super_admin only): `/backup/manifest` for a quick row-count sanity check, `/backup/export` for a full-database JSON download, `/backup/restore` to reload it. Restore is additive (`ON CONFLICT DO NOTHING` on every table's UUID primary key) — it can never overwrite or delete data created since the backup was taken. This is the in-app "download a backup now" path; schedule real `pg_dump`s for automated/point-in-time backups.

## What's next (not yet built)

- Mobile app (Flutter) — none of this backend has a client yet. This was the full backend roadmap (Phases 0–6).
- Push notification *delivery* (FCM/APNs) — `/notifications` currently stores in-app notifications only; wiring a push provider is a thin layer on top of `notification_rules.py`.
- Multi-project support: the data model already supports many projects; `/projects/gold-mining` currently resolves the single seeded project directly rather than taking a `{project_id}` path parameter.
- `sync/push` currently covers revenue and expense only; sales/purchases/rent-collection are not yet offline-queueable.
- A real scheduler (cron/Celery beat) calling `/notifications/generate` on an interval — right now it's manually/externally triggered.

## Project layout

```
app/
  core/          settings, DB session, JWT/password helpers, auth dependency
  models/        SQLAlchemy models (1:1 with the ERD)
  schemas/       Pydantic request/response models
  services/      financial_calculator.py, audit_service.py, transaction_code.py, export_service.py, notification_rules.py, backup_service.py
  api/v1/        routers: auth, revenue, expenses, accounts, dashboard, vehicles, properties, shop, projects, reports, analytics, sync, notifications, backup
  seed.py        loads roles/permissions/admin user + Section 31 business data
alembic/         migrations (0001_initial_schema creates every core table)
```

## Testing the flow end-to-end

```bash
# 1. Log in
curl -X POST localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@assetflow.local","password":"ChangeMe123!"}'

# 2. Use the access_token from the response as a Bearer token to, e.g., list accounts
curl localhost:8000/api/v1/accounts -H "Authorization: Bearer <access_token>"
```
