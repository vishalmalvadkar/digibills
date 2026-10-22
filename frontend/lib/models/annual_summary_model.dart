class MonthlyPnLData {
  final int month;
  final double income;
  final double expense;
  final double profit;

  MonthlyPnLData({
    required this.month,
    required this.income,
    required this.expense,
    required this.profit,
  });
}

class AnnualSummary {
  final int year;
  final double totalIncome;
  final double totalExpense;
  final double netProfit;
  final List<MonthlyPnLData> monthlyData;

  AnnualSummary({
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
    required this.monthlyData,
  });
}
