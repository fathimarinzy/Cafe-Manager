import 'dart:async';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';
import 'offline_sync_service.dart';

class ConnectivityMonitor {
  static ConnectivityMonitor? _instance;
  static ConnectivityMonitor get instance => _instance ??= ConnectivityMonitor._();
  
  ConnectivityMonitor._();
  
  Timer? _connectivityTimer;
  bool _isMonitoring = false;
  bool _wasOffline = false;
  
  /// Start monitoring connectivity and auto-sync when restored
  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    debugPrint('🔄 Starting connectivity monitoring...');
    
    // Check connectivity every 30 seconds
    _connectivityTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _checkConnectivityAndSync();
    });
    
    // Initial check
    _checkConnectivityAndSync();
  }
  
  /// Stop monitoring connectivity
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    _connectivityTimer?.cancel();
    _connectivityTimer = null;
    
    debugPrint('🛑 Stopped connectivity monitoring');
  }
  
  /// Check connectivity and sync if connection is restored
  Future<void> _checkConnectivityAndSync() async {
    try {
      // Ensure Firebase is initialized
      await FirebaseService.ensureInitialized();
      
      final isOnline = FirebaseService.isFirebaseAvailable;
      
      // If we just came back online and have pending data
      if (isOnline && _wasOffline) {
        debugPrint('🌐 Internet connection restored - checking for pending sync...');
        
        final hasPendingData = await OfflineSyncService.hasPendingOfflineData();
        
        if (hasPendingData) {
          debugPrint('🔄 Found pending offline data - attempting sync...');
          
          final syncResult = await OfflineSyncService.syncOfflineRegistration();
          
          if (syncResult['success']) {
            debugPrint('✅ Auto-sync successful after connectivity restore');
            
            // NEW: Update any UI that might be listening for sync completion
            _notifySyncCompletion(true, 'Business information synced to cloud successfully');
          } else {
            debugPrint('⚠️ Auto-sync failed: ${syncResult['message']}');
            _notifySyncCompletion(false, syncResult['message']);
          }
        }
      }
      
      _wasOffline = !isOnline;
      
    } catch (e) {
      debugPrint('⚠️ Error in connectivity check: $e');
    }
  }
  
  /// NEW: Notify about sync completion (can be used to update UI)
  void _notifySyncCompletion(bool success, String message) {
    // This could be expanded to use a stream controller or callback
    // For now, just log the completion
    if (success) {
      debugPrint('✅ Sync notification: $message');
    } else {
      debugPrint('❌ Sync notification: $message');
    }
  }
  
  /// Force check connectivity and sync now
  Future<Map<String, dynamic>> checkAndSyncNow() async {
    try {
      debugPrint('🔄 Manual connectivity check and sync...');
      
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        return {
          'success': false,
          'message': 'No internet connection available',
          'noConnection': true,
        };
      }
      
      final result = await OfflineSyncService.syncOfflineRegistration();
      
      if (result['success']) {
        debugPrint('✅ Manual sync successful');
      } else {
        debugPrint('⚠️ Manual sync failed: ${result['message']}');
      }
      
      return result;
      
    } catch (e) {
      debugPrint('❌ Error in manual connectivity check: $e');
      return {
        'success': false,
        'message': 'Error during sync: ${e.toString()}',
        'exception': true,
      };
    }
  }
  
  /// Get current connectivity status
  Future<Map<String, dynamic>> getConnectivityStatus() async {
    await FirebaseService.ensureInitialized();
    
    return {
      'isOnline': FirebaseService.isFirebaseAvailable,
      'isMonitoring': _isMonitoring,
      'wasOffline': _wasOffline,
    };
  }
  
  /// Dispose of resources
  void dispose() {
    stopMonitoring();
  }
}