
class SupplierBillItem {
  final String? id;
  final String description;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double amount;
  final String? hsnCode;
  final double taxPercentage;
  final double taxAmount;

  SupplierBillItem({
    this.id,
    required this.description,
    required this.quantity,
    this.unit = 'qty',
    required this.unitPrice,
    required this.amount,
    this.hsnCode,
    this.taxPercentage = 0,
    this.taxAmount = 0,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'description': description,
    'quantity': quantity,
    'unit': unit,
    'unit_price': unitPrice,
    'amount': amount,
    'hsn_code': hsnCode,
    'tax_percentage': taxPercentage,
    'tax_amount': taxAmount,
  };

  factory SupplierBillItem.fromMap(Map<String, dynamic> map) {
    return SupplierBillItem(
      id: map['id']?.toString(),
      description: map['description'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] ?? 'qty',
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      hsnCode: map['hsn_code'],
      taxPercentage: (map['tax_percentage'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SupplierBillModel {
  final String id;
  final String supplierName;
  final String? supplierGst;
  final String? invoiceNumber;
  final DateTime date;
  final double totalAmount;
  final double taxAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double discount;
  final String? imageUrl; // NEW: For Record Keeping
  final List<SupplierBillItem> items;
  final Map<String, String> metadata; // NEW: For dynamic fields
  final String? category;
  final String? notes;
  final String tenantId;
  final DateTime createdAt;

  SupplierBillModel({
    required this.id,
    required this.supplierName,
    this.supplierGst,
    this.invoiceNumber,
    required this.date,
    required this.totalAmount,
    this.taxAmount = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.discount = 0,
    this.imageUrl,
    this.items = const [],
    this.metadata = const {}, // NEW
    this.category,
    this.notes,
    required this.tenantId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_name': supplierName,
      'supplier_gst': supplierGst,
      'invoice_number': invoiceNumber,
      'date': date.toIso8601String(),
      'total_amount': totalAmount,
      'tax_amount': taxAmount,
      'cgst_amount': cgstAmount,
      'sgst_amount': sgstAmount,
      'igst_amount': igstAmount,
      'discount': discount,
      'image_url': imageUrl,
      'items': items.map((x) => x.toMap()).toList(),
      'metadata': metadata, // NEW
      'category': category,
      'notes': notes,
      'tenant_id': tenantId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SupplierBillModel.fromMap(Map<String, dynamic> data) {
    return SupplierBillModel(
      id: data['id'] ?? '',
      supplierName: data['supplier_name'] ?? '',
      supplierGst: data['supplier_gst'],
      invoiceNumber: data['invoice_number'],
      date: data['date'] != null ? DateTime.parse(data['date']) : DateTime.now(),
      totalAmount: (data['total_amount'] as num?)?.toDouble() ?? 0,
      taxAmount: (data['tax_amount'] as num?)?.toDouble() ?? 0,
      cgstAmount: (data['cgst_amount'] as num?)?.toDouble() ?? 0,
      sgstAmount: (data['sgst_amount'] as num?)?.toDouble() ?? 0,
      igstAmount: (data['igst_amount'] as num?)?.toDouble() ?? 0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      imageUrl: data['image_url'],
      items: data['items'] != null
          ? (data['items'] as List).map((e) => SupplierBillItem.fromMap(e)).toList()
          : [],
      metadata: data['metadata'] != null
          ? Map<String, String>.from(data['metadata'])
          : {}, // NEW
      category: data['category'],
      notes: data['notes'],
      tenantId: data['tenant_id'] ?? '',
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : DateTime.now(),
    );
  }
}
