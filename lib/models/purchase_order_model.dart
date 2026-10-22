import 'dart:convert';
import 'bill_model.dart'; // Reuse BillItem

class PurchaseOrderModel {
  final String poId;
  final String poNumber;
  final String vendorName;
  final String vendorContact;
  final String vendorAddress;
  final String vendorGst;
  final DateTime date;
  final DateTime expectedDeliveryDate;
  final String status;
  final double totalAmount;
  final List<BillItem> items; // Reusing BillItem for simplicity
  final String notes;
  final String tenantId;
  final double taxPercentage;

  PurchaseOrderModel({
    required this.poId,
    required this.poNumber,
    required this.vendorName,
    required this.vendorContact,
    required this.vendorAddress,
    required this.vendorGst,
    required this.date,
    required this.expectedDeliveryDate,
    required this.status,
    required this.totalAmount,
    required this.items,
    required this.notes,
    required this.tenantId,
    this.taxPercentage = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'po_id': poId,
      'po_number': poNumber,
      'vendor_name': vendorName,
      'vendor_contact': vendorContact,
      'vendor_address': vendorAddress,
      'vendor_gst': vendorGst,
      'date': date.toIso8601String(),
      'expected_delivery_date': expectedDeliveryDate.toIso8601String(),
      'status': status,
      'total_amount': totalAmount,
      'items': items.map((x) => x.toMap()).toList(),
      'notes': notes,
      'tenant_id': tenantId,
      'tax_percentage': taxPercentage,
    };
  }

  factory PurchaseOrderModel.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderModel(
      poId: map['po_id'] ?? '',
      poNumber: map['po_number'] ?? '',
      vendorName: map['vendor_name'] ?? '',
      vendorContact: map['vendor_contact'] ?? '',
      vendorAddress: map['vendor_address'] ?? '',
      vendorGst: map['vendor_gst'] ?? '',
      date: DateTime.parse(map['date']),
      expectedDeliveryDate: DateTime.parse(map['expected_delivery_date']),
      status: map['status'] ?? 'Draft',
      totalAmount: (map['total_amount'] ?? 0).toDouble(),
      items: List<BillItem>.from(
          (map['items'] as List<dynamic>? ?? []).map((x) => BillItem.fromMap(x))),
      notes: map['notes'] ?? '',
      tenantId: map['tenant_id'] ?? '',
      taxPercentage: (map['tax_percentage'] ?? 0).toDouble(),
    );
  }
}
