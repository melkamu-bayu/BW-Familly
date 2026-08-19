import 'models.dart';

class RecentTransaction {
  final bool isIncome;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;

  const RecentTransaction({
    required this.isIncome,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
  });
}

class HomeDashboardData {
  final DashboardSummary summary;
  final List<BusinessPerformanceLine> performance;
  final List<Vehicle> vehicles;
  final List<Property> properties;
  final List<Product> products;
  final ProjectDashboard? project;
  final ShopDashboard? shop;
  final List<RecentTransaction> transactions;
  final int unreadNotifications;

  const HomeDashboardData({
    required this.summary,
    required this.performance,
    required this.vehicles,
    required this.properties,
    required this.products,
    required this.project,
    required this.shop,
    required this.transactions,
    required this.unreadNotifications,
  });
}
