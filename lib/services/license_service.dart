import '../models/license_model.dart';
import '../models/user_model.dart';

class LicenseService {
  
  /// Checks if the license is valid.
  /// Returns `true` if:
  /// 1. License is missing (Graceful fallback)
  /// 2. License is active AND current date is before end date.
  bool isLicenseValid(UserModel user) {
    final license = user.license;
    
    // Graceful fallback: If no license data, assume valid/legacy user
    if (license == null) {
      return true;
    }

    if (!license.isActive) {
      return false;
    }

    final now = DateTime.now();
    // Use end of day for expiry check to be generous? 
    // Or strict comparison. Standard is strict.
    if (now.isAfter(license.endDate)) {
      return false;
    }

    return true;
  }

  /// Calculates days remaining.
  int daysRemaining(UserModel user) {
    if (user.license == null) return 9999; // Infinite
    final now = DateTime.now();
    return user.license!.endDate.difference(now).inDays;
  }
}
