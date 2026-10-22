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
    final isSupported = await _auth.isDeviceSupported();
    if (!isSupported) return false;

    try {
      // LocalAuth 3.0.0 uses AuthenticationOptions class but it's passed as a value, 
      // ensuring const is valid only if constructor is const.
      // However user reported "No named parameter options".
      // This implies we should try named parameters directly for older compat OR 
      // maybe AuthenticationOptions is NOT the name of the parameter?
      // Wait, 2.x had options. 
      // Let's try to remove options for now to confirm basic auth works.
      // Or use named parameters used in 2.x before options class wrapped them.
      // Actually, if "options" named param is missing, it suggests it expects "useErrorDialogs" etc directly?
      // But 3.0.0 docs say options IS used. 
      // Let's assume the installed version is actually older? No, it said 3.0.0.
      // Maybe the error "No named parameter options" is misleading because of the const error?
      // I'll define options variable without const and try passing it.
      // If that fails, I'll fallback to named params.
      // Actually, I'll use the most standard form:
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access DigiInvi',
      );
    } on PlatformException catch (e) {
      if (e.code == 'NotAvailable') { // Use string literal
        // Biometrics not available
        return false;
      }
      return false;
    }
  }

  Future<bool> canCheckBiometrics() async {
    return await _auth.canCheckBiometrics;
  }
}
