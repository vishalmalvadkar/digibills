import 'license_model.dart';

class UserModel {
  final String uid;
  final String role; // 'client' or 'superAdmin'
  final String tenantId;
  final String? name;
  final String? email;
  final DateTime createdAt;
  final LicenseModel? license;
  final String? appVersion;
  final DateTime? lastActiveAt;

  final bool mouAccepted; // NEW
  final List<String> permissions; // NEW

  UserModel({
    required this.uid,
    required this.role,
    required this.tenantId,
    this.name,
    this.email,
    required this.createdAt,
    this.license,
    this.mouAccepted = false, // Default
    this.permissions = const [], // Default
    this.appVersion,
    this.lastActiveAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      role: data['role'] ?? 'client',
      tenantId: data['tenant_id'] ?? data['tenantId'] ?? data['uid'] ?? '', // Prioritize snake_case
      name: data['name'],
      email: data['email'],
      createdAt: data['created_at'] != null 
          ? DateTime.parse(data['created_at'].toString()) 
          : DateTime.now(),
      license: data['license'] != null 
          ? LicenseModel.fromMap(data['license']) 
          : LicenseModel(isActive: true, plan: 'basic', startDate: data['created_at'] != null ? DateTime.parse(data['created_at'].toString()) : DateTime.now(), endDate: DateTime.now().add(const Duration(days: 365))),
      mouAccepted: data['mou_accepted'] ?? false, // Read from map
      permissions: List<String>.from(data['permissions'] ?? []), // NEW
      appVersion: data['app_version'],
      lastActiveAt: data['last_active_at'] != null 
          ? DateTime.parse(data['last_active_at'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role,
      'tenant_id': tenantId, // Note: Snake case in database
      'name': name,
      'email': email,
      'created_at': createdAt.toIso8601String(),
      if (license != null) 'license': license!.toMap(),
      'mou_accepted': mouAccepted,
      'permissions': permissions, // NEW
      if (appVersion != null) 'app_version': appVersion,
      if (lastActiveAt != null) 'last_active_at': lastActiveAt!.toIso8601String(),
    };
  }
  UserModel copyWith({
    String? uid,
    String? role,
    String? tenantId,
    String? name,
    String? email,
    DateTime? createdAt,
    LicenseModel? license,
    bool? mouAccepted,
    List<String>? permissions,
    String? appVersion,
    DateTime? lastActiveAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      license: license ?? this.license,
      mouAccepted: mouAccepted ?? this.mouAccepted,
      permissions: permissions ?? this.permissions,
      appVersion: appVersion ?? this.appVersion,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}
