import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/staff_model.dart';
import 'auth_service.dart';

class StaffService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  Future<void> addStaff(String email, String name, List<String> permissions) async {
    final tenantId = _authService.currentTenantId;
    if (tenantId.isEmpty) throw Exception('Owner not logged in');

    final staff = StaffModel(
      id: const Uuid().v4(),
      tenantId: tenantId,
      email: email.toLowerCase(), // Enforce lowercase
      name: name,
      permissions: permissions,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _supabase.from('staff').insert(staff.toMap());
  }

  Future<void> updatePermissions(String staffId, List<String> permissions) async {
    await _supabase
        .from('staff')
        .update({'permissions': permissions})
        .eq('id', staffId);
  }
  
  Future<void> updateStaff(String staffId, String name, List<String> permissions) async {
     await _supabase
        .from('staff')
        .update({
          'name': name,
          'permissions': permissions
        })
        .eq('id', staffId);
  }

  Future<void> deleteStaff(String staffId) async {
    await _supabase.from('staff').delete().eq('id', staffId);
  }

  Stream<List<StaffModel>> streamStaff() {
    final tenantId = _authService.currentTenantId;
    return _supabase
        .from('staff')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .map((data) => data.map((json) => StaffModel.fromMap(json)).toList());
  }
  
  /// Checks if an email belongs to a staff member and returns the record
  Future<StaffModel?> getStaffByEmail(String email) async {
    final response = await _supabase
        .from('staff')
        .select()
        .eq('email', email)
        .maybeSingle();
        
    if (response != null) {
      return StaffModel.fromMap(response);
    }
    return null;
  }
}
