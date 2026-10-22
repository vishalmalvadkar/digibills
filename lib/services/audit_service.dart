import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'settings_service.dart';

class AuditService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();
  final SettingsService _settingsService = SettingsService();

  Future<void> logEvent({
    required String entityType, // e.g., 'BILL'
    required String entityId,
    required String action, // 'CREATE', 'EDIT', 'DELETE', 'STATUS_CHANGE'
    Map<String, dynamic>? changes,
  }) async {
    try {
      // 1. Check if Audit Trail is enabled
      final settings = await _settingsService.fetchSettings();
      if (settings != null && !settings.isAuditTrailEnabled) {
        return; 
      }

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('audit_logs').insert({
        'entity_type': entityType,
        'entity_id': entityId,
        'action': action,
        'changes': changes,
        'performed_by': user.id,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Fail silently to not block main flow? Or print?
      print('Failed to log audit event: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchLogs(String entityId) async {
    final response = await _supabase
        .from('audit_logs')
        .select()
        .eq('entity_id', entityId)
        .order('timestamp', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
}
