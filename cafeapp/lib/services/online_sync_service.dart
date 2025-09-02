// lib/services/online_sync_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';
import '../services/demo_service.dart';
import 'offline_sync_service.dart';

class OnlineSyncService {
  /// Sync business information for online or demo registration
  static Future<Map<String, dynamic>> syncBusinessInfo({
    required String businessName,
    String? secondBusinessName,
    required String businessAddress,
    required String businessPhone,
    required String businessEmail,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id');
      final registrationMode = prefs.getString('registration_mode') ?? 'offline';
      final isDemoMode = await DemoService.isDemoMode();
      
      debugPrint('🔄 Syncing business info - Mode: $registrationMode, Demo: $isDemoMode, CompanyId: $companyId');
      
      if (isDemoMode) {
        // Handle demo registration sync
        String? companyId = prefs.getString('company_id');
        
        // If no company ID is stored locally, try to get it from Firebase
        if (companyId == null || companyId.isEmpty) {
          debugPrint('No local company ID found, attempting to retrieve from Firebase...');
          
          final deviceId = prefs.getString('device_id') ?? '';
          if (deviceId.isNotEmpty) {
            final demoDetails = await FirebaseService.getDemoDetails(deviceId);
            
            if (demoDetails['success'] && demoDetails['isRegistered']) {
              companyId = demoDetails['companyId'];
              
              // Store it locally for future use
              if (companyId != null && companyId.isNotEmpty) {
                await prefs.setString('company_id', companyId);
                debugPrint('✅ Retrieved and stored demo company ID: $companyId');
              }
            }
          }
        }
        
        if (companyId != null && companyId.isNotEmpty) {
          final result = await FirebaseService.updateDemoRegistrationInfo(
            companyId: companyId,
            businessName: businessName,
            secondBusinessName: secondBusinessName,
            businessAddress: businessAddress,
            businessPhone: businessPhone,
            businessEmail: businessEmail,
          );
          
          if (result['success']) {
            debugPrint('✅ Demo business info synced successfully');
            return {
              'success': true,
              'message': 'Demo business information synced to cloud successfully',
              'type': 'demo',
            };
          } else {
            return result;
          }
        } else {
          return {
            'success': false,
            'message': 'No demo company ID found - unable to sync business information',
            'type': 'demo',
          };
        }
      } else if (registrationMode == 'online' && companyId != null && companyId.isNotEmpty) {
        // Handle online registration sync
        final result = await FirebaseService.updateOnlineRegistrationInfo(
          companyId: companyId,
          businessName: businessName,
          secondBusinessName: secondBusinessName,
          businessAddress: businessAddress,
          businessPhone: businessPhone,
          businessEmail: businessEmail,
        );
        
        if (result['success']) {
          debugPrint('✅ Online business info synced successfully');
          return {
            'success': true,
            'message': 'Business information synced to cloud successfully',
            'type': 'online',
          };
        } else {
          return result;
        }
      } else {
        // Handle offline registration sync (use existing offline sync service)
        debugPrint('🔄 Using offline sync service for business info...');
        
        // Update local storage first
        await prefs.setString('business_name', businessName);
        await prefs.setString('second_business_name', secondBusinessName ?? '');
        await prefs.setString('business_address', businessAddress);
        await prefs.setString('business_phone', businessPhone);
        await prefs.setString('business_email', businessEmail);
        
        // Use existing offline sync logic
        await OfflineSyncService.markOfflineDataPending();
        
        final syncResult = await OfflineSyncService.forceSyncOfflineRegistration();
        
        return {
          'success': syncResult['success'] ?? false,
          'message': syncResult['message'] ?? 'Offline sync attempted',
          'type': 'offline',
          'syncResult': syncResult,
        };
      }
    } catch (e) {
      debugPrint('❌ Error in business info sync: $e');
      return {
        'success': false,
        'message': 'Error syncing business information: ${e.toString()}',
        'exception': true,
      };
    }
  }
  
  /// Check what type of registration this device has
  static Future<String> getRegistrationType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDemoMode = await DemoService.isDemoMode();
      final registrationMode = prefs.getString('registration_mode') ?? 'offline';
      
      if (isDemoMode) {
        return 'demo';
      } else if (registrationMode == 'online') {
        return 'online';
      } else {
        return 'offline';
      }
    } catch (e) {
      debugPrint('Error determining registration type: $e');
      return 'offline'; // Default fallback
    }
  }
}