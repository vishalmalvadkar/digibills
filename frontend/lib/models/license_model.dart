class LicenseModel {
  final bool isActive;
  final String plan;
  final DateTime startDate;
  final DateTime endDate;

  LicenseModel({
    required this.isActive,
    required this.plan,
    required this.startDate,
    required this.endDate,
  });

  factory LicenseModel.fromMap(Map<String, dynamic> data) {
    return LicenseModel(
      isActive: data['isActive'] ?? true, // Default active for fallback
      plan: data['plan'] ?? 'basic',
      startDate: data['startDate'] != null ? DateTime.parse(data['startDate'].toString()) : DateTime.now(),
      endDate: data['endDate'] != null ? DateTime.parse(data['endDate'].toString()) : DateTime.now().add(const Duration(days: 365)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isActive': isActive,
      'plan': plan,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }
}
