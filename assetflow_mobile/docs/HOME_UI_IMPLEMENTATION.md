# AssetFlow Home UI implementation

## Design mapping

The supplied home-page design is implemented in `lib/screens/dashboard/dashboard_screen.dart`.

1. Header: AssetFlow logo/wordmark, notifications and profile.
2. Greeting: authenticated user's first name.
3. Summary strip: all-time revenue, all-time expense and all-time net profit.
4. Profit card: current-month profit plus monthly trend from `/analytics/trends` when available.
5. Quick actions: revenue and expense use the existing offline-first transaction sheet.
6. Assets overview: machines, vehicles, projects, rental properties, shop and total managed assets.
7. Recent transactions: last 60 days of revenue and expense records.
8. Bottom navigation: Home, Assets, Add, Reports, Profile.

## Backend compatibility

The current backend has a `VEHICLES` business category rather than a separate machine endpoint. The home UI therefore classifies existing vehicle records whose names/types look like excavators/heavy equipment (for example `EX-...` or `A...`) as Machines & Equipment and the remaining records as Vehicles. No backend schema change is required for this UI redesign.

The monetary figures shown by the UI are live values returned by the backend. The visual design examples in the supplied screenshot are not hard-coded as production financial values.

## Reliability changes

- Production Render API is now the default API base URL.
- API requests have bounded connect/send/receive timeouts.
- Retryable cold-start/server failures are retried with short backoff.
- Authentication 401 responses trigger token refresh and one request retry.
- Secondary home widgets fail independently so one unavailable endpoint does not blank the whole dashboard.
- Login distinguishes authentication failure from server/connectivity failure.
