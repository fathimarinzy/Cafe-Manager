// lib/services/demo_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

class DemoService {
  static const String _demoStartDateKey = 'demo_start_date';
  static const String _isDemoModeKey = 'is_demo_mode';
  static const int _demoDaysLimit = 30;

  // Demo user credentials
  static const String demoUsername = 'admin';
  static const String demoPassword = 'admin123';

  // Start demo mode and store in Firebase
  static Future<Map<String, dynamic>> startDemo({
    required String businessName,
    String? secondBusinessName,
    required String businessAddress,
    required String businessPhone,
    required String businessEmail,
    required String deviceId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      // Store demo info in Firebase
      final firebaseResult = await FirebaseService.storeDemoRegistration(
        businessName: businessName,
        secondBusinessName: secondBusinessName,
        businessAddress: businessAddress,
        businessPhone: businessPhone,
        businessEmail: businessEmail,
        deviceId: deviceId,
      );

      if (firebaseResult['success']) {
        // Store local demo data
        await prefs.setString(_demoStartDateKey, now.toIso8601String());
        await prefs.setBool(_isDemoModeKey, true);
        await prefs.setBool('company_registered', true);
        await prefs.setBool('device_registered', true);
        await prefs.setString('registration_mode', 'demo');
        await prefs.setString('demo_company_id', firebaseResult['companyId']);

        return {
          'success': true,
          'companyId': firebaseResult['companyId'],
          'message': 'Demo registration successful',
        };
      } else {
        return firebaseResult;
      }
    } catch (e) {
      debugPrint('Error starting demo: $e');
      return {
        'success': false,
        'message': 'Failed to start demo: $e',
      };
    }
  }

  // Check if demo is active
  static Future<bool> isDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isDemoModeKey) ?? false;
  }

  // Check if demo is expired
  static Future<bool> isDemoExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final isDemoMode = prefs.getBool(_isDemoModeKey) ?? false;
    
    if (!isDemoMode) return false;
    
    final startDateStr = prefs.getString(_demoStartDateKey);
    if (startDateStr == null) return true;
    
    final startDate = DateTime.parse(startDateStr);
    final now = DateTime.now();
    final daysDifference = now.difference(startDate).inDays;
    
    return daysDifference >= _demoDaysLimit;
  }

  // Get remaining demo days
  static Future<int> getRemainingDemoDays() async {
    final prefs = await SharedPreferences.getInstance();
    final isDemoMode = prefs.getBool(_isDemoModeKey) ?? false;
    
    if (!isDemoMode) return 0;
    
    final startDateStr = prefs.getString(_demoStartDateKey);
    if (startDateStr == null) return 0;
    
    final startDate = DateTime.parse(startDateStr);
    final now = DateTime.now();
    final daysDifference = now.difference(startDate).inDays;
    final remainingDays = _demoDaysLimit - daysDifference;
    
    return remainingDays > 0 ? remainingDays : 0;
  }

  // End demo mode
  static Future<void> endDemo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_demoStartDateKey);
    await prefs.setBool(_isDemoModeKey, false);
    await prefs.setBool('company_registered', false);
    await prefs.setBool('device_registered', false);
    await prefs.remove('registration_mode');
  }

  // Get demo start date
  static Future<DateTime?> getDemoStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    final startDateStr = prefs.getString(_demoStartDateKey);
    if (startDateStr == null) return null;
    return DateTime.parse(startDateStr);
  }
}