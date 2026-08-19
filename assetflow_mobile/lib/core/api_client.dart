import 'dart:async';

import 'package:dio/dio.dart';

import 'config.dart';
import 'secure_storage.dart';

class SessionExpiredException implements Exception {}

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.instance.getAccessToken();
          if (token != null && !options.path.contains('/auth/login')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final isAuthError = status == 401;
          final alreadyRetried = error.requestOptions.extra['authRetried'] == true;

          if (isAuthError && !alreadyRetried) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              final request = error.requestOptions;
              request.extra['authRetried'] = true;
              final token = await TokenStorage.instance.getAccessToken();
              request.headers['Authorization'] = 'Bearer $token';
              try {
                final response = await _dio.fetch(request);
                return handler.resolve(response);
              } catch (_) {
                return handler.next(error);
              }
            }

            await TokenStorage.instance.clear();
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                error: SessionExpiredException(),
                type: DioExceptionType.badResponse,
              ),
            );
          }

          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;
  Dio get dio => _dio;

  Future<Response<T>> requestWithRetry<T>(
    Future<Response<T>> Function() request, {
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    StackTrace? lastStack;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await request();
      } on DioException catch (e, st) {
        lastError = e;
        lastStack = st;
        final status = e.response?.statusCode;
        final retryable = status == null || status == 408 || status == 429 || status >= 500;
        if (!retryable || attempt == maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 700 * attempt));
      }
    }

    Error.throwWithStackTrace(lastError ?? StateError('Request failed'), lastStack ?? StackTrace.current);
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await TokenStorage.instance.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 15),
        ),
      ).post('/auth/refresh', data: {'refresh_token': refreshToken});

      final data = response.data as Map<String, dynamic>;
      await TokenStorage.instance.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
