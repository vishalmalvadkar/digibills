import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/platform_config_model.dart';
import 'package:package_info_plus/package_info_plus.dart';

class PlatformGovernanceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream for real-time config updates (Announcement/Maintenance)
  Stream<PlatformConfigModel> streamConfig() {
    try {
      return _supabase
          .from('platform_config')
          .stream(primaryKey: ['id'])
          .eq('id', 1)
          .map((data) {
            if (data.isEmpty) {
              return PlatformConfigModel(
                maintenanceMode: false,
                announcementType: 'info',
                maintenanceMessage: 'System is under maintenance.',
                minAppVersion: '1.0.0',
                updatedAt: DateTime.now(),
              );
            }
            return PlatformConfigModel.fromMap(data.first);
          }).handleError((_) => PlatformConfigModel(
                maintenanceMode: false,
                announcementType: 'info',
                maintenanceMessage: 'System is under maintenance.',
                minAppVersion: '1.0.0',
                updatedAt: DateTime.now(),
              ));
    } catch (_) {
      return Stream.value(PlatformConfigModel(
        maintenanceMode: false,
        announcementType: 'info',
        maintenanceMessage: 'System is under maintenance.',
        minAppVersion: '1.0.0',
        updatedAt: DateTime.now(),
      ));
    }
  }

  // Fetch current config
  Future<PlatformConfigModel> fetchConfig() async {
    try {
      final data = await _supabase
          .from('platform_config')
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (data != null) {
        return PlatformConfigModel.fromMap(data);
      }
    } catch (e) {
      print('Error fetching platform config: $e');
    }
    // Return default if not found or error
    return PlatformConfigModel(
      maintenanceMode: false,
      announcementType: 'info',
      maintenanceMessage: 'System is under maintenance.',
      minAppVersion: '1.0.0',
      updatedAt: DateTime.now(),
    );
  }

  // Update config (SuperAdmin only)
  Future<void> updateConfig(PlatformConfigModel config) async {
    // Use upsert to ensure the record with id=1 exists or is updated
    final data = config.toMap();
    data['id'] = 1;
    await _supabase
        .from('platform_config')
        .upsert(data);
  }

  // Audit User: Update app version and last active timestamp
  Future<void> auditUser(String uid) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = '${info.version}+${info.buildNumber}';

      await _supabase.from('users').update({
        'app_version': version,
        'last_active_at': DateTime.now().toIso8601String(),
      }).eq('uid', uid);
    } catch (e) {
      print('Error auditing user: $e');
    }
  }

  // Fetch all user versions for Audit List
  Future<List<Map<String, dynamic>>> fetchVersionAudit() async {
    try {
      // Fetch users with their business name from clients table if possible
      final users = await _supabase
          .from('users')
          .select('uid, name, email, app_version, last_active_at, role');
      
      return List<Map<String, dynamic>>.from(users);
    } catch (e) {
      print('Error fetching version audit: $e');
      return [];
    }
  }
}
