
class PurchaseItem {
  final String? id;
  final String description;
  final double quantity;
  final String unit;
  final double rate;
  final double amount;
  final String hsnCode;
  final String hsnType; // 'HSN' or 'SAC'
  final double discountAmount;

  PurchaseItem({
    this.id,
    required this.description,
    required this.quantity,
    this.unit = 'qty',
    required this.rate,
    required this.amount,
    required this.hsnCode,
    this.hsnType = 'HSN',
    this.discountAmount = 0,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'description': description,
    'quantity': quantity,
    'unit': unit,
    'rate': rate,
    'amount': amount,
    'hsn_code': hsnCode,
    'hsn_type': hsnType,
    'discount_amount': discountAmount,
  };

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id']?.toString() ?? map['item_id']?.toString(),
      description: map['description'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] ?? 'qty',
      rate: (map['rate'] as num?)?.toDouble() ?? 0.0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      hsnCode: map['hsn_code'] ?? '',
      hsnType: map['hsn_type'] ?? 'HSN',
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PurchaseModel {
  final String purchaseId;
  final String tenantId;
  final String supplierName;
  final String? supplierGstin;
  final String? contactNumber;
  final String? state;
  final String? city;
  final String? invoiceNumber;
  final DateTime date;
  final double subtotal;
  final double taxAmount;
  final double discount;
  final double totalAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final String? placeOfSupply;
  final double taxPercentage;
  final double roundOff;
  final double totalQuantity;
  final List<PurchaseItem> items;
  final DateTime createdAt;

  PurchaseModel({
    required this.purchaseId,
    required this.tenantId,
    required this.supplierName,
    this.supplierGstin,
    this.contactNumber,
    this.state,
    this.city,
    this.invoiceNumber,
    required this.date,
    required this.subtotal,
    required this.taxAmount,
    this.discount = 0,
    required this.totalAmount,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.placeOfSupply,
    this.taxPercentage = 18.0,
    this.roundOff = 0,
    this.totalQuantity = 0,
    required this.items,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (purchaseId.isNotEmpty) 'purchase_id': purchaseId,
      if (tenantId.isNotEmpty) 'tenant_id': tenantId,
      'supplier_name': supplierName,
      'supplier_gstin': supplierGstin,
      'contact_number': contactNumber,
      'state': state,
      'city': city,
      'invoice_number': invoiceNumber,
      'date': date.toIso8601String(),
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'discount': discount,
      'total_amount': totalAmount,
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'place_of_supply': placeOfSupply,
      'tax_percentage': taxPercentage,
      'round_off': roundOff,
      'total_quantity': totalQuantity,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PurchaseModel.fromMap(Map<String, dynamic> map, List<PurchaseItem> itemsList) {
    return PurchaseModel(
      purchaseId: map['purchase_id'] ?? '',
      tenantId: map['tenant_id'] ?? '',
      supplierName: map['supplier_name'] ?? '',
      supplierGstin: map['supplier_gstin'],
      contactNumber: map['contact_number'],
      state: map['state'],
      city: map['city'],
      invoiceNumber: map['invoice_number'],
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      cgst: (map['cgst'] as num?)?.toDouble() ?? 0.0,
      sgst: (map['sgst'] as num?)?.toDouble() ?? 0.0,
      igst: (map['igst'] as num?)?.toDouble() ?? 0.0,
      placeOfSupply: map['place_of_supply'],
      taxPercentage: (map['tax_percentage'] as num?)?.toDouble() ?? 18.0,
      roundOff: (map['round_off'] as num?)?.toDouble() ?? 0.0,
      totalQuantity: (map['total_quantity'] as num?)?.toDouble() ?? 0.0,
      items: itemsList,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }
}
