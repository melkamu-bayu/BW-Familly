import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/data_providers.dart';
import '../../widgets/summary_card.dart';

class VehicleDetailScreen extends ConsumerWidget {
  final String vehicleId;
  final Vehicle? vehicle;

  const VehicleDetailScreen({super.key, required this.vehicleId, this.vehicle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profitabilityAsync = ref.watch(vehicleProfitabilityProvider(vehicleId));

    return Scaffold(
      appBar: AppBar(title: Text(vehicle?.name ?? 'Vehicle')),
      body: profitabilityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => const Center(child: Text('Could not load vehicle profitability')),
        data: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (vehicle?.plateNumber != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('Plate: ${vehicle!.plateNumber}', style: const TextStyle(color: Colors.black54)),
              ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                SummaryCard(label: 'Revenue', amount: p.revenue, icon: Icons.trending_up),
                SummaryCard(label: 'Expenses', amount: p.expenses, icon: Icons.trending_down),
                SummaryCard(label: 'Profit', amount: p.profit, icon: Icons.savings_outlined, emphasizeSign: true),
                SummaryCard(label: 'Mileage (km)', amount: p.mileage, icon: Icons.speed_outlined),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Per-kilometer rates', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _RateRow(label: 'Cost per km', value: p.costPerKm),
                    _RateRow(label: 'Profit per km', value: p.profitPerKm),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  final String label;
  final double? value;
  const _RateRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value == null ? '—' : 'ETB ${value!.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}
