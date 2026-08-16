import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/auth_provider.dart';
import '../../state/data_providers.dart';
import '../../widgets/summary_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final performanceAsync = ref.watch(businessPerformanceProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${user?.fullName.split(' ').first ?? ''}'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(businessPerformanceProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            summaryAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => _ErrorTile(message: 'Could not load dashboard summary'),
              data: (summary) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Net Profit (This Month)', style: TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    formatCurrency(summary.monthNetProfit, currency: summary.currency),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: summary.monthNetProfit >= 0 ? AppTheme.profitColor : AppTheme.lossColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      SummaryCard(label: "Today's Revenue", amount: summary.todayRevenue, icon: Icons.trending_up),
                      SummaryCard(label: "Today's Expenses", amount: summary.todayExpense, icon: Icons.trending_down),
                      SummaryCard(label: 'Total Revenue', amount: summary.allTimeRevenue, icon: Icons.stacked_line_chart),
                      SummaryCard(label: 'Total Expenses', amount: summary.allTimeExpense, icon: Icons.receipt_long),
                      SummaryCard(
                        label: 'Cash & Bank Balance',
                        amount: summary.cashAndBankBalance,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      SummaryCard(
                        label: 'Total Net Profit',
                        amount: summary.allTimeNetProfit,
                        icon: Icons.savings_outlined,
                        emphasizeSign: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text('Business Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            performanceAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _ErrorTile(message: 'Could not load business performance'),
              data: (lines) => Column(
                children: lines.map((line) => _BusinessPerformanceTile(line: line)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessPerformanceTile extends StatelessWidget {
  final dynamic line; // BusinessPerformanceLine
  const _BusinessPerformanceTile({required this.line});

  IconData _iconFor(String code) {
    switch (code) {
      case 'VEHICLES':
        return Icons.local_shipping_outlined;
      case 'RENTAL_HOUSES':
        return Icons.home_work_outlined;
      case 'SHOP':
        return Icons.storefront_outlined;
      case 'PROJECT':
        return Icons.diamond_outlined;
      default:
        return Icons.business_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProfit = line.profit >= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: Icon(_iconFor(line.code as String), color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.category as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    'Rev ${formatCurrency(line.revenue as double)} · Exp ${formatCurrency(line.expense as double)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCurrency(line.profit as double),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isProfit ? AppTheme.profitColor : AppTheme.lossColor,
                  ),
                ),
                Text(
                  '${(line.percentageContribution as double).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String message;
  const _ErrorTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off, color: Colors.black38, size: 32),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
