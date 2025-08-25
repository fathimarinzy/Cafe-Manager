import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

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
}