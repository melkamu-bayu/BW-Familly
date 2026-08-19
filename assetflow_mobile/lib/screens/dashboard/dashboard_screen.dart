import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/home_models.dart';
import '../../models/models.dart';
import '../../state/auth_provider.dart';
import '../../state/data_providers.dart';
import '../../screens/transactions/add_transaction_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeDashboardProvider);
    final trendAsync = ref.watch(homeTrendProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeDashboardProvider);
            ref.invalidate(homeTrendProvider);
            await ref.read(homeDashboardProvider.future);
          },
          child: homeAsync.when(
            loading: () => const _DashboardSkeleton(),
            error: (error, _) => _DashboardError(
              onRetry: () {
                ref.invalidate(homeDashboardProvider);
                ref.invalidate(homeTrendProvider);
              },
            ),
            data: (data) => _HomeContent(
              data: data,
              trend: trendAsync.valueOrNull,
              userName: user?.fullName.split(' ').first ?? 'there',
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final HomeDashboardData data;
  final TrendReport? trend;
  final String userName;

  const _HomeContent({required this.data, required this.trend, required this.userName});

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    final machineVehicles = data.vehicles.where(_looksLikeMachine).toList();
    final roadVehicles = data.vehicles.where((v) => !_looksLikeMachine(v)).toList();

    final machineValue = machineVehicles.fold<double>(0, (sum, v) => sum + (v.currentValue ?? v.purchasePrice ?? 0));
    final roadVehicleValue = roadVehicles.fold<double>(0, (sum, v) => sum + (v.currentValue ?? v.purchasePrice ?? 0));
    final propertyValue = data.properties.fold<double>(0, (sum, p) => sum + p.monthlyRent * 12);
    final shopValue = data.products.fold<double>(0, (sum, p) => sum + p.stockValue);
    final projectValue = data.project?.totalInvestment ?? 0;
    final managedAssetCount = data.vehicles.length + data.properties.length + (data.shop == null ? 0 : 1) + (data.project == null ? 0 : 1);

    final assets = <_AssetTileData>[
      _AssetTileData('Machines', '${machineVehicles.length} Assets', machineValue, AppTheme.orange, Icons.construction, '/vehicles'),
      _AssetTileData('Vehicles', '${roadVehicles.length} Vehicles', roadVehicleValue, AppTheme.blue, Icons.directions_car, '/vehicles'),
      _AssetTileData('Projects', data.project == null ? '0 Projects' : '1 Project', projectValue, AppTheme.green, Icons.apartment, '/gold-project'),
      _AssetTileData('Rent Properties', '${data.properties.length} Properties', propertyValue, AppTheme.purple, Icons.home_work_outlined, '/properties'),
      _AssetTileData('Shop', data.shop == null ? '0 Shops' : '1 Shop', shopValue, AppTheme.orange, Icons.storefront, '/shop'),
      _AssetTileData('Total Assets', '$managedAssetCount Managed', machineValue + roadVehicleValue + propertyValue + shopValue + projectValue, AppTheme.navy, Icons.pie_chart_outline, '/accounts'),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Header(unreadCount: data.unreadNotifications),
        const SizedBox(height: 20),
        Text(
          'Good Morning, $userName 👋',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.ink),
        ),
        const SizedBox(height: 4),
        const Text(
          "Here's what's happening with your assets today.",
          style: TextStyle(fontSize: 14, color: AppTheme.muted),
        ),
        const SizedBox(height: 18),
        _SummaryStrip(summary: summary),
        const SizedBox(height: 18),
        _ProfitCard(summary: summary, trend: trend),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Quick Actions', onViewAll: () => _showQuickActions(context)),
        const SizedBox(height: 10),
        _QuickActionsRow(),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Assets Overview',
          onViewAll: () => context.go('/assets'),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: assets.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.52,
          ),
          itemBuilder: (context, index) => _AssetCard(data: assets[index]),
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Recent Transactions', onViewAll: () => _showReports(context)),
        const SizedBox(height: 10),
        if (data.transactions.isEmpty)
          const _EmptyTransactions()
        else
          ...data.transactions.take(5).map((transaction) => _TransactionTile(transaction: transaction)),
        const SizedBox(height: 18),
      ],
    );
  }

  bool _looksLikeMachine(Vehicle v) {
    final name = v.name.toUpperCase();
    final type = (v.vehicleType ?? '').toUpperCase();
    return name.startsWith('EX-') || name.startsWith('A') || type.contains('EXCAV') || type.contains('MACHINE');
  }

  void _showQuickActions(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.arrow_downward, color: AppTheme.green),
                title: const Text('Add Income'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Future.microtask(() => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
                        builder: (_) => const AddTransactionSheet(kind: TransactionKind.revenue),
                      ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward, color: AppTheme.red),
                title: const Text('Add Expense'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Future.microtask(() => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
                        builder: (_) => const AddTransactionSheet(kind: TransactionKind.expense),
                      ));
                },
              ),
            ]),
          ),
        ),
      );

  void _showReports(BuildContext context) => context.go('/reports');
}

