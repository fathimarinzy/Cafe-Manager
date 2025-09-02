// lib/services/offline_sync_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'firebase_service.dart';

class OfflineSyncService {
  static const String _pendingSyncKey = 'pending_offline_sync';
  static const String _lastSyncAttemptKey = 'last_sync_attempt';
  static const String _syncInProgressKey = 'sync_in_progress';
  
  // Minimum time between sync attempts (to avoid spam)
  static const Duration _minSyncInterval = Duration(seconds: 30);
  
  /// Check if there's offline registration data that needs syncing
  static Future<bool> hasPendingOfflineData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingSyncKey) ?? false;
  }
  
  /// Mark offline registration data as pending sync
  static Future<void> markOfflineDataPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingSyncKey, true);
    debugPrint('🔄 Offline registration data marked for sync');
  }
  
  /// Mark offline registration data as synced
  static Future<void> markOfflineDataSynced() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingSyncKey, false);
    await prefs.setString(_lastSyncAttemptKey, DateTime.now().toIso8601String());
    debugPrint('✅ Offline registration data marked as synced');
  }
  
  /// Check if sync is currently in progress
  static Future<bool> isSyncInProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncInProgressKey) ?? false;
  }
  
  /// Mark sync as in progress
  static Future<void> markSyncInProgress(bool inProgress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncInProgressKey, inProgress);
  }
  
  /// Check if enough time has passed since last sync attempt
  static Future<bool> canAttemptSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAttemptStr = prefs.getString(_lastSyncAttemptKey);
    
    if (lastAttemptStr == null) return true;
    
    final lastAttempt = DateTime.parse(lastAttemptStr);
    final now = DateTime.now();
    
    return now.difference(lastAttempt) >= _minSyncInterval;
  }
  
  /// Attempt to sync offline registration data to Firebase
  static Future<Map<String, dynamic>> syncOfflineRegistration() async {
    try {
      // Check if sync is already in progress
      if (await isSyncInProgress()) {
        return {
          'success': false,
          'message': 'Sync already in progress',
          'isInProgress': true,
        };
      }
      
      // Check if there's pending data to sync
      if (!await hasPendingOfflineData()) {
        return {
          'success': true,
          'message': 'No pending data to sync',
          'noDataToSync': true,
        };
      }
      
      // Check if enough time has passed since last attempt
      if (!await canAttemptSync()) {
        return {
          'success': false,
          'message': 'Too soon since last sync attempt. Please wait.',
          'rateLimited': true,
        };
      }
      
      await markSyncInProgress(true);
      
      // Get offline registration data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final businessName = prefs.getString('business_name') ?? '';
      final secondBusinessName = prefs.getString('second_business_name') ?? '';
      final businessAddress = prefs.getString('business_address') ?? '';
      final businessPhone = prefs.getString('business_phone') ?? '';
      final businessEmail = prefs.getString('business_email') ?? ''; // NEW: Get email
      final deviceId = prefs.getString('device_id') ?? '';
      
      // Debug: Print the retrieved data
      debugPrint('Sync data check:');
      debugPrint('  businessName: "$businessName"');
      debugPrint('  secondBusinessName: "$secondBusinessName"');
      debugPrint('  businessAddress: "$businessAddress"');
      debugPrint('  businessPhone: "$businessPhone"');
      debugPrint('  businessEmail: "$businessEmail"'); // NEW: Debug email
      debugPrint('  deviceId: "$deviceId"');
      
      // Get registration keys (for offline registration)
      final List<String> registrationKeys = [];
      final correctKeys = ['M2P016', 'A2L018', 'A2Z023', 'B2CAFE', 'M1U985'];
      registrationKeys.addAll(correctKeys);
      
      // More detailed validation with specific error messages
      if (businessName.isEmpty) {
        await markSyncInProgress(false);
        debugPrint('Sync validation failed: businessName is empty');
        return {
          'success': false,
          'message': 'Business name is required for sync',
          'invalidData': true,
          'missingField': 'businessName',
        };
      }
      
      if (deviceId.isEmpty) {
        await markSyncInProgress(false);
        debugPrint('Sync validation failed: deviceId is empty');
        return {
          'success': false,
          'message': 'Device ID is required for sync',
          'invalidData': true,
          'missingField': 'deviceId',
        };
      }
      
      if (businessAddress.isEmpty) {
        await markSyncInProgress(false);
        debugPrint('Sync validation failed: businessAddress is empty');
        return {
          'success': false,
          'message': 'Business address is required for sync',
          'invalidData': true,
          'missingField': 'businessAddress',
        };
      }
      
      if (businessPhone.isEmpty) {
        await markSyncInProgress(false);
        debugPrint('Sync validation failed: businessPhone is empty');
        return {
          'success': false,
          'message': 'Business phone is required for sync',
          'invalidData': true,
          'missingField': 'businessPhone',
        };
      }
      
      debugPrint('🔄 Attempting to sync offline registration to Firebase...');
      
      // Attempt to store in Firebase
      final result = await FirebaseService.storeOfflineRegistration(
        businessName: businessName,
        secondBusinessName: secondBusinessName,
        businessAddress: businessAddress,
        businessPhone: businessPhone,
        businessEmail: businessEmail,
        deviceId: deviceId,
        registrationKeys: registrationKeys,
      );
      
      await markSyncInProgress(false);
      
      if (result['success']) {
        await markOfflineDataSynced();
        debugPrint('✅ Offline registration synced successfully');
        
        return {
          'success': true,
          'message': 'Offline registration synced successfully',
          'companyId': result['companyId'],
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to sync offline registration',
          'firebaseError': true,
        };
      }
      
    } catch (e) {
      await markSyncInProgress(false);
      debugPrint('❌ Error syncing offline registration: $e');
      
      return {
        'success': false,
        'message': 'Error syncing offline registration: ${e.toString()}',
        'exception': true,
      };
    }
  }
  
  /// Check internet connectivity and sync if available
  static Future<Map<String, dynamic>> checkAndSync() async {
    try {
      // Ensure Firebase is initialized
      await FirebaseService.ensureInitialized();
      
      // Check if Firebase is available (internet connection)
      if (!FirebaseService.isFirebaseAvailable) {
        return {
          'success': false,
          'message': 'No internet connection available',
          'noConnection': true,
        };
      }
      
      return await syncOfflineRegistration();
      
    } catch (e) {
      debugPrint('❌ Error in checkAndSync: $e');
      return {
        'success': false,
        'message': 'Error checking connectivity: ${e.toString()}',
        'exception': true,
      };
    }
  }
  
  /// Auto-sync in background (non-blocking)
  static void autoSync() {
    // Run in background without blocking UI
    Timer.periodic(const Duration(minutes: 10), (timer) async {
      try {
        if (await hasPendingOfflineData() && await canAttemptSync()) {
          debugPrint('🔄 Auto-sync: Attempting to sync offline data...');
          final result = await checkAndSync();
          
          if (result['success']) {
            debugPrint('✅ Auto-sync: Offline data synced successfully');
            timer.cancel(); // Stop auto-sync after successful sync
          } else if (result['noConnection'] != true) {
            // If it's not a connection issue, log the error
            debugPrint('⚠️ Auto-sync failed: ${result['message']}');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Auto-sync error: $e');
      }
    });
  }
  
  /// Force sync (ignore rate limiting)
  static Future<Map<String, dynamic>> forceSyncOfflineRegistration() async {
    try {
      await markSyncInProgress(true);
      
      // Get offline registration data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final businessName = prefs.getString('business_name') ?? '';
      final secondBusinessName = prefs.getString('second_business_name') ?? '';
      final businessAddress = prefs.getString('business_address') ?? '';
      final businessPhone = prefs.getString('business_phone') ?? '';
      final businessEmail = prefs.getString('business_email') ?? ''; // NEW: Get email
      final deviceId = prefs.getString('device_id') ?? '';
      
      // Debug: Print the retrieved data for force sync
      debugPrint('Force sync data check:');
      debugPrint('  businessName: "$businessName"');
      debugPrint('  secondBusinessName: "$secondBusinessName"');
      debugPrint('  businessAddress: "$businessAddress"');
      debugPrint('  businessPhone: "$businessPhone"');
      debugPrint('  businessEmail: "$businessEmail"'); // NEW: Debug email
      debugPrint('  deviceId: "$deviceId"');
      
      // Get registration keys (for offline registration)
      final List<String> registrationKeys = [];
      final correctKeys = ['M2P016', 'A2L018', 'A2Z023', 'B2CAFE', 'M1U985'];
      registrationKeys.addAll(correctKeys);
      
      // More detailed validation with specific error messages
      if (businessName.isEmpty) {
        await markSyncInProgress(false);
        debugPrint('Force sync validation failed: businessName is empty');
        return {
          'success': false,
          'message': 'Business name is required for sync',
          'invalidData': true,
          'missingField': 'businessName',
        };
      }
      
      if (deviceId.isEmpty) {
        await markSyncInProgress(false);
        debugPrint('Force sync validation failed: deviceId is empty');
        return {
          'success': false,
          'message': 'Device ID is required for sync',
          'invalidData': true,
          'missingField': 'deviceId',
        };
      }
      
      if (businessAddress.isEmpty) {
        await markSyncInProgress(false);
        debugPrint('Force sync validation failed: businessAddress is empty');
        return {
          'success': false,
          'message': 'Business address is required for sync',
          'invalidData': true,
          'missingField': 'businessAddress',
        };
      }
      
      if (businessPhone.isEmpty) {
        await markSyncInProgress(false);
        debugPrint('Force sync validation failed: businessPhone is empty');
        return {
          'success': false,
          'message': 'Business phone is required for sync',
          'invalidData': true,
          'missingField': 'businessPhone',
        };
      }
      
      debugPrint('🔄 Force syncing offline registration to Firebase...');
      
      // Attempt to store in Firebase
      final result = await FirebaseService.storeOfflineRegistration(
        businessName: businessName,
        secondBusinessName: secondBusinessName,
        businessAddress: businessAddress,
        businessPhone: businessPhone,
        businessEmail: businessEmail,
        deviceId: deviceId,
        registrationKeys: registrationKeys,
      );
      
      await markSyncInProgress(false);
      
      if (result['success']) {
        await markOfflineDataSynced();
        debugPrint('✅ Offline registration force synced successfully');
        
        return {
          'success': true,
          'message': 'Offline registration synced successfully',
          'companyId': result['companyId'],
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to sync offline registration',
          'firebaseError': true,
        };
      }
      
    } catch (e) {
      await markSyncInProgress(false);
      debugPrint('❌ Error force syncing offline registration: $e');
      
      return {
        'success': false,
        'message': 'Error syncing offline registration: ${e.toString()}',
        'exception': true,
      };
    }
  }
  
  /// Get sync status information
  static Future<Map<String, dynamic>> getSyncStatus() async {
    final hasPending = await hasPendingOfflineData();
    final inProgress = await isSyncInProgress();
    final canSync = await canAttemptSync();
    
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncAttemptKey);
    DateTime? lastSync;
    if (lastSyncStr != null) {
      lastSync = DateTime.parse(lastSyncStr);
    }
    
    return {
      'hasPendingData': hasPending,
      'syncInProgress': inProgress,
      'canAttemptSync': canSync,
      'lastSyncAttempt': lastSync?.toIso8601String(),
      'isFirebaseAvailable': FirebaseService.isFirebaseAvailable,
    };
  }
  
  /// Clear all sync data (for testing/reset purposes)
  static Future<void> clearSyncData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingSyncKey);
    await prefs.remove(_lastSyncAttemptKey);
    await prefs.remove(_syncInProgressKey);
    debugPrint('🧹 Sync data cleared');
  }

  /// Debug method to check what registration data is actually stored
  static Future<Map<String, dynamic>> debugStoredRegistrationData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final data = {
      'business_name': prefs.getString('business_name'),
      'second_business_name': prefs.getString('second_business_name'),
      'business_address': prefs.getString('business_address'),
      'business_phone': prefs.getString('business_phone'),
      'business_email': prefs.getString('business_email'), // NEW: Include email in debug
      'device_id': prefs.getString('device_id'),
      'company_registered': prefs.getBool('company_registered'),
      'device_registered': prefs.getBool('device_registered'),
      'device_mode': prefs.getString('device_mode'),
      'pending_offline_sync': prefs.getBool(_pendingSyncKey),
    };
    
    debugPrint('=== STORED REGISTRATION DATA DEBUG ===');
    data.forEach((key, value) {
      debugPrint('$key: $value');
    });
    debugPrint('=== END DEBUG ===');
    
    return data;
  }
}