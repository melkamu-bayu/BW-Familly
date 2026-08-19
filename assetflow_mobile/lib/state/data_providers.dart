import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/models.dart';
import '../models/home_models.dart';

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final response = await ApiClient.instance.dio.get('/dashboard/summary');
  return DashboardSummary.fromJson(response.data as Map<String, dynamic>);
});

final businessPerformanceProvider = FutureProvider.autoDispose<List<BusinessPerformanceLine>>((ref) async {
  final response = await ApiClient.instance.dio.get('/dashboard/business-performance');
  return (response.data as List)
      .map((e) => BusinessPerformanceLine.fromJson(e as Map<String, dynamic>))
      .toList();
});

final vehiclesProvider = FutureProvider.autoDispose<List<Vehicle>>((ref) async {
  final response = await ApiClient.instance.dio.get('/vehicles');
  return (response.data as List).map((e) => Vehicle.fromJson(e as Map<String, dynamic>)).toList();
});

final vehicleProfitabilityProvider =
    FutureProvider.autoDispose.family<VehicleProfitability, String>((ref, vehicleId) async {
  final response = await ApiClient.instance.dio.get('/vehicles/$vehicleId/profitability');
  return VehicleProfitability.fromJson(response.data as Map<String, dynamic>);
});

final accountsProvider = FutureProvider.autoDispose<List<Account>>((ref) async {
  final response = await ApiClient.instance.dio.get('/accounts');
  return (response.data as List).map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
});

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final response = await ApiClient.instance.dio.get('/notifications');
  return (response.data as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
});

final propertiesProvider = FutureProvider.autoDispose<List<Property>>((ref) async {
  final response = await ApiClient.instance.dio.get('/properties');
  return (response.data as List).map((e) => Property.fromJson(e as Map<String, dynamic>)).toList();
});

final propertyDashboardProvider =
    FutureProvider.autoDispose.family<PropertyDashboard, String>((ref, propertyId) async {
  final response = await ApiClient.instance.dio.get('/properties/$propertyId/dashboard');
  return PropertyDashboard.fromJson(response.data as Map<String, dynamic>);
});

final tenantsProvider = FutureProvider.autoDispose.family<List<Tenant>, String>((ref, propertyId) async {
  final response = await ApiClient.instance.dio.get('/properties/$propertyId/tenants');
  return (response.data as List).map((e) => Tenant.fromJson(e as Map<String, dynamic>)).toList();
});

final customersProvider = FutureProvider.autoDispose<List<Customer>>((ref) async {
  final response = await ApiClient.instance.dio.get('/shop/customers');
  return (response.data as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
});

final suppliersProvider = FutureProvider.autoDispose<List<Supplier>>((ref) async {
  final response = await ApiClient.instance.dio.get('/shop/suppliers');
  return (response.data as List).map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList();
});

final shopProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final response = await ApiClient.instance.dio.get('/shop/products');
  return (response.data as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
});

final shopDashboardProvider = FutureProvider.autoDispose<ShopDashboard>((ref) async {
  final response = await ApiClient.instance.dio.get('/shop/dashboard');
  return ShopDashboard.fromJson(response.data as Map<String, dynamic>);
});

final goldProjectDashboardProvider = FutureProvider.autoDispose<ProjectDashboard>((ref) async {
  final response = await ApiClient.instance.dio.get('/projects/gold-mining/dashboard');
  return ProjectDashboard.fromJson(response.data as Map<String, dynamic>);
});

final profitLossReportProvider = FutureProvider.autoDispose<ProfitLossReport>((ref) async {
  final response = await ApiClient.instance.dio.get('/reports/profit-loss');
  return ProfitLossReport.fromJson(response.data as Map<String, dynamic>);
});

final profitLossByAssetProvider = FutureProvider.autoDispose<List<ProfitLossLine>>((ref) async {
  final response = await ApiClient.instance.dio.get('/reports/profit-loss/by-asset');
  return (response.data as List).map((e) => ProfitLossLine.fromJson(e as Map<String, dynamic>)).toList();
});

final cashFlowReportProvider =
    FutureProvider.autoDispose.family<CashFlowReport, TrendRange>((ref, range) async {
  final response = await ApiClient.instance.dio.get('/reports/cash-flow', queryParameters: {
    'date_from': range.from.toIso8601String().split('T').first,
    'date_to': range.to.toIso8601String().split('T').first,
    'group_by': range.groupBy,
  });
  return CashFlowReport.fromJson(response.data as Map<String, dynamic>);
});

final receivablesProvider = FutureProvider.autoDispose<List<ReceivableLine>>((ref) async {
  final response = await ApiClient.instance.dio.get('/reports/receivables');
  return (response.data as List).map((e) => ReceivableLine.fromJson(e as Map<String, dynamic>)).toList();
});

final payablesProvider = FutureProvider.autoDispose<List<PayableLine>>((ref) async {
  final response = await ApiClient.instance.dio.get('/reports/payables');
  return (response.data as List).map((e) => PayableLine.fromJson(e as Map<String, dynamic>)).toList();
});

final trendReportProvider =
    FutureProvider.autoDispose.family<TrendReport, TrendRange>((ref, range) async {
  final response = await ApiClient.instance.dio.get('/analytics/trends', queryParameters: {
    'date_from': range.from.toIso8601String().split('T').first,
    'date_to': range.to.toIso8601String().split('T').first,
    'group_by': range.groupBy,
  });
  return TrendReport.fromJson(response.data as Map<String, dynamic>);
});