class _Header extends StatelessWidget {
  final int unreadCount;
  const _Header({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundButton(icon: Icons.menu, onTap: () => context.go('/settings')),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Image.asset('assets/assetflow_logo.png', width: 42, height: 42),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Roboto'),
                        children: [
                          TextSpan(text: 'Asset', style: TextStyle(color: AppTheme.navy)),
                          TextSpan(text: 'Flow', style: TextStyle(color: AppTheme.green)),
                        ],
                      ),
                    ),
                    Text('TRACK • MANAGE • GROW', style: TextStyle(fontSize: 7.5, letterSpacing: 1.3, fontWeight: FontWeight.w700, color: AppTheme.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _RoundButton(icon: Icons.notifications_none_rounded, onTap: () => context.go('/notifications')),
            if (unreadCount > 0)
              Positioned(
                right: -1,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.red, borderRadius: BorderRadius.circular(10)),
                  child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        const CircleAvatar(
          radius: 20,
          backgroundColor: Color(0xFFE7F1FF),
          child: Icon(Icons.person, color: AppTheme.blue),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1.5,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, color: AppTheme.ink)),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final DashboardSummary summary;
  const _SummaryStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _SummaryMiniCard(
            title: 'Total Revenue',
            amount: summary.allTimeRevenue,
            change: '+12.5%',
            color: AppTheme.blue,
            icon: Icons.trending_up_rounded,
          ),
          const SizedBox(width: 10),
          _SummaryMiniCard(
            title: 'Total Expense',
            amount: summary.allTimeExpense,
            change: '-8.4%',
            color: AppTheme.green,
            icon: Icons.trending_down_rounded,
          ),
          const SizedBox(width: 10),
          _SummaryMiniCard(
            title: 'Net Profit',
            amount: summary.allTimeNetProfit,
            change: summary.allTimeRevenue == 0 ? '0%' : '${(summary.allTimeNetProfit / math.max(summary.allTimeRevenue, 1) * 100).toStringAsFixed(1)}%',
            color: AppTheme.purple,
            icon: Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
    );
  }
}

class _SummaryMiniCard extends StatelessWidget {
  final String title;
  final double amount;
  final String change;
  final Color color;
  final IconData icon;

  const _SummaryMiniCard({required this.title, required this.amount, required this.change, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 166,
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF3)),
        boxShadow: const [BoxShadow(color: Color(0x090B2A66), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color.withOpacity(.10), shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const Spacer(),
          Text(formatCompactCurrency(amount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('$change from last month', style: const TextStyle(fontSize: 10, color: AppTheme.green, fontWeight: FontWeight.w600), maxLines: 1),
        ],
      ),
    );
  }
}

class _ProfitCard extends StatelessWidget {
  final DashboardSummary summary;
  final TrendReport? trend;
  const _ProfitCard({required this.summary, required this.trend});

  @override
  Widget build(BuildContext context) {
    final points = trend?.points ?? const <TrendPoint>[];
    final profit = summary.monthNetProfit;

    return Container(
      height: 205,
      padding: const EdgeInsets.fromLTRB(18, 17, 10, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0866D9), Color(0xFF1043A4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x240B2A66), blurRadius: 22, offset: Offset(0, 10))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Net Profit This Month', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(14)),
                      child: const Text('This Month ⌄', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(formatCompactCurrency(profit), style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('↗ ${summary.allTimeRevenue == 0 ? '0.0' : (profit / math.max(summary.allTimeRevenue, 1) * 100).toStringAsFixed(1)}% vs last month', style: const TextStyle(color: Color(0xFFB7F6D0), fontSize: 11, fontWeight: FontWeight.w700)),
                const Spacer(),
                Material(
                  color: Colors.white.withOpacity(.13),
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () => context.go('/reports'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.bar_chart_rounded, size: 15, color: Colors.white), SizedBox(width: 6), Text('View Full Report', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(flex: 5, child: _ProfitChart(points: points, fallbackProfit: profit)),
        ],
      ),
    );
  }
}

class _ProfitChart extends StatelessWidget {
  final List<TrendPoint> points;
  final double fallbackProfit;
  const _ProfitChart({required this.points, required this.fallbackProfit});

  @override
  Widget build(BuildContext context) {
    final chartPoints = points.isEmpty
        ? [
            FlSpot(0, fallbackProfit * .55),
            FlSpot(1, fallbackProfit * .72),
            FlSpot(2, fallbackProfit * .65),
            FlSpot(3, fallbackProfit),
          ]
        : points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.profit)).toList();

    final maxY = math.max(1.0, chartPoints.map((e) => e.y).reduce((a, b) => math.max(a, b)) * 1.25);
    final minY = math.min(0.0, chartPoints.map((e) => e.y).reduce((a, b) => math.min(a, b)) * 1.15);

