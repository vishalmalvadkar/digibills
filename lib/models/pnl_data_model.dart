class PnLData {
  final double totalIncome;
  final double totalExpense;
  final double netProfit;
  final DateTime date; // Representative date for the period

  PnLData({
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
    required this.date,
  });
}
