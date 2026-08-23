import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/data_providers.dart';
import '../../widgets/app_back_button.dart';

class VehiclesListScreen extends ConsumerWidget {
  const VehiclesListScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
      case 'available':
      case 'working':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'out_of_service':
        return Colors.red;
      case 'sold':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text('Vehicles')),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => const Center(child: Text('Could not load vehicles')),
        data: (vehicles) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(vehiclesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vehicles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(vehicle.status).withOpacity(0.15),
                    child: Icon(Icons.local_shipping_outlined, color: _statusColor(vehicle.status)),
                  ),
                  title: Text(vehicle.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [
                      if (vehicle.plateNumber != null) vehicle.plateNumber,
                      if (vehicle.driverName != null) 'Driver: ${vehicle.driverName}',
                    ].whereType<String>().join(' · '),
                  ),
                  trailing: Chip(
                    label: Text(vehicle.status, style: const TextStyle(fontSize: 11)),
                    backgroundColor: _statusColor(vehicle.status).withOpacity(0.12),
                    side: BorderSide.none,
                  ),
                  onTap: () => context.push('/vehicles/${vehicle.id}', extra: vehicle),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
