import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/summary_card.dart';
import '../../state/data_providers.dart';

class PropertiesListScreen extends ConsumerWidget {
  const PropertiesListScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'occupied':
        return Colors.green;
      case 'vacant':
        return Colors.orange;
      case 'maintenance':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(propertiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rental Houses')),
      body: propertiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => const Center(child: Text('Could not load properties')),
        data: (properties) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(propertiesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: properties.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final property = properties[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(property.status).withOpacity(0.15),
                    child: Icon(Icons.home_work_outlined, color: _statusColor(property.status)),
                  ),
                  title: Text(property.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Rent: ${formatCurrency(property.monthlyRent)} / month'),
                  trailing: Chip(
                    label: Text(property.status, style: const TextStyle(fontSize: 11)),
                    backgroundColor: _statusColor(property.status).withOpacity(0.12),
                    side: BorderSide.none,
                  ),
                  onTap: () => context.push('/properties/${property.id}', extra: property),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
