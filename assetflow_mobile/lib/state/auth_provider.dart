import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/secure_storage.dart';
import '../core/sync_service.dart';
import '../models/models.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final CurrentUser? user;

  const AuthState({required this.status, this.user});

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);
  const AuthState.authenticated(CurrentUser user) : this(status: AuthStatus.authenticated, user: user);

  /// Mirrors the RBAC matrix from the backend's Section 19 role table, used
  /// only to decide which nav items/FABs to *show* -- the server remains the
  /// real enforcement point (require_permission on every endpoint).
  bool get canManageAssets => user?.role == 'super_admin' || user?.role == 'manager';
  bool get canRecordTransactions =>
      const ['super_admin', 'manager', 'accountant', 'staff'].contains(user?.role);
  bool get isViewer => user?.role == 'viewer';
  bool get isAdmin => user?.role == 'super_admin';
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState.unknown()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await TokenStorage.instance.getAccessToken();
    if (token == null) {
      state = const AuthState.unauthenticated();
      return;
    }
    try {
      final response = await ApiClient.instance.dio.get('/auth/me');
      state = AuthState.authenticated(CurrentUser.fromJson(response.data as Map<String, dynamic>));
      SyncService.instance.start();
    } catch (_) {
      await TokenStorage.instance.clear();
      state = const AuthState.unauthenticated();
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final response = await ApiClient.instance.requestWithRetry(() => ApiClient.instance.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      }));
      final data = response.data as Map<String, dynamic>;
      await TokenStorage.instance.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );

      final meResponse = await ApiClient.instance.dio.get('/auth/me');
      state = AuthState.authenticated(CurrentUser.fromJson(meResponse.data as Map<String, dynamic>));
      SyncService.instance.start();
      return null; // no error
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return 'Incorrect email or password.';
      if (e.response?.statusCode == 403) return 'Your account is not allowed to sign in.';
      if (e.response?.statusCode == 404) return 'Authentication service was not found.';
      return 'Unable to reach AssetFlow server. Please try again.';
    } catch (_) {
      return 'Unable to sign in. Please try again.';
    }
  }

  Future<void> logout() async {
    final refreshToken = await TokenStorage.instance.getRefreshToken();
    if (refreshToken != null) {
      try {
        await ApiClient.instance.dio.post('/auth/logout', data: {'refresh_token': refreshToken});
      } catch (_) {
        // best-effort server-side revoke; local logout proceeds regardless
      }
    }
    await TokenStorage.instance.clear();
    state = const AuthState.unauthenticated();
  }

  /// Re-fetches /auth/me and updates state -- call after anything that
  /// changes server-side user fields (biometric toggle, PIN set) so the UI
  /// reflects reality instead of a stale cached CurrentUser.
  Future<void> refreshUser() async {
    if (state.status != AuthStatus.authenticated) return;
    try {
      final response = await ApiClient.instance.dio.get('/auth/me');
      state = AuthState.authenticated(CurrentUser.fromJson(response.data as Map<String, dynamic>));
    } catch (_) {
      // Leave state as-is; the next natural request will surface any real auth problem.
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
