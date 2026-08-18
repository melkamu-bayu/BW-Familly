import 'package:dio/dio.dart';

import 'config.dart';
import 'secure_storage.dart';

/// Thrown when a request fails after a refresh attempt.
/// The application should treat this as an expired session.
class SessionExpiredException implements Exception {}

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,

        // Short individual attempts.
        // Render may need time to wake up, so transient requests
        // are retried instead of blocking the UI for 60 seconds.
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token =
              await TokenStorage.instance.getAccessToken();

          if (token != null && !options.path.contains('/auth/login')) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },

        onError: (error, handler) async {
          // ---------------------------------------------------------
          // 1. RETRY TRANSIENT NETWORK/SERVER ERRORS
          // ---------------------------------------------------------

          if (_isRetryable(error) &&
              _canRetryRequest(error.requestOptions)) {
            final retryCount =
                (error.requestOptions.extra['retryCount'] as int?) ?? 0;

            // Maximum 2 automatic retries.
            if (retryCount < 2) {
              final nextRetry = retryCount + 1;

              error.requestOptions.extra['retryCount'] = nextRetry;

              // Give Render time to wake up.
              final delay = Duration(
                milliseconds: nextRetry == 1 ? 1200 : 3000,
              );

              await Future<void>.delayed(delay);

              try {
                final response =
                    await _dio.fetch(error.requestOptions);

                return handler.resolve(response);
              } catch (retryError) {
                if (retryError is DioException) {
                  return handler.next(retryError);
                }

                return handler.next(error);
              }
            }
          }

          // ---------------------------------------------------------
          // 2. HANDLE HTTP 401 / TOKEN REFRESH
          // ---------------------------------------------------------

          final isAuthError =
              error.response?.statusCode == 401;

          final alreadyAuthRetried =
              error.requestOptions.extra['authRetried'] == true;

          if (isAuthError && !alreadyAuthRetried) {
            final refreshed = await _tryRefresh();

            if (refreshed) {
              final retryOptions = error.requestOptions;

              retryOptions.extra['authRetried'] = true;

              final newToken =
                  await TokenStorage.instance.getAccessToken();

              retryOptions.headers['Authorization'] =
                  'Bearer $newToken';

              try {
                final response =
                    await _dio.fetch(retryOptions);

                return handler.resolve(response);
              } catch (_) {
                return handler.next(error);
              }
            } else {
              // Refresh failed.
              // Clear local session so the application can
              // redirect the user to login.
              await TokenStorage.instance.clear();

              return handler.reject(
                DioException(
                  requestOptions: error.requestOptions,
                  error: SessionExpiredException(),
                  type: DioExceptionType.badResponse,
                ),
              );
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;

  Dio get dio => _dio;

  // Prevent multiple simultaneous refresh requests.
  bool _refreshing = false;

  // ---------------------------------------------------------------
  // DETERMINE WHETHER AN ERROR IS SAFE TO RETRY
  // ---------------------------------------------------------------

  bool _isRetryable(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;

      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;

        // Common temporary errors from hosted services.
        return status == 502 ||
            status == 503 ||
            status == 504;

      default:
        return false;
    }
  }

  // ---------------------------------------------------------------
  // ONLY RETRY SAFE REQUESTS
  // ---------------------------------------------------------------

  bool _canRetryRequest(RequestOptions options) {
    final method = options.method.toUpperCase();

    // Safe/idempotent requests.
    if (method == 'GET' ||
        method == 'HEAD' ||
        method == 'OPTIONS') {
      return true;
    }

    // Login can safely be retried because it does not create
    // a financial transaction.
    if (options.path == '/auth/login') {
      return true;
    }

    // IMPORTANT:
    // Do NOT automatically retry POST/PUT/PATCH/DELETE
    // transaction requests because a timeout could happen
    // after the backend already processed the transaction.
    return false;
  }

  // ---------------------------------------------------------------
  // TOKEN REFRESH
  // ---------------------------------------------------------------

  Future<bool> _tryRefresh() async {
    // Avoid simultaneous refresh storms.
    if (_refreshing) {
      return false;
    }

    _refreshing = true;

    try {
      final refreshToken =
          await TokenStorage.instance.getRefreshToken();

      if (refreshToken == null) {
        return false;
      }

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final response = await refreshDio.post(
        '/auth/refresh',
        data: {
          'refresh_token': refreshToken,
        },
      );

      final data =
          response.data as Map<String, dynamic>;

      await TokenStorage.instance.saveTokens(
        accessToken:
            data['access_token'] as String,
        refreshToken:
            data['refresh_token'] as String,
      );

      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }
}
