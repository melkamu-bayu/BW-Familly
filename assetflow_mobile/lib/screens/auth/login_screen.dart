import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await ref.read(authProvider.notifier).login(email, password);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FBFF), Color(0xFFEAF3FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 36, 22, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  children: [
                    Image.asset('assets/assetflow_logo.png', width: 105, height: 105),
                    const SizedBox(height: 12),
                    const Text('AssetFlow', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, color: AppTheme.navy)),
                    const SizedBox(height: 3),
                    const Text('TRACK • MANAGE • GROW', style: TextStyle(fontSize: 9, letterSpacing: 2.2, fontWeight: FontWeight.w800, color: AppTheme.muted)),
                    const SizedBox(height: 34),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x160B2A66), blurRadius: 28, offset: Offset(0, 12))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Welcome Back', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.ink)),
                          const SizedBox(height: 5),
                          const Text('Sign in to continue managing your assets', style: TextStyle(color: AppTheme.muted, fontSize: 13)),
                          const SizedBox(height: 20),
                          TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.person_outline))),
                          const SizedBox(height: 12),
                          TextField(controller: _passwordController, obscureText: _obscure, onSubmitted: (_) => _submit(), decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: AppTheme.red.withOpacity(.07), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.error_outline, size: 18, color: AppTheme.red), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.red, fontSize: 12, fontWeight: FontWeight.w600)))])),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w800)))),
                          const SizedBox(height: 8),
                          Center(child: TextButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password recovery can be connected to the backend recovery endpoint.'))), child: const Text('Forgot Password?'))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Secure business and asset management', style: TextStyle(color: AppTheme.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
