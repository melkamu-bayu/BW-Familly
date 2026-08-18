class CurrentUser {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final bool biometricEnabled;
  final bool pinIsSet;

  CurrentUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.biometricEnabled = false,
    this.pinIsSet = false,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        biometricEnabled: json['biometric_enabled'] as bool? ?? false,
        pinIsSet: json['pin_is_set'] as bool? ?? false,
      );
}

class DashboardSummary {
  final double todayRevenue;
  final double todayExpense;
  final double todayNetProfit;
  final double monthRevenue;
  final double monthExpense;
  final double monthNetProfit;
  final double allTimeRevenue;
  final double allTimeExpense;
  final double allTimeNetProfit;
  final double cashAndBankBalance;
  final String currency;

  DashboardSummary({
    required this.todayRevenue,
    required this.todayExpense,
    required this.todayNetProfit,
    required this.monthRevenue,
    required this.monthExpense,
    required this.monthNetProfit,
    required this.allTimeRevenue,
    required this.allTimeExpense,
    required this.allTimeNetProfit,
    required this.cashAndBankBalance,
    required this.currency,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        todayRevenue: (json['today']['revenue'] as num).toDouble(),
        todayExpense: (json['today']['expense'] as num).toDouble(),
        todayNetProfit: (json['today']['net_profit'] as num).toDouble(),
        monthRevenue: (json['this_month']['revenue'] as num).toDouble(),
        monthExpense: (json['this_month']['expense'] as num).toDouble(),
        monthNetProfit: (json['this_month']['net_profit'] as num).toDouble(),
        allTimeRevenue: (json['all_time']['revenue'] as num).toDouble(),
        allTimeExpense: (json['all_time']['expense'] as num).toDouble(),
        allTimeNetProfit: (json['all_time']['net_profit'] as num).toDouble(),
        cashAndBankBalance: (json['cash_and_bank_balance'] as num).toDouble(),
        currency: json['currency'] as String,
      );
}

class BusinessPerformanceLine {
  final String category;
  final String code;
  final double revenue;
  final double expense;
  final double profit;
  final double percentageContribution;

  BusinessPerformanceLine({
    required this.category,
    required this.code,
    required this.revenue,
    required this.expense,
    required this.profit,
    required this.percentageContribution,
  });

  factory BusinessPerformanceLine.fromJson(Map<String, dynamic> json) => BusinessPerformanceLine(
        category: json['category'] as String,
        code: json['code'] as String,
        revenue: (json['revenue'] as num).toDouble(),
        expense: (json['expense'] as num).toDouble(),
        profit: (json['profit'] as num).toDouble(),
        percentageContribution: (json['percentage_contribution'] as num).toDouble(),
      );
}

class Vehicle {
  final String id;
  final String businessUnitId;
  final String name;
  final String? plateNumber;
  final String? vehicleType;
  final String? driverName;
  final double mileage;
  final String status;

  Vehicle({
    required this.id,
    required this.businessUnitId,
    required this.name,
    this.plateNumber,
    this.vehicleType,
    this.driverName,
    required this.mileage,
    required this.status,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String,
        businessUnitId: json['business_unit_id'] as String,
        name: json['name'] as String,
        plateNumber: json['plate_number'] as String?,
        vehicleType: json['vehicle_type'] as String?,
        driverName: json['driver_name'] as String?,
        mileage: (json['mileage'] as num).toDouble(),
        status: json['status'] as String,
      );
}

class VehicleProfitability {
  final String vehicleId;
  final String name;
  final double revenue;
  final double expenses;
  final double profit;
  final double mileage;
  final double? costPerKm;
  final double? profitPerKm;

  VehicleProfitability({
    required this.vehicleId,
    required this.name,
    required this.revenue,
    required this.expenses,
    required this.profit,
    required this.mileage,
    this.costPerKm,
    this.profitPerKm,
  });

  factory VehicleProfitability.fromJson(Map<String, dynamic> json) => VehicleProfitability(
        vehicleId: json['vehicle_id'] as String,
        name: json['name'] as String,
        revenue: (json['revenue'] as num).toDouble(),
        expenses: (json['expenses'] as num).toDouble(),
        profit: (json['profit'] as num).toDouble(),
        mileage: (json['mileage'] as num).toDouble(),
        costPerKm: (json['cost_per_km'] as num?)?.toDouble(),
        profitPerKm: (json['profit_per_km'] as num?)?.toDouble(),
      );
}

class Account {
  final String id;
  final String name;
  final String accountType;
  final double currentBalance;
  final String currency;

  Account({
    required this.id,
    required this.name,
    required this.accountType,
    required this.currentBalance,
    required this.currency,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        name: json['name'] as String,
        accountType: json['account_type'] as String,
        currentBalance: double.tryParse(json['current_balance'].toString()) ?? 0.0,
        currency: json['currency'] as String,
      );
}

class Property {
  final String id;
  final String businessUnitId;
  final String name;
  final String? address;
  final int? rooms;
  final double monthlyRent;
  final String status;

  Property({
    required this.id,
    required this.businessUnitId,
    required this.name,
    this.address,
    this.rooms,
    required this.monthlyRent,
    required this.status,
  });

