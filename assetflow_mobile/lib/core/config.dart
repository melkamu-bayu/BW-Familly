class AppConfig {
  AppConfig._();

  /// Points at the AssetFlow backend built in the previous phases.
  /// Override with --dart-define=API_BASE_URL=... for staging/prod builds.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1', // 10.0.2.2 = Android emulator's host-machine loopback
  );

  static const String defaultCurrency = 'ETB';

  /// How long the app can sit in the background before requiring
  /// PIN/biometric re-unlock (Section 20 session timeout).
  static const Duration idleLockTimeout = Duration(minutes: 5);
}