final insightsProvider = FutureProvider.autoDispose<List<Insight>>((ref) async {
  final response = await ApiClient.instance.dio.get('/analytics/insights');
  return (response.data as List).map((e) => Insight.fromJson(e as Map<String, dynamic>)).toList();
});

/// Composite provider used by the redesigned home dashboard. The financial
/// summary is required; secondary widgets fail independently so a temporary
/// permission/cold-start issue does not blank the entire home screen.
final homeDashboardProvider = FutureProvider.autoDispose<HomeDashboardData>((ref) async {
  final api = ApiClient.instance;

  final summaryResponse = await api.requestWithRetry(
    () => api.dio.get('/dashboard/summary'),
  );
  final summary = DashboardSummary.fromJson(summaryResponse.data as Map<String, dynamic>);

  Future<List<T>> safeList<T>(Future<List<T>> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return <T>[];
    }
  }

  Future<T?> safeOne<T>(Future<T> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return null;
    }
  }

  final results = await Future.wait<dynamic>([
    safeList<BusinessPerformanceLine>(() async {
      final r = await api.requestWithRetry(() => api.dio.get('/dashboard/business-performance'));
      return (r.data as List)
          .map((e) => BusinessPerformanceLine.fromJson(e as Map<String, dynamic>))
          .toList();
    }),
    safeList<Vehicle>(() async {
      final r = await api.requestWithRetry(() => api.dio.get('/vehicles'));
      return (r.data as List).map((e) => Vehicle.fromJson(e as Map<String, dynamic>)).toList();
    }),
    safeList<Property>(() async {
      final r = await api.requestWithRetry(() => api.dio.get('/properties'));
      return (r.data as List).map((e) => Property.fromJson(e as Map<String, dynamic>)).toList();
    }),
    safeList<Product>(() async {
      final r = await api.requestWithRetry(() => api.dio.get('/shop/products'));
      return (r.data as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
    }),
    safeOne<ProjectDashboard>(() async {
      final r = await api.requestWithRetry(() => api.dio.get('/projects/gold-mining/dashboard'));
      return ProjectDashboard.fromJson(r.data as Map<String, dynamic>);
    }),
    safeOne<ShopDashboard>(() async {
      final r = await api.requestWithRetry(() => api.dio.get('/shop/dashboard'));
      return ShopDashboard.fromJson(r.data as Map<String, dynamic>);
    }),
    safeList<RecentTransaction>(() async {
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 60)).toIso8601String().split('T').first;
      final to = now.toIso8601String().split('T').first;

      final responses = await Future.wait<Response<dynamic>>([
        api.requestWithRetry(() => api.dio.get('/revenue', queryParameters: {
          'date_from': from,
          'date_to': to,
          'page': 1,
          'per_page': 10,
        })),
        api.requestWithRetry(() => api.dio.get('/expenses', queryParameters: {
          'date_from': from,
          'date_to': to,
          'page': 1,
          'per_page': 10,
        })),
      ]);

      final items = <RecentTransaction>[];
      final revenueRows = (responses[0].data as List).cast<Map<String, dynamic>>();
      final expenseRows = (responses[1].data as List).cast<Map<String, dynamic>>();

      for (final row in revenueRows) {
        items.add(
          RecentTransaction(
            isIncome: true,
            title: (row['description'] as String?)?.trim().isNotEmpty == true
                ? row['description'] as String
                : 'Revenue',
            subtitle: row['category'] as String? ?? 'Income',
            amount: double.tryParse(row['amount'].toString()) ?? 0,
            date: DateTime.tryParse(row['created_at']?.toString() ?? row['txn_date']?.toString() ?? '') ?? now,
          ),
        );
      }
      for (final row in expenseRows) {
        items.add(
          RecentTransaction(
            isIncome: false,
            title: (row['description'] as String?)?.trim().isNotEmpty == true
                ? row['description'] as String
                : 'Expense',
            subtitle: row['category'] as String? ?? 'Expense',
            amount: double.tryParse(row['amount'].toString()) ?? 0,
            date: DateTime.tryParse(row['created_at']?.toString() ?? row['txn_date']?.toString() ?? '') ?? now,
          ),
        );
      }
      items.sort((a, b) => b.date.compareTo(a.date));
      return items.take(5).toList();
    }),
    safeOne<int>(() async {
      final r = await api.requestWithRetry(() => api.dio.get('/notifications'));
      return (r.data as List).where((e) => e['is_read'] == false).length;
    }),
  ]);

  return HomeDashboardData(
    summary: summary,
    performance: results[0] as List<BusinessPerformanceLine>,
    vehicles: results[1] as List<Vehicle>,
    properties: results[2] as List<Property>,
    products: results[3] as List<Product>,
    project: results[4] as ProjectDashboard?,
    shop: results[5] as ShopDashboard?,
    transactions: results[6] as List<RecentTransaction>,
    unreadNotifications: results[7] as int? ?? 0,
  );
});

final homeTrendProvider = FutureProvider.autoDispose<TrendReport?>((ref) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month - 5, 1);
  try {
    final response = await ApiClient.instance.requestWithRetry(
      () => ApiClient.instance.dio.get('/analytics/trends', queryParameters: {
        'date_from': from.toIso8601String().split('T').first,
        'date_to': now.toIso8601String().split('T').first,
        'group_by': 'month',
      }),
    );
    return TrendReport.fromJson(response.data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});
