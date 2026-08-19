# AssetFlow Mobile

AssetFlow is a Flutter mobile application for managing business revenue, expenses, vehicles/machines, rental properties, construction-material shop inventory, projects and reports.

## Home screen redesign

The home screen is implemented to match the supplied AssetFlow design:

- AssetFlow blue/green branding
- Greeting and account header
- Revenue / expense / net-profit cards
- Monthly net-profit chart
- Quick actions
- Machines / vehicles / projects / rental properties / shop / total managed assets
- Recent transactions
- Five-item bottom navigation: Home, Assets, Add, Reports, Profile

## Production API

The production API is the default:

`https://assetflow-api-f435.onrender.com/api/v1`

You can override it for another environment:

```bash
flutter run --dart-define=API_BASE_URL=https://example.com/api/v1
```

## Build

```bash
flutter pub get
flutter analyze
flutter build apk --release --dart-define=API_BASE_URL=https://assetflow-api-f435.onrender.com/api/v1
```

The repository workflow can create the Android wrapper automatically when the `android/` directory is absent.
