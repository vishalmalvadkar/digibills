import '../models/bill_model.dart';
import 'package:intl/intl.dart';

class TimeSeriesPoint {
  final String label;
  final double amount;

  TimeSeriesPoint(this.label, this.amount);
}

class ReportCalculator {
  static List<TimeSeriesPoint> daily(List<BillModel> bills) {
    final Map<DateTime, double> map = {};

    for (var bill in bills) {
      final date = DateTime(
        bill.billDate.year,
        bill.billDate.month,
        bill.billDate.day,
      );
      map[date] = (map[date] ?? 0) + bill.totalAmount;
    }

    final sortedKeys = map.keys.toList()..sort();

    return sortedKeys.map((date) {
      return TimeSeriesPoint(
        DateFormat('dd MMM').format(date),
        map[date]!,
      );
    }).toList();
  }

  static List<TimeSeriesPoint> monthly(List<BillModel> bills) {
    final Map<DateTime, double> map = {};

    for (var bill in bills) {
      final date = DateTime(bill.billDate.year, bill.billDate.month);
      map[date] = (map[date] ?? 0) + bill.totalAmount;
    }

    final sortedKeys = map.keys.toList()..sort();

    return sortedKeys.map((date) {
      return TimeSeriesPoint(
        DateFormat('MMM yyyy').format(date),
        map[date]!,
      );
    }).toList();
  }

  static List<TimeSeriesPoint> yearly(List<BillModel> bills) {
    final Map<int, double> map = {};

    for (var bill in bills) {
      map[bill.billDate.year] =
          (map[bill.billDate.year] ?? 0) + bill.totalAmount;
    }

    final years = map.keys.toList()..sort();

    return years.map((year) {
      return TimeSeriesPoint(year.toString(), map[year]!);
    }).toList();
  }
}
