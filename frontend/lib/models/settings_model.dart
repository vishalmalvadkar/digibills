class AppSettings {
  final String tenantName; // The user's business name
  final String contactEmail;
  final String contactPhone;

  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String accountHolderName;
  final String upiId;
  final String payeeName;
  final String gstNumber;
  final String address;
  final String city;
  final String district;
  final String pincode;
  final String state; // NEW: Business State for Place of Supply
  final double defaultGstRate; // NEW: Default Tax Rate
  final String printFormat; // 'A4', 'Thermal58', 'Thermal80'

  final String? logoBase64; // RESTORED
  final double logoWidth; // RESTORED
  final double logoHeight; // RESTORED
  final String mouPdfHeaderTitle; 
  final String mouPdfSubHeader; 
  final bool showLogoOnPdf;
  final bool isAuditTrailEnabled; 
  final String invoicePrefix; // NEW: e.g. "INV-24-25-"
  final int invoiceStartNumber; // NEW: Starting number for sequence

  AppSettings({
    required this.tenantName,
    required this.contactEmail,
    required this.contactPhone,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    required this.accountHolderName,
    required this.upiId,
    required this.payeeName,
    required this.gstNumber,
    required this.address,
    required this.city,
    required this.district,
    required this.pincode,
    this.state = '',
    this.defaultGstRate = 18.0,
    this.printFormat = 'A4',
    this.logoBase64,
    this.logoWidth = 60.0,
    this.logoHeight = 60.0,
    this.mouPdfHeaderTitle = 'Memorandum of Understanding', 
    this.mouPdfSubHeader = 'Technology Solutions Provider\nWeb & App Development', 
    this.showLogoOnPdf = true, 
    this.isAuditTrailEnabled = false,
    this.invoicePrefix = 'INV-', // Default
    this.invoiceStartNumber = 1, // Default
  });

  factory AppSettings.defaultSettings() {
    return AppSettings(
      tenantName: 'My Business',
      contactEmail: '',
      contactPhone: '',
      bankName: '',
      accountNumber: '',
      ifscCode: '',
      accountHolderName: '',
      upiId: '',
      payeeName: '',
      gstNumber: '',
      address: '',
      city: '',
      district: '',
      pincode: '',
    );
  }

  factory AppSettings.fromMap(Map<String, dynamic> data) {
    String getName() {
      final name = data['tenant_name'] ?? data['tenantName'] ?? data['companyName'] ?? data['company_name'] ?? data['businessName'] ?? data['business_name'];
      if (name == null || name.toString().trim().isEmpty || name == 'Start-Up Agency') return 'Start-Up Agency';
      return name.toString();
    }

    return AppSettings(
      tenantName: getName(),
      contactEmail: data['contact_email'] ?? data['contactEmail'] ?? '',
      contactPhone: data['contact_phone'] ?? data['contactPhone'] ?? '',
      bankName: data['bank_name'] ?? data['bankName'] ?? '',
      accountNumber: data['account_number'] ?? data['accountNumber'] ?? '',
      ifscCode: data['ifsc_code'] ?? data['ifscCode'] ?? '',
      accountHolderName: data['account_holder_name'] ?? data['accountHolderName'] ?? '',
      upiId: data['upi_id'] ?? data['upiId'] ?? '',
      payeeName: data['payee_name'] ?? data['payeeName'] ?? 'DigiWebia',
      gstNumber: data['gst_number'] ?? data['gstNumber'] ?? '',
      address: data['address'] ?? data['businessAddress'] ?? '', 
      city: data['city'] ?? '',
      district: data['district'] ?? '',
      pincode: data['pincode'] ?? '',
      state: data['state'] ?? '',
      defaultGstRate: (data['default_gst_rate'] ?? 18.0).toDouble(),
      printFormat: data['print_format'] ?? data['printFormat'] ?? 'A4',
      logoBase64: data['logo_base64'] ?? data['logoBase64'],
      logoWidth: (data['logo_width'] ?? data['logoWidth'] ?? 60.0).toDouble(),
      logoHeight: (data['logo_height'] ?? data['logoHeight'] ?? 60.0).toDouble(),
      mouPdfHeaderTitle: data['mou_pdf_header_title'] ?? data['mouPdfHeaderTitle'] ?? 'Memorandum of Understanding',
      mouPdfSubHeader: data['mou_pdf_sub_header'] ?? data['mouPdfSubHeader'] ?? 'Technology Solutions Provider\nWeb & App Development',
      showLogoOnPdf: data['show_logo_on_pdf'] ?? data['showLogoOnPdf'] ?? true,
      isAuditTrailEnabled: data['is_audit_trail_enabled'] ?? data['isAuditTrailEnabled'] ?? false,
      invoicePrefix: data['invoice_prefix'] ?? data['invoicePrefix'] ?? 'INV-',
      invoiceStartNumber: (data['invoice_start_number'] ?? data['invoiceStartNumber'] ?? 1) as int,
    );
  }

  bool get isDefault => tenantName == 'Start-Up Agency';

  AppSettings copyWith({
    String? tenantName,
    String? contactEmail,
    String? contactPhone,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? accountHolderName,
    String? upiId,
    String? payeeName,
    String? gstNumber,
    String? address,
    String? city,
    String? district,
    String? pincode,
    String? state,
    double? defaultGstRate,
    String? printFormat,
    String? logoBase64,
    double? logoWidth,
    double? logoHeight,
    String? mouPdfHeaderTitle,
    String? mouPdfSubHeader,
    bool? showLogoOnPdf,
    bool? isAuditTrailEnabled,
    String? invoicePrefix,
    int? invoiceStartNumber,
  }) {
    return AppSettings(
      tenantName: tenantName ?? this.tenantName,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      upiId: upiId ?? this.upiId,
      payeeName: payeeName ?? this.payeeName,
      gstNumber: gstNumber ?? this.gstNumber,
      address: address ?? this.address,
      city: city ?? this.city,
      district: district ?? this.district,
      pincode: pincode ?? this.pincode,
      state: state ?? this.state,
      defaultGstRate: defaultGstRate ?? this.defaultGstRate,
      printFormat: printFormat ?? this.printFormat,
      logoBase64: logoBase64 ?? this.logoBase64,
      logoWidth: logoWidth ?? this.logoWidth,
      logoHeight: logoHeight ?? this.logoHeight,
      mouPdfHeaderTitle: mouPdfHeaderTitle ?? this.mouPdfHeaderTitle,
      mouPdfSubHeader: mouPdfSubHeader ?? this.mouPdfSubHeader,
      showLogoOnPdf: showLogoOnPdf ?? this.showLogoOnPdf,
      isAuditTrailEnabled: isAuditTrailEnabled ?? this.isAuditTrailEnabled,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      invoiceStartNumber: invoiceStartNumber ?? this.invoiceStartNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenant_name': tenantName,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'account_holder_name': accountHolderName,
      'upi_id': upiId,
      'payee_name': payeeName,
      'gst_number': gstNumber,
      'address': address,
      'city': city,
      'district': district,
      'pincode': pincode,
      'state': state,
      'default_gst_rate': defaultGstRate,
      'print_format': printFormat,
      'logo_base64': logoBase64,
      'logo_width': logoWidth,
      'logo_height': logoHeight,
      'mou_pdf_header_title': mouPdfHeaderTitle,
      'mou_pdf_sub_header': mouPdfSubHeader,
      'show_logo_on_pdf': showLogoOnPdf,
      'is_audit_trail_enabled': isAuditTrailEnabled,
      'invoice_prefix': invoicePrefix,
      'invoice_start_number': invoiceStartNumber,
    };
  }

  // Helper for display
  String get fullAddress => [address, city, district, pincode].where((e) => e.isNotEmpty).join(', ');
}
