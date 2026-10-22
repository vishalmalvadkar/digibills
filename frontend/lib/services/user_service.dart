import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/user_model.dart';
import '../models/license_model.dart';
import 'api_client.dart';

class UserService {
  final ApiClient _api = ApiClient();

  Future<UserModel> syncUser(sb.User user) async {
    try {
      final userMap = _api.currentUser ?? {};
      return UserModel(
        uid: userMap['uid'] ?? user.id,
        role: userMap['role'] ?? 'client',
        tenantId: userMap['tenant_id'] ?? user.id,
        name: userMap['name'] ?? user.email?.split('@').first,
        email: userMap['email'] ?? user.email,
        createdAt: DateTime.now(),
        license: userMap['license'] != null
            ? LicenseModel.fromMap(userMap['license'])
            : LicenseModel(
                isActive: true,
                plan: 'premium',
                startDate: DateTime.now(),
                endDate: DateTime.now().add(const Duration(days: 365 * 5)),
              ),
        mouAccepted: userMap['mou_accepted'] ?? true,
        permissions: List<String>.from(userMap['permissions'] ?? []),
      );
    } catch (e) {
      return UserModel(
        uid: user.id,
        role: 'client',
        tenantId: user.id,
        email: user.email,
        createdAt: DateTime.now(),
        license: LicenseModel(
          isActive: true,
          plan: 'premium',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 365)),
        ),
      );
    }
  }

  Future<UserModel?> getUser(String uid) async {
    final userMap = _api.currentUser;
    if (userMap != null) {
      return UserModel.fromMap(userMap);
    }
    return null;
  }

  Stream<UserModel?> streamUser(String uid) {
    return Stream.value(_api.currentUser != null ? UserModel.fromMap(_api.currentUser!) : null);
  }
}
