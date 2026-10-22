import 'license_model.dart';
import 'user_model.dart';
import 'bill_model.dart'; // NEW for PaymentRecord

class ClientModel {
  final String clientId; // Same as User ID (uid)
  final String businessName;
  final String ownerName;
  final String email;
  final String whatsappNumber; // Renamed from phone
  final String tenantId;
  final String state; // NEW: Client State for IGST/SGST calculation
  final String gstNumber; // NEW: Client GSTIN
  final LicenseModel license;
  final String status; // 'pending', 'active', 'blocked'
  final DateTime createdAt;
  
  // MOU Details (NEW)
  final bool mouAccepted;
  final Map<String, dynamic>? mouMeta; // { 'version': 'v1.0', 'signedAt': Timestamp, 'language': 'en' }

  // Billing/Payment Integration Fields (Added for compatibility with Admin UI)
  final double amount;
  final String paymentMode;
  final String paymentStatus;
  final double taxPercentage;
  final List<PaymentRecord> advances;

  ClientModel({
    required this.clientId,
    required this.businessName,
    required this.ownerName,
    required this.email,
    required this.whatsappNumber,
    required this.tenantId,
    this.state = '',
    this.gstNumber = '',
    required this.license,
    this.status = 'active', 
    required this.createdAt,
    this.amount = 0.0,
    this.paymentMode = 'Cash',
    this.paymentStatus = 'Pending', 
    this.taxPercentage = 0.0,
    this.advances = const [],
    this.mouAccepted = false,
    this.mouMeta,
  });

  factory ClientModel.fromMap(Map<String, dynamic> data) {
    return ClientModel(
      clientId: data['client_id'] ?? data['clientId'] ?? '',
      businessName: data['business_name'] ?? data['businessName'] ?? 'Unknown Business',
      ownerName: data['owner_name'] ?? data['ownerName'] ?? 'Unknown Owner',
      email: data['email'] ?? '',
      whatsappNumber: data['whatsapp_number'] ?? data['whatsappNumber'] ?? data['phone'] ?? '', 
      tenantId: data['tenant_id'] ?? data['tenantId'] ?? '',
      state: data['state'] ?? '',
      gstNumber: data['gst_number'] ?? data['gstNumber'] ?? '',
      
      // Handle License (JSONB or Map)
      license: data['license'] != null 
          ? LicenseModel.fromMap(data['license']) 
          : LicenseModel(isActive: false, plan: 'none', startDate: DateTime.now(), endDate: DateTime.now()),
          
      status: data['status'] ?? 'active',
      
      // Handle dates (String from Supabase, Timestamp from Firestore fallback)
      createdAt: data['created_at'] != null 
          ? DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
          
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: data['payment_mode'] ?? data['paymentMode'] ?? 'Cash',
      paymentStatus: data['payment_status'] ?? data['paymentStatus'] ?? 'Pending',
      taxPercentage: (data['tax_percentage'] as num?)?.toDouble() ?? 0.0,
      
      // Advances are likely not in the main table query unless joined, handling null
      advances: (data['advances'] as List?)?.map((e) => PaymentRecord.fromMap(e)).toList() ?? [],
      
      mouAccepted: data['mou_accepted'] ?? data['mouAccepted'] ?? false,
      mouMeta: data['mou_meta'] ?? data['mouMeta'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'client_id': clientId,
      'tenant_id': tenantId,
      'state': state,
      'gst_number': gstNumber,
      'business_name': businessName,
      'owner_name': ownerName,
      'email': email,
      'whatsapp_number': whatsappNumber,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'license': license.toMap(),
      'mou_accepted': mouAccepted,
      'mou_meta': mouMeta,
      'amount': amount,
      'payment_mode': paymentMode,
      'payment_status': paymentStatus,
      'tax_percentage': taxPercentage,
    };
  }
}