    return Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 2),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          minX: 0,
          maxX: math.max(3, chartPoints.length - 1).toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: maxY == 0 ? 1 : maxY / 3,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(.08), strokeWidth: 1),
            getDrawingVerticalLine: (_) => FlLine(color: Colors.white.withOpacity(.07), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(_shortAmount(value), style: const TextStyle(color: Colors.white70, fontSize: 8)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 18,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  final label = points[i].periodLabel;
                  return Padding(padding: const EdgeInsets.only(top: 5), child: Text(label.length > 3 ? label.substring(0, 3) : label, style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w600)));
                },
              ),
            ),
          ),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: chartPoints,
              isCurved: true,
              barWidth: 2.5,
              color: Colors.white,
              dotData: FlDotData(show: chartPoints.length <= 6),
              belowBarData: BarAreaData(show: true, color: Colors.white.withOpacity(.10)),
            ),
          ],
        ),
      ),
    );
  }

  String _shortAmount(double value) {
    final abs = value.abs();
    if (abs >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;
  const _SectionHeader({required this.title, required this.onViewAll});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink))),
          TextButton(onPressed: onViewAll, child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
      );
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Add Income', Icons.arrow_downward_rounded, AppTheme.green, TransactionKind.revenue),
      ('Add Expense', Icons.arrow_upward_rounded, AppTheme.red, TransactionKind.expense),
      ('Add Asset', Icons.business_center_outlined, AppTheme.blue, null),
      ('Add Project', Icons.apartment_rounded, AppTheme.purple, null),
      ('Transfer', Icons.swap_horiz_rounded, AppTheme.orange, null),
    ];

    return SizedBox(
      height: 105,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final action = actions[index];
          return _QuickActionCard(
            label: action.$1,
            icon: action.$2,
            color: action.$3,
            onTap: () {
              if (action.$4 != null) {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
                  builder: (_) => AddTransactionSheet(kind: action.$4!),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${action.$1} is available from the Assets/Add section.')));
              }
            },
          );
        },
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionCard({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 94,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(17),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE8ECF3))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(.10), shape: BoxShape.circle), child: Icon(icon, color: color, size: 19)),
                  const SizedBox(height: 7),
                  Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _AssetTileData {
  final String title;
  final String subtitle;
  final double value;
  final Color color;
  final IconData icon;
  final String route;
  const _AssetTileData(this.title, this.subtitle, this.value, this.color, this.icon, this.route);
}

class _AssetCard extends StatelessWidget {
  final _AssetTileData data;
  const _AssetCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final progress = (data.value / 10000000).clamp(.08, 1.0).toDouble();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => context.go(data.route),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE8ECF3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 34, height: 34, decoration: BoxDecoration(color: data.color.withOpacity(.10), shape: BoxShape.circle), child: Icon(data.icon, color: data.color, size: 18)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(data.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.ink))),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(child: Text(data.subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.muted))),
                  Flexible(child: Text(formatCompactCurrency(data.value), textAlign: TextAlign.end, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.ink))),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: data.color.withOpacity(.10), valueColor: AlwaysStoppedAnimation(data.color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final RecentTransaction transaction;
  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final color = transaction.isIncome ? AppTheme.green : AppTheme.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE8ECF3))),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(.11), shape: BoxShape.circle), child: Icon(transaction.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: color, size: 19)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(transaction.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.ink)),
              const SizedBox(height: 2),
              Text(transaction.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${transaction.isIncome ? '+' : '-'} ${formatCompactCurrency(transaction.amount)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(DateFormat('MMM d, HH:mm').format(transaction.date), style: const TextStyle(fontSize: 9.5, color: AppTheme.muted)),
          ]),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE8ECF3))),
        child: const Column(children: [Icon(Icons.receipt_long_outlined, color: AppTheme.muted), SizedBox(height: 8), Text('No recent transactions', style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600))]),
      );
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const SizedBox(height: 50),
        ...List.generate(6, (i) => Container(margin: const EdgeInsets.only(bottom: 12), height: i == 2 ? 190 : 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)))),
      ]);
}

class _DashboardError extends StatelessWidget {
  final VoidCallback onRetry;
  const _DashboardError({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 46, color: AppTheme.muted),
            const SizedBox(height: 12),
            const Text('We could not load your dashboard.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink)),
            const SizedBox(height: 6),
            const Text('The API may be waking up. Try again in a moment.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 18),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ]),
        ),
      );
}

String formatCompactCurrency(double value) {
  final sign = value < 0 ? '-' : '';
  final n = value.abs();
  if (n >= 1000000000) return '$sign ETB ${(n / 1000000000).toStringAsFixed(1)}B';
  if (n >= 1000000) return '$sign ETB ${(n / 1000000).toStringAsFixed(n >= 10000000 ? 1 : 2)}M';
  if (n >= 1000) return '$sign ETB ${(n / 1000).toStringAsFixed(n >= 100000 ? 0 : 1)}K';
  return '$sign ETB ${NumberFormat('#,##0').format(n)}';
}
