
class IncomeModel {
  final String id; // Typically same as billId
  final String billId;
  final String clientId;
  final String customerName;
  final String invoiceNumber; // NEW
  final double amount;
  final DateTime incomeDate;
  final String tenantId; // NEW: App Owner ID

  IncomeModel({
    required this.id,
    required this.billId,
    required this.clientId,
    required this.customerName,
    required this.invoiceNumber, // NEW
    required this.amount,
    required this.incomeDate,
    this.tenantId = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'billId': billId,
      'clientId': clientId,
      'customerName': customerName, // Legacy
      'customer_name': customerName, // Supabase
      'invoiceNumber': invoiceNumber,
      'invoice_number': invoiceNumber,
      'amount': amount,
      'incomeDate': incomeDate.toIso8601String(),
      'income_date': incomeDate.toIso8601String(),
      'tenantId': tenantId,
      'tenant_id': tenantId,
    };
  }

  factory IncomeModel.fromMap(Map<String, dynamic> data) {
    final bId = data['billId'] ?? data['bill_id'] ?? data['id'] ?? '';
    
    String invNo = data['invoiceNumber'] ?? data['invoice_number'] ?? '';
    if (invNo.isEmpty && bId.isNotEmpty && bId.toString().length > 5) {
       // Fallback: Generate from Bill ID (first 5 chars)
       invNo = 'INV-${bId.toString().substring(0, 5).toUpperCase()}';
    }

    return IncomeModel(
      id: data['id'] ?? '',
      billId: bId,
      clientId: data['clientId'] ?? data['client_id'] ?? '',
      customerName: data['customerName'] ?? data['customer_name'] ?? 'Unknown',
      invoiceNumber: invNo,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      incomeDate: DateTime.tryParse((data['incomeDate'] ?? data['income_date']).toString()) ?? DateTime.now(),
      tenantId: data['tenantId'] ?? data['tenant_id'] ?? '',
    );
  }
}
