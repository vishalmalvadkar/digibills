class StaffModel {
  final String id;
  final String tenantId;
  final String email;
  final String name;
  final List<String> permissions;
  final String status; // 'active', 'pending'
  final DateTime createdAt;

  StaffModel({
    required this.id,
    required this.tenantId,
    required this.email,
    required this.name,
    required this.permissions,
    required this.status,
    required this.createdAt,
  });

  factory StaffModel.fromMap(Map<String, dynamic> data) {
    return StaffModel(
      id: data['id'] ?? '',
      tenantId: data['tenant_id'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      permissions: List<String>.from(data['permissions'] ?? []),
      status: data['status'] ?? 'pending',
      createdAt: data['created_at'] != null 
          ? DateTime.parse(data['created_at'].toString()) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'email': email,
      'name': name,
      'permissions': permissions,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
