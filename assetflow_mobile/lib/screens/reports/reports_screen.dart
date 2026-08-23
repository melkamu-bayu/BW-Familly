import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/data_providers.dart';
import '../../widgets/summary_card.dart';
import '../../widgets/app_back_button.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plAsync = ref.watch(profitLossReportProvider);
    final byAssetAsync = ref.watch(profitLossByAssetProvider);
    final trendRange = TrendRange(
      from: DateTime.now().subtract(const Duration(days: 30)),
      to: DateTime.now(),
      groupBy: 'day',
    );
    final trendAsync = ref.watch(trendReportProvider(trendRange));
    final cashFlowRange = TrendRange(
      from: DateTime.now().subtract(const Duration(days: 180)),
      to: DateTime.now(),
      groupBy: 'month',
    );
    final cashFlowAsync = ref.watch(cashFlowReportProvider(cashFlowRange));
    final insightsAsync = ref.watch(insightsProvider);
    final receivablesAsync = ref.watch(receivablesProvider);
    final payablesAsync = ref.watch(payablesProvider);

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text('Reports & Analytics')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profitLossReportProvider);
          ref.invalidate(profitLossByAssetProvider);
          ref.invalidate(trendReportProvider(trendRange));
          ref.invalidate(cashFlowReportProvider(cashFlowRange));
          ref.invalidate(insightsProvider);
          ref.invalidate(receivablesProvider);
          ref.invalidate(payablesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Profit & Loss', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            plAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => const Text('Could not load P&L report'),
              data: (report) => Column(
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      SummaryCard(label: 'Total Revenue', amount: report.consolidated.revenue, icon: Icons.trending_up),
                      SummaryCard(label: 'Total Expenses', amount: report.consolidated.expenses, icon: Icons.trending_down),
                      SummaryCard(
                        label: 'Net Profit',
                        amount: report.consolidated.profit,
                        icon: Icons.savings_outlined,
                        emphasizeSign: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...report.byCategory.map((line) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(line.label),
                          subtitle: Text(
                            'Rev ${formatCurrency(line.revenue)} · Exp ${formatCurrency(line.expenses)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            formatCurrency(line.profit),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: line.profit >= 0 ? AppTheme.profitColor : AppTheme.lossColor,
                            ),
                          ),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text('Revenue & Expense Trend (30 days)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            trendAsync.when(
              loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              error: (err, _) => const Text('Could not load trend data'),
              data: (trend) => _TrendChart(points: trend.points),
            ),
            const SizedBox(height: 28),
            const Text('Profit & Loss by Asset', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            byAssetAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => const Text('Could not load by-asset P&L'),
              data: (lines) => Column(
                children: lines
                    .map((line) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            dense: true,
                            title: Text(line.label, style: const TextStyle(fontSize: 13)),
                            trailing: Text(
                              formatCurrency(line.profit),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: line.profit >= 0 ? AppTheme.profitColor : AppTheme.lossColor,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Cash Flow (6 months)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            cashFlowAsync.when(
              loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              error: (err, _) => const Text('Could not load cash flow data'),
              data: (cashFlow) => _CashFlowChart(report: cashFlow),
            ),
            const SizedBox(height: 28),
            const Text('Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            insightsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => const Text('Could not load insights'),
              data: (insights) => Column(
                children: insights.map((insight) => _InsightTile(insight: insight)).toList(),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Receivables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            receivablesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => const Text('Could not load receivables'),
              data: (lines) {
                if (lines.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No outstanding receivables.', style: TextStyle(color: Colors.black54)),
                  );
                }
                return Column(
                  children: lines
                      .map((l) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(l.customerName),
                              trailing: Text(
                                formatCurrency(l.outstandingBalance),
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.danger),
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text('Payables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            payablesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => const Text('Could not load payables'),
              data: (lines) {
                if (lines.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No outstanding payables.', style: TextStyle(color: Colors.black54)),
                  );
                }
                return Column(
                  children: lines
                      .map((l) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.local_shipping_outlined),
                              title: Text(l.supplierName),
                              trailing: Text(
                                formatCurrency(l.outstandingPayable),
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.danger),
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<TrendPoint> points;
  const _TrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Not enough data yet.', style: TextStyle(color: Colors.black54))),
      );
    }

    final revenueSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      revenueSpots.add(FlSpot(i.toDouble(), points[i].revenue));
      expenseSpots.add(FlSpot(i.toDouble(), points[i].expense));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
        child: SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: revenueSpots,
                  isCurved: true,
                  color: AppTheme.profitColor,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: expenseSpots,
                  isCurved: true,
                  color: AppTheme.danger,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CashFlowChart extends StatelessWidget {
  final CashFlowReport report;
  const _CashFlowChart({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.points.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Not enough data yet.', style: TextStyle(color: Colors.black54))),
      );
    }

    final maxValue = report.points
        .map((p) => p.inflow > p.outflow ? p.inflow : p.outflow)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxValue == 0 ? 1 : maxValue * 1.2,
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= report.points.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              report.points[index].periodLabel,
                              style: const TextStyle(fontSize: 9, color: Colors.black54),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < report.points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(toY: report.points[i].inflow, color: AppTheme.profitColor, width: 6),
                          BarChartRodData(toY: report.points[i].outflow, color: AppTheme.danger, width: 6),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LegendDot(color: AppTheme.profitColor, label: 'Inflow'),
                _LegendDot(color: AppTheme.danger, label: 'Outflow'),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net Cash Flow', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  formatCurrency(report.netCashFlow),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: report.netCashFlow >= 0 ? AppTheme.profitColor : AppTheme.lossColor,
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  final Insight insight;
  const _InsightTile({required this.insight});

  @override
  Widget build(BuildContext context) {
    final isWarning = insight.severity == 'warning';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isWarning ? Colors.orange.shade50 : null,
      child: ListTile(
        leading: Icon(
          isWarning ? Icons.warning_amber_outlined : Icons.lightbulb_outline,
          color: isWarning ? Colors.orange : AppTheme.primary,
        ),
        title: Text(insight.text),
        dense: true,
      ),
    );
  }
}
