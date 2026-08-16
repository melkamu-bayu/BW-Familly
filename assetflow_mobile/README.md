# AssetFlow Mobile — Foundation

Flutter client scaffold wired against the AssetFlow backend (Phases 0–6).
This covers the architecture pieces from the plan's Step 6/7/9 (navigation,
screens, offline sync) end-to-end for a first slice: **login → dashboard →
vehicles → add transaction**, with the offline outbox working underneath it.

## Stack

Flutter + Riverpod (state) + go_router (navigation) + Dio (networking) +
sqflite (local cache/outbox) + flutter_secure_storage (tokens), per Section 26.

## What's implemented

- **Auth**: login screen, JWT stored in Keychain/Keystore (never SQLite), automatic
  access-token refresh on 401 via a Dio interceptor (`core/api_client.dart`),
  session restore on app launch, logout.
- **Navigation**: `go_router` shell with bottom nav (Dashboard / Vehicles / Alerts /
  Settings) and auth-based redirects — an unauthenticated user is always bounced to
  `/login`, an authenticated one is bounced away from it. Properties, Shop, Gold
  Project, and Accounts are reachable from Settings (11 nav items don't fit a
  bottom bar, per Section 25, so these get a list-style entry point instead).
- **Dashboard**: today/month/all-time revenue-expense-profit, cash & bank balance,
  and the business-performance breakdown by category, matching `/dashboard/summary`
  and `/dashboard/business-performance`.
- **Vehicles**: list + detail/profitability screen, matching `/vehicles` and
  `/vehicles/{id}/profitability`.
- **Rental Houses**: list + detail screen with a rent-collection dialog that posts
  directly to `/properties/{id}/rent` (this is an online-only action — rent
  collection isn't in the offline outbox's scope, see below).
- **Construction Shop**: dashboard (revenue/COGS/gross profit/net profit) plus a
  live inventory list that flags low-stock items, matching `/shop/dashboard` and
  `/shop/products`.
- **Gold-Mining Project**: dashboard with investment/expenses/revenue/net profit/ROI,
  matching `/projects/gold-mining/dashboard`.
- **Accounts**: balance list plus an inter-account transfer dialog, matching
  `/accounts` and `/accounts/transfer`.
- **Add Transaction**: the FAB from Section 25, opening a Revenue/Expense sheet.
  Every save goes into the **local outbox first** and returns immediately —
  it doesn't wait on the network. `SyncService` drains the outbox in the
  background, whether that happens instantly (online) or after reconnecting.
- **Offline sync engine** (`core/`): `local_db.dart` (SQLite schema: outbox +
  read cache + sync watermark), `outbox_repository.dart` (enqueue/mark-synced/
  mark-failed), `sync_service.dart` (connectivity-triggered push with
  exponential backoff, batch-capped at 50 to match the server's
  `SyncPushRequest` limit, plus `/sync/pull` to refresh the local cache using
  server time as the watermark rather than device time).
- **Notifications**: list + mark-read, wired to `/notifications`.
- **Settings**: profile summary, sync status (pending outbox count), sign out,
  PIN set dialog wired to `/auth/pin/set`, biometric toggle wired to
  `/auth/biometric` (see caveat below), plus entry points into the four
  modules that don't have bottom-nav slots.

### Known gap: biometric toggle state

Fixed — the backend's `/auth/me` and `/auth/biometric` now return
`biometric_enabled` and `pin_is_set`, and `AuthNotifier.refreshUser()` is
called after either changes, so Settings reflects real server state instead
of assuming "off" after every reload.

- **Session lock** (`widgets/idle_lock_gate.dart`, `screens/auth/app_lock_screen.dart`):
  a `WidgetsBindingObserver` tracks how long the app sat backgrounded; past
  `AppConfig.idleLockTimeout` (5 min), resuming shows a full-screen lock
  requiring PIN (verified server-side via `/auth/pin/verify`) or on-device
  biometrics before the app underneath is usable again. Neither unlock path
  re-runs the password/JWT login — they only confirm it's still the same
  person holding an already-valid session (Section 20).
- **Reports & Analytics** (`screens/reports/reports_screen.dart`): consolidated
  P&L + by-category breakdown, P&L by every individual asset, a 30-day
  revenue/expense line chart and a 6-month cash-flow bar chart (`fl_chart`),
  the rule-based insights feed, and receivables/payables lists — wired to
  every `/reports/*` and `/analytics/*` endpoint except export.
