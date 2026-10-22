class BillItem {
  final String? id;
  final String? productId; 
  final String description;
  final double amount; 
  final double quantity; 
  final String unit; 
  final double unitPrice; 
  final String? hsnCode; // NEW: GSTR-1 Requirement
  final String hsnType; // NEW: 'HSN' or 'SAC'

  BillItem({
    this.id,
    this.productId,
    required this.description, 
    required this.amount,
    this.quantity = 1,
    this.unit = 'qty',
    this.unitPrice = 0,
    this.hsnCode,
    this.hsnType = 'HSN',
  });

  double get total => amount;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    if (productId != null) 'product_id': productId,
    'description': description,
    'amount': amount,
    'quantity': quantity,
    'unit': unit,
    'unit_price': unitPrice, 
    if (hsnCode != null) 'hsn_code': hsnCode,
    'hsn_type': hsnType,
  };

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      id: map['id']?.toString(), 
      productId: map['product_id'],
      description: map['description'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] ?? 'qty',
      unitPrice: (map['unit_price'] ?? map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      hsnCode: map['hsn_code'] ?? map['hsnCode'],
      hsnType: map['hsn_type'] ?? map['hsnType'] ?? 'HSN',
    );
  }
}

class PaymentRecord {
  final String? id; // NEW: Unique ID for the payment entry
  final DateTime date;
  final double amount;
  final String mode; // 'Cash', 'UPI', 'Cheque', 'Net Banking'

  PaymentRecord({
    this.id,
    required this.date,
    required this.amount,
    required this.mode,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'date': date.toIso8601String(),
    'amount': amount,
    'mode': mode,
  };

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    return PaymentRecord(
      id: map['id']?.toString() ?? map['payment_id']?.toString(), // Handle potential naming variants
      date: map['date'] != null 
          ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      mode: map['mode'] ?? 'Cash',
    );
  }
}

class BillModel {
  final String billId;
  final String customerName;
  final String clientId;
  final String serviceName; 
  final DateTime billDate;
  final double price; 
  final double taxPercentage;
  final double taxAmount;
  final double cgstAmount; // NEW
  final double sgstAmount; // NEW
  final double igstAmount; // NEW
  final String placeOfSupply; // NEW
  final double advanceAmount; // Sum of all payments
  final double totalAmount;
  final String paymentStatus;
  final DateTime? paymentReceivedDate;
  final String whatsappNumber;
  final DateTime createdAt;
  final String clientAddress;
  final String invoiceNumber;
  final List<BillItem> items;
  final List<PaymentRecord> payments; // NEW: Detailed history
  final String tenantId;
  final String? createdBy; // NEW: Track creator for branding
  final String? gstNumber; // NEW: Customer GSTIN
  final double returnAmount; // NEW: Track total returns for status updates
  final String? ewayBillNo; // NEW: e-Way Bill Number
  final String? vehicleNo; // NEW: Vehicle Number
  final String? transportMode; // NEW: Transport Mode (Road, Rail, etc.)
  final String? shippingAddress; // NEW: Shipped To
  final String? shippingName; // NEW: Shipped To
  final String? clientCity; // NEW

  BillModel({
    required this.billId,
    required this.customerName,
    required this.clientId,
    required this.serviceName,
    required this.billDate,
    required this.price,
    required this.taxPercentage,
    required this.taxAmount,
    this.cgstAmount = 0.0,
    this.sgstAmount = 0.0,
    this.igstAmount = 0.0,
    this.placeOfSupply = '',
    required this.advanceAmount,
    required this.totalAmount,
    required this.paymentStatus,
    this.paymentReceivedDate,
    required this.whatsappNumber,
    required this.createdAt,
    required this.clientAddress,
    required this.invoiceNumber,
    required this.items,
    this.payments = const [], 
    this.tenantId = '',
    this.createdBy,
    this.gstNumber, 
    this.returnAmount = 0.0, 
    this.ewayBillNo,
    this.vehicleNo,
    this.transportMode,
    this.shippingAddress,
    this.shippingName,
    this.clientCity,
  });

