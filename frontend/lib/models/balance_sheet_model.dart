class BalanceSheetData {
  final DateTime asOnDate;
  
  // Assets
  final double cashAndBank; // (Total Received - Total Expenses)
  final double accountsReceivable; // (Total Invoiced - Total Received)
  final double totalAssets; // (Cash + Receivables)

  // Liabilities
  final double gstPayable; // (Total Tax Collected)
  final double totalLiabilities; // (GST)

  // Equity
  final double netProfit; // (Revenue - Expenses) note: Revenue = Invoiced - Tax
  final double totalEquity; // (Net Profit)

  BalanceSheetData({
    required this.asOnDate,
    required this.cashAndBank,
    required this.accountsReceivable,
    required this.totalAssets,
    required this.gstPayable,
    required this.totalLiabilities,
    required this.netProfit,
    required this.totalEquity,
  });
}
