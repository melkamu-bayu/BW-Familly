import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/outbox_repository.dart';
import '../../core/theme.dart';
import '../../state/auth_provider.dart';
import '../../state/lock_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showSetPinDialog(BuildContext context, WidgetRef ref) async {
    final pinController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set App PIN'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          decoration: const InputDecoration(labelText: '4-8 digit PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final pin = pinController.text;
              if (pin.length < 4) return;
              try {
                await ApiClient.instance.dio.post('/auth/pin/set', data: {'pin': pin});
                await ref.read(authProvider.notifier).refreshUser();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN set')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not set PIN'), backgroundColor: AppTheme.danger),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometric(BuildContext context, WidgetRef ref, bool enabled) async {
    try {
      await ApiClient.instance.dio.post('/auth/biometric', data: {'enabled': enabled});
      await ref.read(authProvider.notifier).refreshUser();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(enabled ? 'Biometric unlock enabled' : 'Biometric unlock disabled')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update biometric setting'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (user != null)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary,
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(user.fullName),
              subtitle: Text('${user.email} · ${user.role}'),
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('BUSINESS', style: TextStyle(fontSize: 12, color: Colors.black45, letterSpacing: 0.5)),
          ),
          ListTile(
            leading: const Icon(Icons.home_work_outlined),
            title: const Text('Rental Houses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/properties'),
          ),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Construction Shop'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/shop'),
          ),
          ListTile(
            leading: const Icon(Icons.diamond_outlined),
            title: const Text('Gold-Mining Project'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/gold-project'),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Accounts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/accounts'),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Reports & Analytics'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/reports'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('SECURITY', style: TextStyle(fontSize: 12, color: Colors.black45, letterSpacing: 0.5)),
          ),
          FutureBuilder<int>(
            future: OutboxRepository.instance.pendingCount(),
            builder: (context, snapshot) => ListTile(
              leading: const Icon(Icons.sync_outlined),
              title: const Text('Sync status'),
              subtitle: Text(
                (snapshot.data ?? 0) == 0
                    ? 'All transactions synced'
                    : '${snapshot.data} transaction(s) waiting to sync',
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: const Text('App PIN'),
            subtitle: Text(user?.pinIsSet == true ? 'PIN is set — tap to change it' : 'Set a PIN to unlock the app quickly'),
            onTap: () => _showSetPinDialog(context, ref),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Biometric unlock'),
            value: user?.biometricEnabled ?? false,
            onChanged: (enabled) => _toggleBiometric(context, ref, enabled),
          ),
          if (user?.pinIsSet == true || user?.biometricEnabled == true)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Lock now'),
              subtitle: const Text('Immediately require PIN/biometric to continue'),
              onTap: () => ref.read(lockProvider.notifier).lock(),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.danger),
            title: const Text('Sign out', style: TextStyle(color: AppTheme.danger)),
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
