
class ExpenseModel {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String? notes;
  final String? userId; 
  final String tenantId; 
  
  // NEW: GSTR-3B / ITC Fields
  final String? supplierGstNumber;
  final String? invoiceNumber;
  final double taxAmount;
  final String? taxType; // 'IGST', 'CGST_SGST'
  final String? hsnCode;
  final bool isItcEligible;

  ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.notes,
    this.userId,
    this.tenantId = '', 
    this.supplierGstNumber,
    this.invoiceNumber,
    this.taxAmount = 0.0,
    this.taxType,
    this.hsnCode,
    this.isItcEligible = false,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> data) {
    return ExpenseModel(
      id: data['id'] ?? data['expense_id'] ?? '',
      title: data['title'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] ?? 'Other',
      
      date: data['date'] != null 
          ? DateTime.tryParse(data['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
          
      notes: data['notes'],
      userId: data['user_id'] ?? data['userId'],
      tenantId: data['tenant_id'] ?? data['tenantId'] ?? '',
      
      supplierGstNumber: data['supplier_gst_number'],
      invoiceNumber: data['invoice_number'],
      taxAmount: (data['tax_amount'] as num?)?.toDouble() ?? 0.0,
      taxType: data['tax_type'],
      hsnCode: data['hsn_code'],
      isItcEligible: data['is_itc_eligible'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, 
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'notes': notes,
      'user_id': userId,
      'tenant_id': tenantId,
      'supplier_gst_number': supplierGstNumber,
      'invoice_number': invoiceNumber,
      'tax_amount': taxAmount,
      'tax_type': taxType,
      'hsn_code': hsnCode,
      'is_itc_eligible': isItcEligible,
    };
  }
}
