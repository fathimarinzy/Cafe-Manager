import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'firebase_service.dart';

class LicenseService {
  static const String _licenseStartDateKey = 'license_start_date';
  static const String _companyRegisteredKey = 'company_registered';
  static const int _licenseDurationDays = 365; // 1 year

  /// Check if user has a valid license (is registered and not expired)
  static Future<bool> hasValidLicense() async {
    final prefs = await SharedPreferences.getInstance();
    final isRegistered = prefs.getBool(_companyRegisteredKey) ?? false;
    
    if (!isRegistered) return false;
    
    return !await isLicenseExpired();
  }

  /// Check if license is expired
  static Future<bool> isLicenseExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final isRegistered = prefs.getBool(_companyRegisteredKey) ?? false;
    
    if (!isRegistered) return false;
    
    final startDateString = prefs.getString(_licenseStartDateKey);
    if (startDateString == null) return false;
    
    final startDate = DateTime.parse(startDateString);
    final expiryDate = startDate.add(Duration(days: _licenseDurationDays));
    
    return DateTime.now().isAfter(expiryDate);
  }

  /// Get remaining days in license
  static Future<int> getRemainingLicenseDays() async {
    final prefs = await SharedPreferences.getInstance();
    final isRegistered = prefs.getBool(_companyRegisteredKey) ?? false;
    
    if (!isRegistered) return 0;
    
    final startDateString = prefs.getString(_licenseStartDateKey);
    if (startDateString == null) return 0;
    
    final startDate = DateTime.parse(startDateString);
    final expiryDate = startDate.add(Duration(days: _licenseDurationDays));
    final now = DateTime.now();
    
    if (now.isAfter(expiryDate)) return 0;
    
    return expiryDate.difference(now).inDays;
  }

  /// Get license expiry date
  static Future<DateTime?> getLicenseExpiryDate() async {
    final prefs = await SharedPreferences.getInstance();
    final startDateString = prefs.getString(_licenseStartDateKey);
    
    if (startDateString == null) return null;
    
    final startDate = DateTime.parse(startDateString);
    return startDate.add(Duration(days: _licenseDurationDays));
  }

  /// Set license start date (call this when user registers)
  static Future<void> setLicenseStartDate([DateTime? startDate]) async {
    final prefs = await SharedPreferences.getInstance();
    final dateToSet = startDate ?? DateTime.now();
    await prefs.setString(_licenseStartDateKey, dateToSet.toIso8601String());
    debugPrint('License start date set: $dateToSet');
  }

  /// Check if user is registered (company registered)
  static Future<bool> isUserRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_companyRegisteredKey) ?? false;
  }

  /// Get license duration in days
  static int getLicenseDurationDays() => _licenseDurationDays;

  /// Reset license (for testing purposes)
  static Future<void> resetLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseStartDateKey);
    debugPrint('License data reset');
  }

  /// Check license status and return detailed info
  static Future<Map<String, dynamic>> getLicenseStatus() async {
    final isRegistered = await isUserRegistered();
    final isExpired = await isLicenseExpired();
    final remainingDays = await getRemainingLicenseDays();
    final expiryDate = await getLicenseExpiryDate();
    final hasValid = await hasValidLicense();
    
    return {
      'isRegistered': isRegistered,
      'isExpired': isExpired,
      'remainingDays': remainingDays,
      'expiryDate': expiryDate,
      'hasValidLicense': hasValid,
      'totalDays': _licenseDurationDays,
    };
  }
   /// Renew license for another year
  static Future<Map<String, dynamic>> renewLicense() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isRegistered = prefs.getBool(_companyRegisteredKey) ?? false;
      
      if (!isRegistered) {
        return {
          'success': false,
          'message': 'Company is not registered',
        };
      }

      // Set new license start date to current time
      final now = DateTime.now();
      await prefs.setString(_licenseStartDateKey, now.toIso8601String());

      debugPrint('✅ License renewed for another year');
      
      return {
        'success': true,
        'message': 'License renewed successfully',
        'newStartDate': now.toIso8601String(),
        'newExpiryDate': now.add(Duration(days: _licenseDurationDays)).toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error renewing license: $e');
      return {
        'success': false,
        'message': 'Failed to renew license: $e',
      };
    }
  }

  /// Check if license can be renewed (user is registered)
  static Future<bool> canRenewLicense() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_companyRegisteredKey) ?? false;
  }

  /// Get license renewal info
  static Future<Map<String, dynamic>> getLicenseRenewalInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final isRegistered = prefs.getBool(_companyRegisteredKey) ?? false;
    
    if (!isRegistered) {
      return {
        'canRenew': false,
        'message': 'Company not registered',
      };
    }

    final startDateString = prefs.getString(_licenseStartDateKey);
    if (startDateString == null) {
      return {
        'canRenew': false,
        'message': 'No license start date found',
      };
    }

    final startDate = DateTime.parse(startDateString);
    final expiryDate = startDate.add(Duration(days: _licenseDurationDays));
    final now = DateTime.now();
    final isExpired = now.isAfter(expiryDate);
    final remainingDays = isExpired ? 0 : expiryDate.difference(now).inDays;

    return {
      'canRenew': true,
      'isExpired': isExpired,
      'startDate': startDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'remainingDays': remainingDays,
      'totalDays': _licenseDurationDays,
    };
  }

  /// Get number of times license has been renewed (based on renewals in last 5 years)
  static Future<int> getRenewalCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      if (deviceId == null) return 0;

      // Get renewal history from Firebase (implement this in FirebaseService if needed)
      final renewalHistory = await FirebaseService.getRenewalHistory(deviceId);
      if (renewalHistory['success']) {
        final renewals = renewalHistory['renewals'] as List;
        return renewals.where((renewal) => 
          renewal['renewalType'] == 'RenewalType.license'
        ).length;
      }
      
      return 0;
    } catch (e) {
      debugPrint('Error getting renewal count: $e');
      return 0;
    }
  }
}