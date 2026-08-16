import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/data_providers.dart';
import '../../widgets/summary_card.dart';
import 'record_purchase_dialog.dart';
import 'record_sale_dialog.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(shopDashboardProvider);
    final productsAsync = ref.watch(shopProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Construction Materials Shop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart_outlined),
            tooltip: 'Record Purchase',
            onPressed: () async {
              final saved = await showDialog<bool>(
                context: context,
                builder: (context) => const RecordPurchaseDialog(),
              );
              if (saved == true) {
                ref.invalidate(shopDashboardProvider);
                ref.invalidate(shopProductsProvider);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.point_of_sale),
            tooltip: 'Record Sale',
            onPressed: () async {
              final saved = await showDialog<bool>(
                context: context,
                builder: (context) => const RecordSaleDialog(),
              );
              if (saved == true) {
                ref.invalidate(shopDashboardProvider);
                ref.invalidate(shopProductsProvider);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(shopDashboardProvider);
          ref.invalidate(shopProductsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            dashboardAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => const Text('Could not load shop dashboard'),
              data: (d) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  SummaryCard(label: 'Revenue', amount: d.revenue, icon: Icons.point_of_sale_outlined),
                  SummaryCard(label: 'Gross Profit', amount: d.grossProfit, icon: Icons.trending_up),
                  SummaryCard(label: 'Operating Expenses', amount: d.operatingExpenses, icon: Icons.receipt_long),
                  SummaryCard(
                    label: 'Net Profit',
                    amount: d.netProfit,
                    icon: Icons.savings_outlined,
                    emphasizeSign: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Inventory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => const Text('Could not load products'),
              data: (products) {
                if (products.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No products yet.', style: TextStyle(color: Colors.black54))),
                  );
                }
                return Column(
                  children: products.map((p) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          Icons.inventory_2_outlined,
                          color: p.isLowStock ? AppTheme.danger : Colors.black54,
                        ),
                        title: Text(p.name),
                        subtitle: Text('${p.currentQuantity} ${p.unit} in stock · Value ${formatCurrency(p.stockValue)}'),
                        trailing: p.isLowStock
                            ? const Chip(
                                label: Text('Low stock', style: TextStyle(fontSize: 11, color: Colors.white)),
                                backgroundColor: AppTheme.danger,
                                side: BorderSide.none,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
