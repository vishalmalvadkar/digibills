class PlatformConfigModel {
  final bool maintenanceMode;
  final String? announcementText;
  final String? announcementType;
  final String maintenanceMessage;
  final String minAppVersion;
  final String mouAppName;
  final String mouAddress;
  final String mouFooter;
  final String? mouLogoBase64;
  final String? mouWatermarkBase64;
  final String mouHeaderTitle;
  final DateTime updatedAt;

  PlatformConfigModel({
    required this.maintenanceMode,
    this.announcementText,
    required this.announcementType,
    required this.maintenanceMessage,
    required this.minAppVersion,
    this.mouAppName = 'DigiInvi',
    this.mouAddress = 'Technology Solutions Provider',
    this.mouFooter = 'DigiInvi - developed by DigiWebia',
    this.mouLogoBase64,
    this.mouWatermarkBase64,
    this.mouHeaderTitle = 'MEMORANDUM OF UNDERSTANDING',
    required this.updatedAt,
  });

  factory PlatformConfigModel.fromMap(Map<String, dynamic> data) {
    return PlatformConfigModel(
      maintenanceMode: data['maintenance_mode'] ?? false,
      announcementText: data['announcement_text'],
      announcementType: data['announcement_type'] ?? 'info',
      maintenanceMessage: data['maintenance_message'] ?? 'The system is currently undergoing scheduled maintenance.',
      minAppVersion: data['min_app_version'] ?? '1.0.0',
      mouAppName: data['mou_app_name'] ?? 'DigiInvi',
      mouAddress: data['mou_address'] ?? 'Technology Solutions Provider',
      mouFooter: data['mou_footer'] ?? 'DigiInvi - developed by DigiWebia',
      mouLogoBase64: data['mou_logo_base64'],
      mouWatermarkBase64: data['mou_watermark_base64'],
      mouHeaderTitle: data['mou_header_title'] ?? 'MEMORANDUM OF UNDERSTANDING',
      updatedAt: data['updated_at'] != null 
          ? DateTime.parse(data['updated_at'].toString()) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'maintenance_mode': maintenanceMode,
      'announcement_text': announcementText,
      'announcement_type': announcementType,
      'maintenance_message': maintenanceMessage,
      'min_app_version': minAppVersion,
      'mou_app_name': mouAppName,
      'mou_address': mouAddress,
      'mou_footer': mouFooter,
      'mou_logo_base64': mouLogoBase64,
      'mou_watermark_base64': mouWatermarkBase64,
      'mou_header_title': mouHeaderTitle,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PlatformConfigModel copyWith({
    bool? maintenanceMode,
    String? announcementText,
    String? announcementType,
    String? maintenanceMessage,
    String? minAppVersion,
    String? mouAppName,
    String? mouAddress,
    String? mouFooter,
    String? mouLogoBase64,
    String? mouWatermarkBase64,
    String? mouHeaderTitle,
    DateTime? updatedAt,
  }) {
    return PlatformConfigModel(
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      announcementText: announcementText ?? this.announcementText,
      announcementType: announcementType ?? this.announcementType,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      minAppVersion: minAppVersion ?? this.minAppVersion,
      mouAppName: mouAppName ?? this.mouAppName,
      mouAddress: mouAddress ?? this.mouAddress,
      mouFooter: mouFooter ?? this.mouFooter,
      mouLogoBase64: mouLogoBase64 ?? this.mouLogoBase64,
      mouWatermarkBase64: mouWatermarkBase64 ?? this.mouWatermarkBase64,
      mouHeaderTitle: mouHeaderTitle ?? this.mouHeaderTitle,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
