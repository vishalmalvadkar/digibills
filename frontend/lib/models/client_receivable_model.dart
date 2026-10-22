class ClientReceivableModel {
  final String clientName;
  final String clientId;
  final double totalPending;
  final int billCount;
  final DateTime oldestBillDate;
  final int overdueDays;

  ClientReceivableModel({
    required this.clientName,
    required this.clientId,
    required this.totalPending,
    required this.billCount,
    required this.oldestBillDate,
    required this.overdueDays,
  });
}
