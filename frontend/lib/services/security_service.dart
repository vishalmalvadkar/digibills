import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  static const _pinKey = 'user_pin';
  static const _biometricKey = 'biometric_enabled';
  static const _enabledKey = 'pin_lock_enabled';

  // --- PIN Management ---

  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    final storedPin = await _storage.read(key: _pinKey);
    return storedPin == pin;
  }

  Future<bool> isPinSet() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
    await setPinEnabled(false);
    await setBiometricEnabled(false); // Disable biometric if PIN is removed
  }

  Future<bool> isPinEnabled() async {
    final val = await _storage.read(key: _enabledKey);
    return val == 'true';
  }

  Future<void> setPinEnabled(bool enabled) async {
    await _storage.write(key: _enabledKey, value: enabled.toString());
  }

  // --- Biometric Management ---

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricKey, value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _biometricKey);
    return val == 'true';
  }

  Future<bool> authenticatedBiometric() async {
    if (kIsWeb) return false;
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;

      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access DigiInvi',
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> canCheckBiometrics() async {
    if (kIsWeb) return false;
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }
}
