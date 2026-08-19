import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/auth_provider.dart';
import '../../state/data_providers.dart';
import '../../widgets/summary_card.dart';
import '../transactions/add_transaction_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _openTransaction(
    BuildContext context,
    TransactionKind kind,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Material(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: AddTransactionSheet(kind: kind),
      ),
    );

    if (result == true && context.mounted) {
      // Dashboard providers will be refreshed when the screen
      // is rebuilt after the transaction is saved.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final performanceAsync = ref.watch(businessPerformanceProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hello, ${user?.fullName.split(' ').first ?? ''}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(businessPerformanceProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            summaryAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => _ErrorTile(
                message: 'Could not load dashboard summary',
                onRetry: () {
                  ref.invalidate(dashboardSummaryProvider);
                },
              ),
              data: (summary) {
                final isProfit = summary.monthNetProfit >= 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─────────────────────────────────────────────
                    // NET PROFIT HERO
                    // ─────────────────────────────────────────────
                    Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'NET PROFIT',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                                Icon(
                                  isProfit
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: isProfit
                                      ? AppTheme.profitColor
                                      : AppTheme.lossColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatCurrency(
                                summary.monthNetProfit,
                                currency: summary.currency,
                              ),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: isProfit
                                    ? AppTheme.profitColor
                                    : AppTheme.lossColor,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'This month',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ─────────────────────────────────────────────
                    // PRIMARY ACTIONS
                    // ─────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.add,
                            label: 'Revenue',
                            onTap: () => _openTransaction(
                              context,
                              TransactionKind.revenue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.remove,
                            label: 'Expense',
                            onTap: () => _openTransaction(
                              context,
                              TransactionKind.expense,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ─────────────────────────────────────────────
                    // TODAY
                    // ─────────────────────────────────────────────
                    const _SectionTitle(
                      title: 'Today',
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: SummaryCard(
                            label: "Today's Revenue",
                            amount: summary.todayRevenue,
                            icon: Icons.trending_up,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SummaryCard(
                            label: "Today's Expenses",
                            amount: summary.todayExpense,
                            icon: Icons.trending_down,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ─────────────────────────────────────────────
                    // FINANCIAL POSITION
                    // ─────────────────────────────────────────────
                    const _SectionTitle(
                      title: 'Financial Position',
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: SummaryCard(
                            label: 'Cash & Bank',
                            amount: summary.cashAndBankBalance,
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SummaryCard(
                            label: 'Total Profit',
                            amount: summary.allTimeNetProfit,
                            icon: Icons.savings_outlined,
                            emphasizeSign: true,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ─────────────────────────────────────────────
                    // BUSINESS PERFORMANCE
                    // ─────────────────────────────────────────────
                    Row(
                      children: [
                        const Expanded(
                          child: _SectionTitle(
                            title: 'Business Performance',
                          ),
                        ),
                        Icon(
                          Icons.insights_outlined,
                          color: AppTheme.primary,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    performanceAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => _ErrorTile(
                        message:
                            'Could not load business performance',
                        onRetry: () {
                          ref.invalidate(
                            businessPerformanceProvider,
                          );
                        },
                      ),
                      data: (lines) {
                        if (lines.isEmpty) {
                          return const _EmptyTile(
                            message:
                                'No business performance data yet',
                          );
                        }

                        return Column(
                          children: lines
                              .map(
                                (line) =>
                                    _BusinessPerformanceTile(
                                  line: line,
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 21,
        ),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _BusinessPerformanceTile extends StatelessWidget {
  final dynamic line;

  const _BusinessPerformanceTile({
    required this.line,
  });

  IconData _iconFor(String code) {
    switch (code) {
      case 'VEHICLES':
        return Icons.local_shipping_outlined;
      case 'RENTAL_HOUSES':
        return Icons.home_work_outlined;
      case 'SHOP':
        return Icons.storefront_outlined;
      case 'PROJECT':
        return Icons.construction_outlined;
      default:
        return Icons.business_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProfit = line.profit >= 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  AppTheme.primary.withOpacity(0.10),
              child: Icon(
                _iconFor(line.code as String),
                color: AppTheme.primary,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    line.category as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Revenue ${formatCurrency(line.revenue as double)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    'Expense ${formatCurrency(line.expense as double)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  formatCurrency(line.profit as double),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isProfit
                        ? AppTheme.profitColor
                        : AppTheme.lossColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${(line.percentageContribution as double).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
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
  final VoidCallback onRetry;

  const _ErrorTile({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 34,
              color: Colors.black38,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  final String message;

  const _EmptyTile({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
