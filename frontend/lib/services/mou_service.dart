import 'dart:async';
import '../models/mou_template_model.dart';
import 'api_client.dart';

class MouService {
  final ApiClient _api = ApiClient();

  // --- Template Management ---

  Stream<List<MouTemplateModel>> streamTemplates() {
    return Stream.fromFuture(getTemplates());
  }

  Future<List<MouTemplateModel>> getTemplates() async {
    try {
      final res = await _api.get('/api/v1/mou/templates');
      if (res is List) {
        return res.map((e) => MouTemplateModel.fromMap(Map<String, dynamic>.from(e))).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<MouTemplateModel?> getActiveTemplate() async {
    try {
      final res = await _api.get('/api/v1/mou/templates/active');
      if (res is Map<String, dynamic>) {
        return MouTemplateModel.fromMap(res);
      }
    } catch (_) {}
    return null;
  }

  Future<MouTemplateModel?> getTemplateByVersion(String version) async {
    try {
      final res = await _api.get('/api/v1/mou/templates/version/$version');
      if (res is Map<String, dynamic>) {
        return MouTemplateModel.fromMap(res);
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveTemplate(MouTemplateModel template) async {
    await _api.post('/api/v1/mou/templates', body: template.toMap());
  }

  Future<void> publishTemplate(String templateId) async {
    await _api.post('/api/v1/mou/templates/$templateId/publish');
  }

  // --- Client Acceptance ---

  Future<void> acceptMou({
    required String clientId,
    required String tenantId,
    required String version,
    required String language,
    required String signatureData, // Base64
  }) async {
    await _api.post('/api/v1/mou/accept', body: {
      'client_id': clientId,
      'tenant_id': tenantId,
      'version': version,
      'language': language,
      'signature_data': signatureData,
    });
    // Immediately update local session so the app recognizes MOU is accepted without re-login
    await _api.updateCurrentUser({'mou_accepted': true});
  }

  // Delete Client MOU
  Future<void> deleteClientMou(String clientId) async {
    await _api.put('/api/v1/clients/$clientId', body: {
      'mou_accepted': false,
      'mou_meta': null,
    });
  }

  Future<String?> getSignatureData(String clientId) async {
    try {
      final res = await _api.get('/api/v1/mou/signature/$clientId');
      if (res is Map<String, dynamic> && res['signature'] != null) {
        return res['signature'] as String;
      }
    } catch (_) {}
    return null;
  }
}