  factory Property.fromJson(Map<String, dynamic> json) => Property(
        id: json['id'] as String,
        businessUnitId: json['business_unit_id'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        rooms: json['rooms'] as int?,
        monthlyRent: (json['monthly_rent'] as num).toDouble(),
        status: json['status'] as String,
      );
}

class PropertyDashboard {
  final String propertyId;
  final String name;
  final double monthlyRent;
  final double annualRent;
  final double collectedRent;
  final double outstandingRent;
  final double propertyExpenses;
  final double netRentalProfit;
  final String occupancyStatus;

  PropertyDashboard({
    required this.propertyId,
    required this.name,
    required this.monthlyRent,
    required this.annualRent,
    required this.collectedRent,
    required this.outstandingRent,
    required this.propertyExpenses,
    required this.netRentalProfit,
    required this.occupancyStatus,
  });

  factory PropertyDashboard.fromJson(Map<String, dynamic> json) => PropertyDashboard(
        propertyId: json['property_id'] as String,
        name: json['name'] as String,
        monthlyRent: (json['monthly_rent'] as num).toDouble(),
        annualRent: (json['annual_rent'] as num).toDouble(),
        collectedRent: (json['collected_rent'] as num).toDouble(),
        outstandingRent: (json['outstanding_rent'] as num).toDouble(),
        propertyExpenses: (json['property_expenses'] as num).toDouble(),
        netRentalProfit: (json['net_rental_profit'] as num).toDouble(),
        occupancyStatus: json['occupancy_status'] as String,
      );
}

class Product {
  final String id;
  final String name;
  final String? sku;
  final String unit;
  final double? sellingPrice;
  final double currentQuantity;
  final double minStockLevel;
  final double stockValue;

  Product({
    required this.id,
    required this.name,
    this.sku,
    required this.unit,
    this.sellingPrice,
    required this.currentQuantity,
    required this.minStockLevel,
    required this.stockValue,
  });

  bool get isLowStock => currentQuantity <= minStockLevel;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        sku: json['sku'] as String?,
        unit: json['unit'] as String,
        sellingPrice: (json['selling_price'] as num?)?.toDouble(),
        currentQuantity: (json['current_quantity'] as num).toDouble(),
        minStockLevel: (json['min_stock_level'] as num).toDouble(),
        stockValue: (json['stock_value'] as num).toDouble(),
      );
}

class ShopDashboard {
  final double revenue;
  final double costOfGoodsSold;
  final double grossProfit;
  final double operatingExpenses;
  final double netProfit;
  final int lowStockCount;

  ShopDashboard({
    required this.revenue,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.operatingExpenses,
    required this.netProfit,
    required this.lowStockCount,
  });

  factory ShopDashboard.fromJson(Map<String, dynamic> json) => ShopDashboard(
        revenue: (json['revenue'] as num).toDouble(),
        costOfGoodsSold: (json['cost_of_goods_sold'] as num).toDouble(),
        grossProfit: (json['gross_profit'] as num).toDouble(),
        operatingExpenses: (json['operating_expenses'] as num).toDouble(),
        netProfit: (json['net_profit'] as num).toDouble(),
        lowStockCount: json['low_stock_count'] as int,
      );
}

class ProjectDashboard {
  final String projectId;
  final String name;
  final String status;
  final double totalInvestment;
  final double totalExpenses;
  final double totalRevenue;
  final double netProfit;
  final double cashUsed;
  final double? roi;

  ProjectDashboard({
    required this.projectId,
    required this.name,
    required this.status,
    required this.totalInvestment,
    required this.totalExpenses,
    required this.totalRevenue,
    required this.netProfit,
    required this.cashUsed,
    this.roi,
  });

  factory ProjectDashboard.fromJson(Map<String, dynamic> json) => ProjectDashboard(
        projectId: json['project_id'] as String,
        name: json['name'] as String,
        status: json['status'] as String,
        totalInvestment: (json['total_investment'] as num).toDouble(),
        totalExpenses: (json['total_expenses'] as num).toDouble(),
        totalRevenue: (json['total_revenue'] as num).toDouble(),
        netProfit: (json['net_profit'] as num).toDouble(),
        cashUsed: (json['cash_used'] as num).toDouble(),
        roi: (json['roi'] as num?)?.toDouble(),
      );
}

class ProfitLossLine {
  final String label;
  final double revenue;
  final double expenses;
  final double profit;

  ProfitLossLine({required this.label, required this.revenue, required this.expenses, required this.profit});

  factory ProfitLossLine.fromJson(Map<String, dynamic> json) => ProfitLossLine(
        label: json['label'] as String,
        revenue: (json['revenue'] as num).toDouble(),
        expenses: (json['expenses'] as num).toDouble(),
        profit: (json['profit'] as num).toDouble(),
      );
}

class ProfitLossReport {
  final ProfitLossLine consolidated;
  final List<ProfitLossLine> byCategory;

  ProfitLossReport({required this.consolidated, required this.byCategory});

