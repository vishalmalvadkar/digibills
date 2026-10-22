import 'bill_model.dart'; // Reuse BillItem

class QuoteModel {
  final String quoteId;
  final String customerName;
  final String clientId;
  final DateTime date;
  final DateTime expiryDate; // NEW: Urgency
  final double totalAmount;
  final String status; // Draft, Sent, Viewed, Accepted, Rejected, Converted
  final List<BillItem> items;
  final String tenantId;
  final String quoteNumber; // QT-00001
  final String notes;
  final String whatsappNumber; // NEW
  final String customerEmail; // NEW: Email Integration
  final double taxPercentage; // NEW
  final String placeOfSupply; // NEW: GST Logic
  final String docType; // Quote or Proforma
  final String? createdBy; // NEW: Branding
  final String? shippingAddress; // NEW: Shipped To
  final String? shippingName; // NEW: Shipped To

  QuoteModel({
    required this.quoteId,
    required this.customerName,
    required this.clientId,
    required this.date,
    required this.expiryDate,
    required this.totalAmount,
    required this.status,
    required this.items,
    required this.tenantId,
    required this.quoteNumber,
    required this.notes,
    required this.whatsappNumber,
    this.customerEmail = '', // Default empty
    required this.taxPercentage,
    this.docType = 'Quote', // Default
    this.createdBy,
    this.placeOfSupply = '', // Default
    this.shippingAddress,
    this.shippingName,
  });

  double get subTotal => items.fold(0, (sum, item) => sum + item.amount);
  double get taxAmount => (subTotal * taxPercentage / 100);
  double get discountAmount => 0.0; // Future-proof

  Map<String, dynamic> toMap() {
    return {
      'quote_id': quoteId,
      'customer_name': customerName,
      'client_id': clientId,
      'date': date.toIso8601String(),
      'expiry_date': expiryDate.toIso8601String(),
      'total_amount': totalAmount,
      'status': status,
      'items': items.map((e) => e.toMap()).toList(),
      'tenant_id': tenantId,
      'quote_number': quoteNumber,
      'notes': notes,
      'whatsapp_number': whatsappNumber,
      'customer_email': customerEmail,
      'tax_percentage': taxPercentage,
      'doc_type': docType,
      'created_by': createdBy,
      'place_of_supply': placeOfSupply,
      'shipping_address': shippingAddress,
      'shipping_name': shippingName,
    };
  }

  factory QuoteModel.fromMap(Map<String, dynamic> data) {
    var itemsList = <BillItem>[];
    if (data['items'] != null) {
      itemsList = (data['items'] as List).map((e) => BillItem.fromMap(e)).toList();
    }

    return QuoteModel(
      quoteId: data['quote_id'] ?? '',
      customerName: data['customer_name'] ?? '',
      clientId: data['client_id'] ?? '',
      date: DateTime.tryParse(data['date'].toString()) ?? DateTime.now(),
      expiryDate: DateTime.tryParse(data['expiry_date'].toString()) ?? DateTime.now(),
      totalAmount: (data['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'Draft',
      items: itemsList,
      tenantId: data['tenant_id'] ?? '',
      quoteNumber: data['quote_number'] ?? '',
      notes: data['notes'] ?? '',
      whatsappNumber: data['whatsapp_number'] ?? '',
      customerEmail: data['customer_email'] ?? '',
      taxPercentage: (data['tax_percentage'] as num?)?.toDouble() ?? 0.0,
      docType: data['doc_type'] ?? 'Quote',
      createdBy: data['created_by'],
      placeOfSupply: data['place_of_supply'] ?? '',
      shippingAddress: data['shipping_address'],
      shippingName: data['shipping_name'],
    );
  }
}
