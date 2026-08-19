import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/data_providers.dart';

class AssetsHubScreen extends ConsumerWidget {
  const AssetsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider);
    final properties = ref.watch(propertiesProvider);
    final products = ref.watch(shopProductsProvider);
    final project = ref.watch(goldProjectDashboardProvider);
    final shop = ref.watch(shopDashboardProvider);

    final lowStock = shop.valueOrNull?.lowStockCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Assets', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Text('Manage everything that generates value for your business.', style: TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 18),
          _HubCard(icon: Icons.construction, color: AppTheme.orange, title: 'Machines & Equipment', subtitle: 'Excavators and heavy equipment', onTap: () => context.go('/vehicles')),
          _HubCard(icon: Icons.directions_car, color: AppTheme.blue, title: 'Vehicles', subtitle: 'Cars, trucks and transport assets', onTap: () => context.go('/vehicles')),
          _HubCard(icon: Icons.home_work_outlined, color: AppTheme.purple, title: 'Rent Properties', subtitle: 'Houses, tenants and rent collection', onTap: () => context.go('/properties')),
          _HubCard(icon: Icons.storefront, color: AppTheme.orange, title: 'Construction Materials Shop', subtitle: 'Inventory, purchases and sales', onTap: () => context.go('/shop')),
          _HubCard(icon: Icons.apartment, color: AppTheme.green, title: 'Gold-Mining Project', subtitle: 'Investment, revenue, expenses and ROI', onTap: () => context.go('/gold-project')),
          const SizedBox(height: 12),
          const Text('Live overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _StatCard(label: 'Vehicles', value: vehicles.valueOrNull?.length.toString() ?? '—', icon: Icons.directions_car, color: AppTheme.blue)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: 'Properties', value: properties.valueOrNull?.length.toString() ?? '—', icon: Icons.home, color: AppTheme.purple)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _StatCard(label: 'Products', value: products.valueOrNull?.length.toString() ?? '—', icon: Icons.inventory_2_outlined, color: AppTheme.orange)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: 'Project ROI', value: project.valueOrNull?.roi == null ? '—' : '${project.valueOrNull!.roi!.toStringAsFixed(1)}%', icon: Icons.trending_up, color: AppTheme.green)),
          ]),
          if (lowStock != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.orange.withOpacity(.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.orange.withOpacity(.18))),
              child: Row(children: [const Icon(Icons.warning_amber_rounded, color: AppTheme.orange), const SizedBox(width: 10), Expanded(child: Text('$lowStock shop products are at or below minimum stock.', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink)))]),
            ),
          ],
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _HubCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8ECF3))),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          leading: Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withOpacity(.10), shape: BoxShape.circle), child: Icon(icon, color: color)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink)),
          subtitle: Padding(padding: const EdgeInsets.only(top: 3), child: Text(subtitle, style: const TextStyle(color: AppTheme.muted, fontSize: 12))),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
        ),
      );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE8ECF3))),
        child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withOpacity(.10), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.muted)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink))]))]),
      );
}
