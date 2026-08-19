class AppConfig {
  AppConfig._();

  /// Production API is the default so a release APK cannot accidentally use
  /// the Android emulator host URL. Override for local/staging builds with:
  /// --dart-define=API_BASE_URL=https://example.com/api/v1
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://assetflow-api-f435.onrender.com/api/v1',
  );

  static const String defaultCurrency = 'ETB';
  static const Duration idleLockTimeout = Duration(minutes: 5);
}
