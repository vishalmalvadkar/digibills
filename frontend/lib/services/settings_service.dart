import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/settings_model.dart';
import 'api_client.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final ApiClient _api = ApiClient();
  AppSettings? _cachedSettings;
  final StreamController<AppSettings> _settingsController =
      StreamController<AppSettings>.broadcast();

  AppSettings _getDefaultSettings() {
    return AppSettings(
      tenantName: 'My Business',
      contactEmail: '',
      contactPhone: '',
      bankName: '',
      accountNumber: '',
      ifscCode: '',
      accountHolderName: '',
      upiId: '',
      payeeName: '',
      gstNumber: '',
      address: '',
      city: '',
      district: '',
      pincode: '',
    );
  }

  void clearCache() {
    _cachedSettings = null;
  }

  Future<AppSettings> fetchSettings({bool forceRefresh = false}) async {
    if (_cachedSettings != null && !forceRefresh) return _cachedSettings!;
    try {
      final res = await _api.get('/api/v1/settings');
      if (res != null && res is Map<String, dynamic>) {
        _cachedSettings = AppSettings.fromMap(res);
        _settingsController.add(_cachedSettings!);
        return _cachedSettings!;
      }
    } catch (e) {
      debugPrint('Error fetchSettings: $e');
    }
    return _getDefaultSettings();
  }

  Future<AppSettings> fetchTenantSettings(String tenantId) async {
    return fetchSettings();
  }

  Stream<AppSettings> streamSettings() {
    if (_cachedSettings != null) {
      Timer.run(() => _settingsController.add(_cachedSettings!));
    }
    fetchSettings();
    return _settingsController.stream;
  }

  Future<void> updateSettings(AppSettings settings) async {
    try {
      final res = await _api.put('/api/v1/settings', body: settings.toMap());
      if (res != null && res is Map<String, dynamic>) {
        _cachedSettings = AppSettings.fromMap(res);
        _settingsController.add(_cachedSettings!);
      }
    } catch (e) {
      debugPrint('Error updating settings: $e');
      rethrow;
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await updateSettings(settings);
  }
}
