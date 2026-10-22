import '../models/bill_model.dart';
import '../models/expense_model.dart';
import 'report_calculator.dart';
import 'package:intl/intl.dart';

class DashboardSummary {
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final int totalBills;
  final int paidCount;
  final int pendingCount;
  final Map<String, double> serviceDistribution;
  final Map<String, int> serviceUsageCount;
  
  // Advanced Analytics
  final Map<String, double> topCustomers;
  final Map<String, double> topProducts;
  final Map<String, double> arAging;
  final Map<String, double> gstLiability;
  final List<TimeSeriesPoint> monthlyProfitTrend;
  final List<TimeSeriesPoint> monthlyExpenseTrend;

  DashboardSummary({
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.totalBills,
    required this.paidCount,
    required this.pendingCount,
    required this.serviceDistribution,
    required this.serviceUsageCount,
    required this.topCustomers,
    required this.topProducts,
    required this.arAging,
    required this.gstLiability,
    required this.monthlyProfitTrend,
    required this.monthlyExpenseTrend,
  });
}

class DashboardCalculator {
  static DashboardSummary calculate(List<BillModel> bills, List<ExpenseModel> expenses) {
    double total = 0;
    double paid = 0;
    double pending = 0;
    int paidCount = 0;
    int pendingCount = 0;
    Map<String, double> serviceDist = {};
    Map<String, int> serviceCount = {};
    
    // Advanced Maps
    Map<String, double> topCustomers = {};
    Map<String, double> topProducts = {};
    Map<String, double> arAging = {
      '0-15 Days': 0,
      '16-30 Days': 0,
      '31-60 Days': 0,
      '60+ Days': 0,
    };
    Map<String, double> gstLiability = {
      'IGST': 0,
      'CGST': 0,
      'SGST': 0,
    };

    final now = DateTime.now();

    for (var bill in bills) {
      total += bill.totalAmount;
      
      // GST Liability (Output Tax)
      gstLiability['IGST'] = (gstLiability['IGST'] ?? 0) + bill.igstAmount;
      gstLiability['CGST'] = (gstLiability['CGST'] ?? 0) + bill.cgstAmount;
      gstLiability['SGST'] = (gstLiability['SGST'] ?? 0) + bill.sgstAmount;

      if (bill.paymentStatus == 'Paid') {
        paid += bill.totalAmount;
        paidCount++;
      } else {
        pending += (bill.totalAmount - bill.advanceAmount);
        pendingCount++;
        
        // AR Aging
        final daysDiff = now.difference(bill.billDate).inDays;
        if (daysDiff <= 15) {
          arAging['0-15 Days'] = (arAging['0-15 Days'] ?? 0) + (bill.totalAmount - bill.advanceAmount);
        } else if (daysDiff <= 30) {
          arAging['16-30 Days'] = (arAging['16-30 Days'] ?? 0) + (bill.totalAmount - bill.advanceAmount);
        } else if (daysDiff <= 60) {
          arAging['31-60 Days'] = (arAging['31-60 Days'] ?? 0) + (bill.totalAmount - bill.advanceAmount);
        } else {
          arAging['60+ Days'] = (arAging['60+ Days'] ?? 0) + (bill.totalAmount - bill.advanceAmount);
        }
      }

      // Top Customers
      topCustomers.update(
        bill.customerName, 
        (val) => val + bill.totalAmount, 
        ifAbsent: () => bill.totalAmount
      );

      // Service/Product distribution
      if (bill.items.isNotEmpty) {
        for (var item in bill.items) {
          serviceDist.update(
            item.description, 
            (value) => value + item.amount, 
            ifAbsent: () => item.amount
          );
          serviceCount.update(
            item.description, 
            (value) => value + 1, 
            ifAbsent: () => 1
          );
          // Top Products
          topProducts.update(
            item.description,
            (val) => val + item.amount,
            ifAbsent: () => item.amount
          );
        }
      } else {
        serviceDist.update(
          bill.serviceName, 
          (value) => value + bill.totalAmount, 
          ifAbsent: () => bill.totalAmount
        );
        serviceCount.update(
          bill.serviceName, 
          (value) => value + 1, 
          ifAbsent: () => 1
        );
      }
    }

    // Profit Trend (Income vs Expenses)
    final monthlyProfit = _calculateMonthlyPoints(bills.map((e) => _Point(e.billDate, e.totalAmount)).toList());
    final monthlyExpensePoints = _calculateMonthlyPoints(expenses.map((e) => _Point(e.date, e.amount)).toList());

    return DashboardSummary(
      totalAmount: total,
      paidAmount: paid,
      pendingAmount: pending,
      totalBills: bills.length,
      paidCount: paidCount,
      pendingCount: pendingCount,
      serviceDistribution: serviceDist,
      serviceUsageCount: serviceCount,
      topCustomers: topCustomers,
      topProducts: topProducts,
      arAging: arAging,
      gstLiability: gstLiability,
      monthlyProfitTrend: monthlyProfit,
      monthlyExpenseTrend: monthlyExpensePoints,
    );
  }

  static List<TimeSeriesPoint> _calculateMonthlyPoints(List<_Point> points) {
    final Map<DateTime, double> map = {};
    for (var p in points) {
      final key = DateTime(p.date.year, p.date.month);
      map[key] = (map[key] ?? 0) + p.amount;
    }
    
    final sortedKeys = map.keys.toList()..sort();
    // Show last 6 months or all if fewer
    final filteredKeys = sortedKeys.length > 6 ? sortedKeys.sublist(sortedKeys.length - 6) : sortedKeys;

    return filteredKeys.map((date) {
      return TimeSeriesPoint(
        DateFormat('MMM yy').format(date),
        map[date]!,
      );
    }).toList();
  }
}

class _Point {
  final DateTime date;
  final double amount;
  _Point(this.date, this.amount);
}
