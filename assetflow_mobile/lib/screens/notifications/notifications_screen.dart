import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../state/data_providers.dart';
import '../../widgets/app_back_button.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String type) {
    if (type.contains('rent')) return Icons.home_work_outlined;
    if (type.contains('vehicle')) return Icons.local_shipping_outlined;
    if (type.contains('inventory') || type.contains('stock')) return Icons.inventory_2_outlined;
    if (type.contains('expense')) return Icons.warning_amber_outlined;
    if (type.contains('summary')) return Icons.summarize_outlined;
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text('Notifications')),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => const Center(child: Text('Could not load notifications')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No notifications yet.', style: TextStyle(color: Colors.black54)),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return ListTile(
                  leading: Icon(_iconFor(n.type), color: n.isRead ? Colors.black38 : Colors.deepOrange),
                  title: Text(
                    n.title ?? n.type,
                    style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.w700),
                  ),
                  subtitle: Text(n.body ?? ''),
                  trailing: Text(
                    DateFormat.MMMd().add_jm().format(n.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                  onTap: () async {
                    if (!n.isRead) {
                      await ApiClient.instance.dio.patch('/notifications/${n.id}/read');
                      ref.invalidate(notificationsProvider);
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