  factory ProfitLossReport.fromJson(Map<String, dynamic> json) => ProfitLossReport(
        consolidated: ProfitLossLine.fromJson(json['consolidated'] as Map<String, dynamic>),
        byCategory: (json['by_category'] as List)
            .map((e) => ProfitLossLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TrendPoint {
  final String periodLabel;
  final double revenue;
  final double expense;
  final double profit;

  TrendPoint({required this.periodLabel, required this.revenue, required this.expense, required this.profit});

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
        periodLabel: json['period_label'] as String,
        revenue: (json['revenue'] as num).toDouble(),
        expense: (json['expense'] as num).toDouble(),
        profit: (json['profit'] as num).toDouble(),
      );
}

class TrendReport {
  final String metricGroupBy;
  final List<TrendPoint> points;

  TrendReport({required this.metricGroupBy, required this.points});

  factory TrendReport.fromJson(Map<String, dynamic> json) => TrendReport(
        metricGroupBy: json['metric_group_by'] as String,
        points: (json['points'] as List).map((e) => TrendPoint.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Not a backend model -- just the (from, to, group_by) key for
/// trendReportProvider's `.family`, since FutureProvider.family needs a
/// single hashable argument rather than three separate ones.
class TrendRange {
  final DateTime from;
  final DateTime to;
  final String groupBy; // day | week | month

  const TrendRange({required this.from, required this.to, this.groupBy = 'day'});

  @override
  bool operator ==(Object other) =>
      other is TrendRange && other.from == from && other.to == to && other.groupBy == groupBy;

  @override
  int get hashCode => Object.hash(from, to, groupBy);
}

class Insight {
  final String text;
  final String category;
  final String severity;

  Insight({required this.text, required this.category, required this.severity});

  factory Insight.fromJson(Map<String, dynamic> json) => Insight(
        text: json['text'] as String,
        category: json['category'] as String,
        severity: json['severity'] as String? ?? 'info',
      );
}

class CashFlowPoint {
  final String periodLabel;
  final double inflow;
  final double outflow;
  final double net;

  CashFlowPoint({required this.periodLabel, required this.inflow, required this.outflow, required this.net});

  factory CashFlowPoint.fromJson(Map<String, dynamic> json) => CashFlowPoint(
        periodLabel: json['period_label'] as String,
        inflow: (json['inflow'] as num).toDouble(),
        outflow: (json['outflow'] as num).toDouble(),
        net: (json['net'] as num).toDouble(),
      );
}

class CashFlowReport {
  final List<CashFlowPoint> points;
  final double totalInflow;
  final double totalOutflow;
  final double netCashFlow;

  CashFlowReport({
    required this.points,
    required this.totalInflow,
    required this.totalOutflow,
    required this.netCashFlow,
  });

  factory CashFlowReport.fromJson(Map<String, dynamic> json) => CashFlowReport(
        points: (json['points'] as List).map((e) => CashFlowPoint.fromJson(e as Map<String, dynamic>)).toList(),
        totalInflow: (json['total_inflow'] as num).toDouble(),
        totalOutflow: (json['total_outflow'] as num).toDouble(),
        netCashFlow: (json['net_cash_flow'] as num).toDouble(),
      );
}

class ReceivableLine {
  final String customerId;
  final String customerName;
  final double outstandingBalance;

  ReceivableLine({required this.customerId, required this.customerName, required this.outstandingBalance});

  factory ReceivableLine.fromJson(Map<String, dynamic> json) => ReceivableLine(
        customerId: json['customer_id'] as String,
        customerName: json['customer_name'] as String,
        outstandingBalance: (json['outstanding_balance'] as num).toDouble(),
      );
}

class PayableLine {
  final String supplierId;
  final String supplierName;
  final double outstandingPayable;

  PayableLine({required this.supplierId, required this.supplierName, required this.outstandingPayable});

  factory PayableLine.fromJson(Map<String, dynamic> json) => PayableLine(
        supplierId: json['supplier_id'] as String,
        supplierName: json['supplier_name'] as String,
        outstandingPayable: (json['outstanding_payable'] as num).toDouble(),
      );
}

class Tenant {
  final String id;
  final String propertyId;
  final String name;
  final String? phone;
  final bool active;

  Tenant({required this.id, required this.propertyId, required this.name, this.phone, required this.active});

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
        id: json['id'] as String,
        propertyId: json['property_id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        active: json['active'] as bool,
      );
}

class Customer {
  final String id;
  final String name;
  final String? phone;
  final double outstandingBalance;

  Customer({required this.id, required this.name, this.phone, required this.outstandingBalance});

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        outstandingBalance: (json['outstanding_balance'] as num).toDouble(),
      );
}

class Supplier {
  final String id;
  final String name;
  final String? phone;
  final double outstandingPayable;

  Supplier({required this.id, required this.name, this.phone, required this.outstandingPayable});

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        outstandingPayable: (json['outstanding_payable'] as num).toDouble(),
      );
}

class AppNotification {
  final String id;
  final String type;
  final String? title;
  final String? body;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    this.title,
    this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String?,
        body: json['body'] as String?,
        isRead: json['is_read'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