- **Shop sales & purchases**: `record_sale_dialog.dart` and
  `record_purchase_dialog.dart`, reachable from the Shop screen's app bar.
  Sales validate against live stock (server-enforced) and both flows post
  through the shared revenue/expense pipeline, matching `/shop/sales` and
  `/shop/purchases`.
- **Tenant management**: add/list tenants per property, built into
  `property_detail_screen.dart`, wired to `/properties/{id}/tenants`.
- **Manual lock**: `state/lock_provider.dart` holds lock state independently
  of the idle timer, so Settings has a "Lock now" action alongside the
  automatic idle-lock — both drive the same `AppLockScreen`.

## What's next (not yet built)

- Export (CSV/Excel/PDF) UI — the backend endpoint (`/reports/export`) exists;
  triggering a download and opening/sharing it from mobile needs a
  `url_launcher`/file-save flow that isn't wired up yet.
- Sales/purchases/rent-collection through the offline outbox — the outbox
  schema only queues `revenue`/`expense` right now, matching the backend's
  current `/sync/push` scope. Recording a sale, purchase, or rent payment
  works, but only online — see `record_sale_dialog.dart` /
  `record_purchase_dialog.dart` / the rent-collection flow in
  `property_detail_screen.dart`.
- A note on the idle-lock: it fires on `paused`/`inactive` → `resumed`
  transitions, which covers backgrounding the app or the OS switching apps.
  It does not currently persist `_backgroundedAt` across a full process kill
  (Android/iOS killing the app entirely rather than just backgrounding it) —
  on a fresh cold start after a kill, the session-restore flow in
  `auth_provider.dart` runs instead, which re-validates the token but does
  not force a PIN/biometric prompt. Add persisted-timestamp handling in
  `IdleLockGate` if that gap matters for your threat model.

## Running it

This environment has no Flutter SDK, no access to pub.dev, and (critically)
this project only contains the `lib/` Dart source — it has **no `android/`
or `ios/` platform folders**, since those are generated by the Flutter
tooling itself (`flutter create`), not hand-written. The code here has been
checked for import correctness, brace/paren balance, and duplicate/missing
class references by hand, but **not compiled**. To actually run it:

```bash
flutter create .                     # generates android/, ios/, etc. in place, without touching lib/ or pubspec.yaml
flutter pub get
flutter analyze                      # start here -- report back what it finds
flutter run --dart-define=API_BASE_URL=http://<your-backend-host>:8000/api/v1
```

- Android emulator talking to a backend running on your host machine:
  the default `API_BASE_URL` (`http://10.0.2.2:8000/api/v1`) already points
  at the emulator's host-loopback address, so `flutter run` with no
  `--dart-define` works out of the box against `docker compose up` from the
  backend README.
- Physical device: pass your machine's LAN IP explicitly via `--dart-define`.
- iOS simulator: `http://localhost:8000/api/v1` works directly.

Log in with the seeded admin (`admin@assetflow.local` / `ChangeMe123!`) once
the backend's `python -m app.seed` has run.

### Platform setup for biometrics

`local_auth` needs a small amount of native config beyond `pubspec.yaml`:

- **Android**: in `android/app/src/main/AndroidManifest.xml`, add
  `<uses-permission android:name="android.permission.USE_BIOMETRIC" />`, and
  make sure `MainActivity` extends `FlutterFragmentActivity` (not
  `FlutterActivity`) — `local_auth` requires it.
- **iOS**: add an `NSFaceIDUsageDescription` entry to `ios/Runner/Info.plist`.

Neither is present yet since this environment can't generate the native
`android/` and `ios/` platform folders (those come from `flutter create`,
not from hand-written Dart) — running `flutter create .` in the project root
once, before your first `flutter run`, will scaffold them.

## Project layout

```
lib/
  core/        config, api_client (JWT + refresh), secure_storage, local_db,
               outbox_repository, sync_service, theme
  models/      Dart models mirroring the backend's Pydantic schemas
  state/       Riverpod providers: auth_provider, data_providers
  screens/     one folder per feature area: auth (login + app_lock_screen),
               dashboard, vehicles, properties, shop, projects, accounts,
               reports, transactions, notifications, settings
  widgets/     nav_shell (bottom nav + Add Transaction FAB), idle_lock_gate,
               summary_card
  router.dart  go_router config with auth-based redirects
  main.dart    entrypoint, wraps the app in IdleLockGate
```
