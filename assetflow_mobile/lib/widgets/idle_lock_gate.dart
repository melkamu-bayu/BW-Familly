import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../screens/auth/app_lock_screen.dart';
import '../state/auth_provider.dart';
import '../state/lock_provider.dart';

/// Wraps the whole app below MaterialApp.router. Tracks how long the app
/// sat in the background and, on resume, locks (via lockProvider) if that
/// duration exceeded AppConfig.idleLockTimeout (Section 20). Lock state
/// lives in lockProvider rather than local widget state so anything else
/// in the app (e.g. a manual "Lock now" action in Settings) can trigger the
/// same lock screen without reaching into this widget's internals.
///
/// This is a Stack overlay rather than a route so it works regardless of
/// where go_router's navigation stack currently is -- locking never has to
/// know or care what screen was open when the app backgrounded.
class IdleLockGate extends ConsumerStatefulWidget {
  final Widget child;
  const IdleLockGate({super.key, required this.child});

  @override
  ConsumerState<IdleLockGate> createState() => _IdleLockGateState();
}

class _IdleLockGateState extends ConsumerState<IdleLockGate> with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isAuthenticated = ref.read(authProvider).status == AuthStatus.authenticated;
    if (!isAuthenticated) return; // nothing to lock before login

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;
      if (backgroundedAt != null &&
          DateTime.now().difference(backgroundedAt) >= AppConfig.idleLockTimeout) {
        ref.read(lockProvider.notifier).lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = ref.watch(lockProvider);

    return Stack(
      children: [
        widget.child,
        if (isLocked)
          AppLockScreen(onUnlocked: () => ref.read(lockProvider.notifier).unlock()),
      ],
    );
  }
}
