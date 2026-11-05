import 'api_client.dart';

class SequenceService {
  final ApiClient _api = ApiClient();

  /// Fetches the next invoice number atomically from FastAPI + PostgreSQL
  Future<String> getNextInvoiceNumber(String tenantId, String prefix, int startNumber) async {
    try {
      final res = await _api.post(
        '/api/v1/sequence/next?type=invoice&prefix=$prefix&start=$startNumber',
      );
      if (res is Map<String, dynamic> && res['number'] != null) {
        return res['number'] as String;
      }
    } catch (_) {}

    // Fallback timestamp if offline or server error
    return '$prefix${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get current number without incrementing (for preview)
  Future<String> peekNextInvoiceNumber(String tenantId, String prefix, int startNumber) async {
    try {
      final res = await _api.get(
        '/api/v1/sequence/peek?type=invoice&prefix=$prefix&start=$startNumber',
      );
      if (res is Map<String, dynamic> && res['number'] != null) {
        return res['number'] as String;
      }
    } catch (_) {}

    return '$prefix${startNumber.toString().padLeft(3, '0')}';
  }
}
