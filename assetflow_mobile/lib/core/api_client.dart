import 'package:dio/dio.dart';

import 'config.dart';
import 'secure_storage.dart';

/// Thrown when a request fails after a refresh attempt -- callers should
/// treat this as "session expired, send the user back to login."
class SessionExpiredException implements Exception {}

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      // 60s, not the more typical 10-15s: free-tier hosting (e.g. Render)
      // spins the backend down after ~15 min idle, and a cold start can take
      // 30-60s to respond to the first request after that. A short timeout
      // here doesn't fail faster in any useful way -- it just turns "the
      // server is waking up" into a confusing false negative.
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.instance.getAccessToken();
        if (token != null && !options.path.contains('/auth/login')) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final isAuthError = error.response?.statusCode == 401;
        final alreadyRetried = error.requestOptions.extra['retried'] == true;

        if (isAuthError && !alreadyRetried) {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            final retryOptions = error.requestOptions;
            retryOptions.extra['retried'] = true;
            final newToken = await TokenStorage.instance.getAccessToken();
            retryOptions.headers['Authorization'] = 'Bearer $newToken';
            try {
              final response = await _dio.fetch(retryOptions);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          } else {
            await TokenStorage.instance.clear();
            return handler.reject(DioException(
              requestOptions: error.requestOptions,
              error: SessionExpiredException(),
              type: DioExceptionType.badResponse,
            ));
          }
        }
        handler.next(error);
      },
    ));
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  Dio get dio => _dio;

  bool _refreshing = false;

  Future<bool> _tryRefresh() async {
    if (_refreshing) return false; // avoid concurrent refresh storms
    _refreshing = true;
    try {
      final refreshToken = await TokenStorage.instance.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)).post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data as Map<String, dynamic>;
      await TokenStorage.instance.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }
}
