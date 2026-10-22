
class MouTemplateModel {
  final String id;
  final String version;
  final bool isActive;
  final DateTime updatedAt;
  final Map<String, String> content; // {'en': '...', 'hi': '...', 'mr': '...'}

  MouTemplateModel({
    required this.id,
    required this.version,
    required this.isActive,
    required this.updatedAt,
    required this.content,
  });

  factory MouTemplateModel.fromMap(Map<String, dynamic> data) {
    return MouTemplateModel(
      id: data['id'] ?? data['template_id'] ?? '', // Handle both ID styles if needed
      version: data['version'] ?? '',
      isActive: data['isActive'] ?? data['is_active'] ?? false,
      updatedAt: data['updatedAt'] != null || data['updated_at'] != null
          ? DateTime.tryParse((data['updatedAt'] ?? data['updated_at']).toString()) ?? DateTime.now()
          : DateTime.now(),
      content: Map<String, String>.from(data['content'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'is_active': isActive,
      'updated_at': updatedAt.toIso8601String(),
      'content': content,
    };
  }

  // Helper for empty
  static MouTemplateModel empty() {
    return MouTemplateModel(
      id: '',
      version: '',
      isActive: false,
      updatedAt: DateTime.now(),
      content: {},
    );
  }
}
