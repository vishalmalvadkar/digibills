import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'api_client.dart';
import 'settings_service.dart';

class AuthService {
  final ApiClient _api = ApiClient();

  Future<sb.User?> signIn(String email, String password) async {
    try {
      final res = await _api.post('/api/v1/auth/login', body: {
        'email': email,
        'password': password,
      });

      if (res != null && res['access_token'] != null) {
        final token = res['access_token'] as String;
        final userData = res['user'] as Map<String, dynamic>;
        await _api.saveSession(token, userData);

        final sbUser = sb.User(
          id: userData['uid'],
          appMetadata: {},
          userMetadata: userData,
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: userData['email'],
        );

        _authStateController.add(sbUser);
        return sbUser;
      }
      return null;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<sb.User?> signUp(String email, String password, {String? name}) async {
    try {
      final res = await _api.post('/api/v1/auth/signup', body: {
        'email': email,
        'password': password,
        if (name != null) 'name': name,
        'role': 'client',
      });

      if (res != null && res['access_token'] != null) {
        final token = res['access_token'] as String;
        final userData = res['user'] as Map<String, dynamic>;
        await _api.saveSession(token, userData);

        final sbUser = sb.User(
          id: userData['uid'],
          appMetadata: {},
          userMetadata: userData,
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: userData['email'],
        );

        _authStateController.add(sbUser);
        return sbUser;
      }
      return null;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    // Password reset endpoint can be added or logged
  }

  static final StreamController<sb.User?> _authStateController =
      StreamController<sb.User?>.broadcast();

  Stream<sb.User?> get authStateChanges => _authStateController.stream;

  Future<void> signOut() async {
    SettingsService().clearCache();
    await _api.clearSession();
    _authStateController.add(null);
  }

  String get currentTenantId => _api.currentTenantId;

  Future<String> getEffectiveTenantId() async {
    return _api.currentTenantId;
  }

  sb.User? get currentUser {
    final user = _api.currentUser;
    if (user == null || _api.token == null) return null;
    return sb.User(
      id: user['uid'] ?? '',
      appMetadata: {},
      userMetadata: user,
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: user['email'],
    );
  }
}
