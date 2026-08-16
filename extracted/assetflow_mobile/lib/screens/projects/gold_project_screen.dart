import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/data_providers.dart';
import '../../widgets/summary_card.dart';

class GoldProjectScreen extends ConsumerWidget {
  const GoldProjectScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'planning':
        return Colors.blue;
      case 'suspended':
        return Colors.orange;
      case 'completed':
        return AppTheme.accent;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(goldProjectDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gold-Mining Project')),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => const Center(child: Text('Could not load project dashboard')),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(goldProjectDashboardProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Chip(
                label: Text(d.status),
                backgroundColor: _statusColor(d.status).withOpacity(0.15),
                side: BorderSide.none,
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  SummaryCard(label: 'Total Investment', amount: d.totalInvestment, icon: Icons.account_balance_outlined),
                  SummaryCard(label: 'Total Expenses', amount: d.totalExpenses, icon: Icons.trending_down),
                  SummaryCard(label: 'Total Revenue', amount: d.totalRevenue, icon: Icons.trending_up),
                  SummaryCard(
                    label: 'Net Profit/Loss',
                    amount: d.netProfit,
                    icon: Icons.savings_outlined,
                    emphasizeSign: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ROI', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        d.roi == null ? 'N/A' : '${d.roi!.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: (d.roi ?? 0) >= 0 ? AppTheme.profitColor : AppTheme.lossColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
