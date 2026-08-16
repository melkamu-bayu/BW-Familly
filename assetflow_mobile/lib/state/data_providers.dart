import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/models.dart';

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
