import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../state/auth_provider.dart';

/// Full-screen lock shown when the app returns to the foreground after
/// sitting in the background longer than AppConfig.idleLockTimeout
/// (Section 20 session timeout). Unlock never re-authenticates against
/// the password/JWT flow -- it only confirms the person holding the device
/// is still the one who's already logged in, via PIN (verified server-side
/// against /auth/pin/verify) or on-device biometrics.
class AppLockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  final _pinController = TextEditingController();
  final _localAuth = LocalAuthentication();
  String? _error;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user?.biometricEnabled == true) {
      // Offer biometric immediately rather than waiting for a tap.
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return;
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock AssetFlow',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (authenticated) widget.onUnlocked();
    } catch (_) {
      // Fall through to PIN entry -- biometric hardware/cancellation errors
      // shouldn't strand the user with no way to unlock.
    }
  }

  Future<void> _verifyPin() async {
    if (_pinController.text.isEmpty) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ApiClient.instance.dio.post('/auth/pin/verify', data: {'pin': _pinController.text});
      widget.onUnlocked();
    } catch (e) {
      setState(() => _error = 'Incorrect PIN');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Welcome back${user != null ? ', ${user.fullName.split(' ').first}' : ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                if (user?.pinIsSet == true) ...[
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      maxLength: 8,
                      style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                      decoration: const InputDecoration(counterText: '', border: UnderlineInputBorder()),
                      onSubmitted: (_) => _verifyPin(),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _verifying ? null : _verifyPin,
                    child: _verifying
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Unlock'),
                  ),
                ] else
                  const Text(
                    'No PIN set for this account -- set one in Settings for quick unlock.\nSigning out and back in will also clear this lock.',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                if (user?.biometricEnabled == true) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _tryBiometric,
                    icon: const Icon(Icons.fingerprint, color: Colors.white),
                    label: const Text('Use biometrics', style: TextStyle(color: Colors.white)),
                  ),
                ],
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  child: const Text('Sign out instead', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }
}
