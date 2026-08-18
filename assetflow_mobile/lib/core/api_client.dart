import 'package:dio/dio.dart';

import 'config.dart';
import 'secure_storage.dart';

/// Thrown when a request fails because the authenticated session
/// can no longer be refreshed.
class SessionExpiredException implements Exception {}

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,

        // Render can need time to wake up.
        // Use short individual attempts instead of one 60-second wait.
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

          // Never attach an old access token to login or refresh.
          if (token != null && !_isAuthEndpoint(options.path)) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },

        onError: (error, handler) async {
          // ---------------------------------------------------------
          // 1. RETRY TEMPORARY NETWORK/SERVER ERRORS
          // ---------------------------------------------------------

          if (_isRetryable(error) &&
              _canRetryRequest(error.requestOptions)) {
            final retryCount =
                (error.requestOptions.extra['retryCount'] as int?) ?? 0;

            // Two retries after the original attempt.
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
          // 2. HANDLE 401 / TOKEN REFRESH
          // ---------------------------------------------------------

          final isLoginRequest =
              _isLoginRequest(error.requestOptions.path);

          final isRefreshRequest =
              _isRefreshRequest(error.requestOptions.path);

          final isAuthError =
              error.response?.statusCode == 401;

          // IMPORTANT:
          //
          // Login 401 means invalid credentials.
          // Pass it directly back to auth_provider.dart.
          //
          // Refresh 401 means the refresh token is invalid/expired.
          // It must also NOT recursively enter the refresh process.
          if (isAuthError &&
              !isLoginRequest &&
              !isRefreshRequest) {
            final alreadyAuthRetried =
                error.requestOptions.extra['authRetried'] == true;

            if (!alreadyAuthRetried) {
              final refreshed = await _tryRefresh();

              if (refreshed) {
                final retryOptions = error.requestOptions;

                retryOptions.extra['authRetried'] = true;

                final newToken =
                    await TokenStorage.instance.getAccessToken();

                if (newToken == null || newToken.isEmpty) {
                  await TokenStorage.instance.clear();

                  return handler.reject(
                    DioException(
                      requestOptions: error.requestOptions,
                      error: SessionExpiredException(),
                      type: DioExceptionType.badResponse,
                    ),
                  );
                }

                retryOptions.headers['Authorization'] =
                    'Bearer $newToken';

                try {
                  final response =
                      await _dio.fetch(retryOptions);

                  return handler.resolve(response);
                } catch (retryError) {
                  if (retryError is DioException) {
                    return handler.next(retryError);
                  }

                  return handler.next(error);
                }
              }

              // Refresh failed.
              // The authenticated session is no longer valid.
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

          // Preserve the original error.
          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;

  Dio get dio => _dio;

  // -----------------------------------------------------------------
  // SINGLE-FLIGHT TOKEN REFRESH
  // -----------------------------------------------------------------
  //
  // If five API requests receive 401 simultaneously, only ONE refresh
  // request is sent. The other four requests wait for the same Future.
  //
  // This prevents refresh storms and accidental logout.

  Future<bool>? _refreshFuture;

  Future<bool> _tryRefresh() {
    final existingRefresh = _refreshFuture;

    if (existingRefresh != null) {
      return existingRefresh;
    }

    final refreshFuture = _performRefresh();

    _refreshFuture = refreshFuture;

    refreshFuture.whenComplete(() {
      if (identical(_refreshFuture, refreshFuture)) {
        _refreshFuture = null;
      }
    });

    return refreshFuture;
  }

  Future<bool> _performRefresh() async {
    try {
      final refreshToken =
          await TokenStorage.instance.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      // Separate Dio instance.
      //
      // This request does not contain the main interceptor, so the
      // refresh endpoint cannot recursively trigger another refresh.
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

      if (response.data is! Map<String, dynamic>) {
        return false;
      }

      final data =
          response.data as Map<String, dynamic>;

      final accessToken =
          data['access_token'] as String?;

      if (accessToken == null || accessToken.isEmpty) {
        return false;
      }

      // The backend may return a new refresh token.
      // If it does not, preserve the existing one.
      final newRefreshToken =
          data['refresh_token'] as String? ?? refreshToken;

      await TokenStorage.instance.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
      );

      return true;
    } on DioException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // -----------------------------------------------------------------
  // AUTH ENDPOINT DETECTION
  // -----------------------------------------------------------------

  bool _isLoginRequest(String path) {
    return path == '/auth/login' ||
        path.endsWith('/auth/login');
  }

  bool _isRefreshRequest(String path) {
    return path == '/auth/refresh' ||
        path.endsWith('/auth/refresh');
  }

  bool _isAuthEndpoint(String path) {
    return _isLoginRequest(path) ||
        _isRefreshRequest(path);
  }

  // -----------------------------------------------------------------
  // RETRY DECISION
  // -----------------------------------------------------------------

  bool _isRetryable(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;

      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;

        // Temporary upstream/server errors.
        return status == 502 ||
            status == 503 ||
            status == 504;

      default:
        return false;
    }
  }

  // -----------------------------------------------------------------
  // SAFE REQUEST RETRY
  // -----------------------------------------------------------------

  bool _canRetryRequest(RequestOptions options) {
    final method = options.method.toUpperCase();

    // Safe/idempotent requests.
    if (method == 'GET' ||
        method == 'HEAD' ||
        method == 'OPTIONS') {
      return true;
    }

    // Login is safe to retry on network/temporary server failure.
    //
    // This does NOT retry 401 because 401 is not considered retryable.
    if (_isLoginRequest(options.path)) {
      return true;
    }

    // IMPORTANT:
    //
    // Do NOT automatically retry financial transaction writes.
    //
    // If a POST succeeds on the backend but the response is lost,
    // retrying could create duplicate revenue/expense records.
    return false;
  }
}