  factory BillModel.fromMap(Map<String, dynamic> data) {
    List<BillItem> items = [];
    if (data['bill_items'] != null) {
      items = (data['bill_items'] as List).map((e) => BillItem.fromMap(e)).toList();
    } else if (data['items'] != null) {
      items = (data['items'] as List).map((e) => BillItem.fromMap(e)).toList();
    }

    List<PaymentRecord> payments = [];
    if (data['bill_payments'] != null) {
      payments = (data['bill_payments'] as List).map((e) => PaymentRecord.fromMap(e)).toList();
    } else if (data['payments'] != null) {
      payments = (data['payments'] as List).map((e) => PaymentRecord.fromMap(e)).toList();
    }

    // Helper to safely parse doubles from num or string
    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    // Helper to parse dates robustly
    DateTime parseDate(dynamic val) {
       if (val == null) return DateTime.now();
       if (val is DateTime) return val;
       return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }
    
    DateTime? parseDateNullable(dynamic val) {
       if (val == null) return null;
       if (val is DateTime) return val;
       return DateTime.tryParse(val.toString());
    }

    return BillModel(
      billId: data['bill_id'] ?? data['billId'] ?? '',
      customerName: data['customer_name'] ?? data['customerName'] ?? '',
      clientId: data['client_id'] ?? data['clientId'] ?? '',
      serviceName: data['service_name'] ?? data['serviceName'] ?? '',
      
      billDate: parseDate(data['bill_date']),
          
      price: toDouble(data['price']),
      taxPercentage: toDouble(data['tax_percentage']),
      taxAmount: toDouble(data['tax_amount']),
      cgstAmount: toDouble(data['cgst_amount']),
      sgstAmount: toDouble(data['sgst_amount']),
      igstAmount: toDouble(data['igst_amount']),
      placeOfSupply: data['place_of_supply'] ?? '',
      advanceAmount: toDouble(data['advance_amount']),
      totalAmount: toDouble(data['total_amount']),
      
      paymentStatus: data['payment_status'] ?? data['paymentStatus'] ?? 'Pending',
      paymentReceivedDate: parseDateNullable(data['payment_received_date']),
          
      whatsappNumber: data['whatsapp_number'] ?? data['whatsappNumber'] ?? '',
      
      createdAt: parseDate(data['created_at']),
          
      clientAddress: data['client_address'] ?? data['clientAddress'] ?? '',
      invoiceNumber: data['invoice_number'] ?? data['invoiceNumber'] ?? '',
      
      items: items,
      payments: payments,
      tenantId: data['tenant_id'] ?? data['tenantId'] ?? '',
      createdBy: data['created_by'] ?? data['createdBy'],
      gstNumber: data['gst_number'] ?? data['gstNumber'], 
      returnAmount: toDouble(data['return_amount'] ?? data['returnAmount']), 
      ewayBillNo: data['eway_bill_no']?.toString(),
      vehicleNo: data['vehicle_no']?.toString(),
      transportMode: data['transport_mode']?.toString(),
      shippingAddress: data['shipping_address'],
      shippingName: data['shipping_name'],
      clientCity: data['client_city'] ?? data['clientCity'], // NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bill_id': billId,
      'tenant_id': tenantId,
      'invoice_number': invoiceNumber,
      'customer_name': customerName,
      'client_address': clientAddress,
      'whatsapp_number': whatsappNumber,
      'bill_date': billDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'service_name': serviceName,
      'price': price,
      'tax_percentage': taxPercentage,
      'tax_amount': taxAmount,
      'cgst_amount': cgstAmount,
      'sgst_amount': sgstAmount,
      'igst_amount': igstAmount,
      'place_of_supply': placeOfSupply,
      'total_amount': totalAmount,
      'advance_amount': advanceAmount,
      'payment_status': paymentStatus,
      'payment_received_date': paymentReceivedDate?.toIso8601String(),
      'client_id': clientId,
      'created_by': createdBy,
      'gst_number': gstNumber, 
      'return_amount': returnAmount, 
      'eway_bill_no': ewayBillNo,
      'vehicle_no': vehicleNo,
      'transport_mode': transportMode,
      'shipping_address': shippingAddress,
      'shipping_name': shippingName,
      'client_city': clientCity, // NEW
    };
  }

  BillModel copyWith({
    String? billId,
    String? customerName,
    String? clientId,
    String? serviceName,
    DateTime? billDate,
    double? price,
    double? taxPercentage,
    double? taxAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    String? placeOfSupply,
    double? advanceAmount,
    double? totalAmount,
    String? paymentStatus,
    DateTime? paymentReceivedDate,
    String? whatsappNumber,
    DateTime? createdAt,
    String? clientAddress,
    String? invoiceNumber,
    List<BillItem>? items,
    List<PaymentRecord>? payments,
    String? tenantId,
    String? createdBy,
    String? gstNumber,
    double? returnAmount,
    String? ewayBillNo,
    String? vehicleNo,
    String? transportMode,
    String? shippingAddress,
    String? shippingName,
    String? clientCity, // NEW
  }) {
    return BillModel(
      billId: billId ?? this.billId,
      customerName: customerName ?? this.customerName,
      clientId: clientId ?? this.clientId,
      serviceName: serviceName ?? this.serviceName,
      billDate: billDate ?? this.billDate,
      price: price ?? this.price,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      taxAmount: taxAmount ?? this.taxAmount,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstAmount: igstAmount ?? this.igstAmount,
      placeOfSupply: placeOfSupply ?? this.placeOfSupply,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentReceivedDate: paymentReceivedDate ?? this.paymentReceivedDate,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      createdAt: createdAt ?? this.createdAt,
      clientAddress: clientAddress ?? this.clientAddress,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      items: items ?? this.items,
      payments: payments ?? this.payments,
      tenantId: tenantId ?? this.tenantId,
      createdBy: createdBy ?? this.createdBy,
      gstNumber: gstNumber ?? this.gstNumber,
      returnAmount: returnAmount ?? this.returnAmount,
      ewayBillNo: ewayBillNo ?? this.ewayBillNo,
      vehicleNo: vehicleNo ?? this.vehicleNo,
      transportMode: transportMode ?? this.transportMode,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      shippingName: shippingName ?? this.shippingName,
      clientCity: clientCity ?? this.clientCity, // NEW
    );
  }
}
