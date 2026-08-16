import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'router.dart';
import 'widgets/idle_lock_gate.dart';

void main() {
  runApp(const ProviderScope(child: AssetFlowApp()));
}

class AssetFlowApp extends ConsumerWidget {
  const AssetFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'AssetFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => IdleLockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
