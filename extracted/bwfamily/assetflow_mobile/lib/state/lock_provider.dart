import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the app is currently showing the PIN/biometric lock screen.
/// This is separate from AuthState: a locked-but-authenticated user still
/// has a valid JWT and a valid local session -- they just haven't proven
/// physical presence recently enough (Section 20 session timeout).
class LockNotifier extends StateNotifier<bool> {
  LockNotifier() : super(false);

  void lock() => state = true;
  void unlock() => state = false;
}

final lockProvider = StateNotifierProvider<LockNotifier, bool>((ref) => LockNotifier());
