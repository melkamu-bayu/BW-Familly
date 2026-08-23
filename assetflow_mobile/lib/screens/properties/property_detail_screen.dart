import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/data_providers.dart';
import '../../widgets/summary_card.dart';
import '../../widgets/app_back_button.dart';

class PropertyDetailScreen extends ConsumerWidget {
  final String propertyId;
  final Property? property;

  const PropertyDetailScreen({super.key, required this.propertyId, this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(propertyDashboardProvider(propertyId));

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text(property?.name ?? 'Property')),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => const Center(child: Text('Could not load property dashboard')),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(propertyDashboardProvider(propertyId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Chip(label: Text(d.occupancyStatus)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  SummaryCard(label: 'Monthly Rent', amount: d.monthlyRent, icon: Icons.calendar_month_outlined),
                  SummaryCard(label: 'Collected Rent', amount: d.collectedRent, icon: Icons.payments_outlined),
                  SummaryCard(
                    label: 'Outstanding Rent',
                    amount: d.outstandingRent,
                    icon: Icons.warning_amber_outlined,
                    emphasizeSign: false,
                  ),
                  SummaryCard(
                    label: 'Net Rental Profit',
                    amount: d.netRentalProfit,
                    icon: Icons.savings_outlined,
                    emphasizeSign: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Collect Rent'),
                onPressed: () => _showCollectRentDialog(context, ref, d),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tenant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_outlined),
                    tooltip: 'Add tenant',
                    onPressed: () => _showAddTenantDialog(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _TenantSection(propertyId: propertyId),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTenantDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tenant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                await ApiClient.instance.dio.post('/properties/$propertyId/tenants', data: {
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ref.invalidate(tenantsProvider(propertyId));
                  ref.invalidate(propertyDashboardProvider(propertyId));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not add tenant'), backgroundColor: AppTheme.danger),
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

  Future<void> _showCollectRentDialog(BuildContext context, WidgetRef ref, PropertyDashboard dashboard) async {
    final amountController = TextEditingController(text: dashboard.monthlyRent.toStringAsFixed(2));
    final accountsAsync = ref.read(accountsProvider);
    String? selectedAccountId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Collect Rent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount Paid (ETB)'),
              ),
              const SizedBox(height: 12),
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => const Text('Could not load accounts'),
                data: (accounts) => DropdownButtonFormField<String>(
                  value: selectedAccountId,
                  decoration: const InputDecoration(labelText: 'Deposit to Account'),
                  items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                  onChanged: (v) => setState(() => selectedAccountId = v),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedAccountId == null) return;
                final now = DateTime.now();
                final periodMonth = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;

                try {
                  await ApiClient.instance.dio.post('/properties/$propertyId/rent', data: {
                    'tenant_id': null,
                    'period_month': periodMonth,
                    'amount_due': dashboard.monthlyRent,
                    'amount_paid': double.tryParse(amountController.text) ?? 0,
                    'account_id': selectedAccountId,
                    'idempotency_key': const Uuid().v4(),
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ref.invalidate(propertyDashboardProvider(propertyId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rent recorded')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not record rent payment'), backgroundColor: AppTheme.danger),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantSection extends ConsumerWidget {
  final String propertyId;
  const _TenantSection({required this.propertyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(tenantsProvider(propertyId));
    return tenantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => const Text('Could not load tenants'),
      data: (tenants) {
        if (tenants.isEmpty) {
          return const Text('No tenant on record.', style: TextStyle(color: Colors.black54));
        }
        return Column(
          children: tenants
              .map((t) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(Icons.person_outline, color: t.active ? AppTheme.primary : Colors.black38),
                      title: Text(t.name),
                      subtitle: Text(t.phone ?? 'No phone on record'),
                      trailing: t.active ? const Chip(label: Text('Active')) : null,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}
