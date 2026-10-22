import 'dart:convert';

class CreditNoteModel {
  final String id;
  final String tenantId;
  final String billId; // Original Invoice ID
  final String clientId;
  final String creditNoteNumber;
  final String invoiceNumber;
  final String customerName; // NEW
  final DateTime returnDate;
  
  final double totalAmount; // Final Refund Amount
  final double subtotal;
  final double taxAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  
  final String reason;
  final DateTime createdAt;
  final String createdBy;
  
  final List<CreditNoteItem> items;

  CreditNoteModel({
    required this.id,
    required this.tenantId,
    required this.billId,
    required this.clientId,
    required this.creditNoteNumber,
    required this.invoiceNumber,
    this.customerName = '', // NEW
    required this.returnDate,
    required this.totalAmount,
    required this.subtotal,
    required this.taxAmount,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.reason = '',
    required this.createdAt,
    required this.createdBy,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id.isEmpty ? null : id,
      'tenant_id': tenantId,
      'bill_id': billId,
      'client_id': clientId,
      'credit_note_number': creditNoteNumber,
      'invoice_number': invoiceNumber,
      // 'customer_name': customerName, // Not in DB usually, but maybe good to cache? No, fetch from bill.
      'return_date': returnDate.toIso8601String(),
      'total_amount': totalAmount,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'cgst_amount': cgstAmount,
      'sgst_amount': sgstAmount,
      'igst_amount': igstAmount,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  factory CreditNoteModel.fromMap(Map<String, dynamic> map) {
    return CreditNoteModel(
      id: map['id'] ?? '',
      tenantId: map['tenant_id'] ?? '',
      billId: map['bill_id'] ?? '',
      clientId: map['client_id'] ?? '',
      creditNoteNumber: map['credit_note_number'] ?? '',
      invoiceNumber: map['invoice_number'] ?? '', 
      customerName: map['bills'] != null ? (map['bills']['customer_name'] ?? '') : (map['customer_name'] ?? ''), // Handle Join or cached
      returnDate: DateTime.parse(map['return_date']),
      totalAmount: (map['total_amount'] ?? 0).toDouble(),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      taxAmount: (map['tax_amount'] ?? 0).toDouble(),
      cgstAmount: (map['cgst_amount'] ?? 0).toDouble(),
      sgstAmount: (map['sgst_amount'] ?? 0).toDouble(),
      igstAmount: (map['igst_amount'] ?? 0).toDouble(),
      reason: map['reason'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      createdBy: map['created_by'] ?? '',
      items: (map['credit_note_items'] ?? map['items']) != null
          ? List<CreditNoteItem>.from(
              (map['credit_note_items'] ?? map['items'])?.map((x) => CreditNoteItem.fromMap(x)))
          : [],
    );
  }
}

class CreditNoteItem {
  final String id;
  final String creditNoteId;
  final String? productId;
  final String description;
  final double quantity;
  final double unitPrice;
  final double returnAmount;

  CreditNoteItem({
    required this.id,
    required this.creditNoteId,
    this.productId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.returnAmount,
  });

  double get amount => returnAmount; // Alias for PDF Helper compatibility

  Map<String, dynamic> toMap() {
    return {
      'id': id.isEmpty ? null : id,
      'credit_note_id': creditNoteId,
      'product_id': productId,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'return_amount': returnAmount,
    };
  }

  factory CreditNoteItem.fromMap(Map<String, dynamic> map) {
    return CreditNoteItem(
      id: map['id'] ?? '',
      creditNoteId: map['credit_note_id'] ?? '',
      productId: map['product_id'],
      description: map['description'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unitPrice: (map['unit_price'] ?? 0).toDouble(),
      returnAmount: (map['return_amount'] ?? 0).toDouble(),
    );
  }
}
