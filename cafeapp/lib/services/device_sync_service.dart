// lib/services/device_sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_model.dart';
import '../models/device_link_model.dart';
import '../models/order.dart' as local_models;
import '../models/sync_order_model.dart' as sync_models;
import '../repositories/local_order_repository.dart';
import 'firebase_service.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../services/menu_sync_service.dart';

class DeviceSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _devicesCollection = 'devices';
  static const String _ordersCollection = 'synced_orders';
  static const String _linkCodesCollection = 'device_link_codes';
  
  static Timer? _syncTimer;
  static StreamSubscription? _orderSubscription;

  /// Generate a 6-digit linking code for staff devices
  static Future<Map<String, dynamic>> generateLinkCode() async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        return {
          'success': false,
          'message': 'No internet connection',
          'isOffline': true,
        };
      }

      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id') ?? '';
      final deviceId = prefs.getString('device_id') ?? '';
      final deviceName = prefs.getString('device_name') ?? 'Main Device';
      final isMainDevice = prefs.getBool('is_main_device') ?? false;
      
      if (companyId.isEmpty || deviceId.isEmpty) {
        return {
          'success': false,
          'message': 'Device not properly configured',
        };
      }

      if (!isMainDevice) {
        return {
          'success': false,
          'message': 'Only main device can generate link codes',
        };
      }

      // Generate a unique 6-digit code
      String code;
      bool codeExists;
      do {
        code = _generateSixDigitCode();
        
        // Check if code already exists and is valid
        final existingCodes = await _firestore
            .collection(_linkCodesCollection)
            .where('code', isEqualTo: code)
            .where('isUsed', isEqualTo: false)
            .get();
        
        codeExists = existingCodes.docs.any((doc) {
          final data = doc.data();
          final expiresAt = DateTime.parse(data['expiresAt'] as String);
          return DateTime.now().isBefore(expiresAt);
        });
      } while (codeExists);

      // Create link code that expires in 24 hours
      final linkCode = DeviceLinkCode(
        code: code,
        companyId: companyId,
        mainDeviceId: deviceId,
        mainDeviceName: deviceName,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      await _firestore
          .collection(_linkCodesCollection)
          .add(linkCode.toJson());

      debugPrint('✅ Link code generated: $code');

      return {
        'success': true,
        'code': code,
        'expiresAt': linkCode.expiresAt.toIso8601String(),
        'message': 'Link code generated successfully',
      };
    } catch (e) {
      debugPrint('❌ Error generating link code: $e');
      return {
        'success': false,
        'message': 'Failed to generate link code: ${e.toString()}',
      };
    }
  }

  /// Link staff device using 6-digit code
   static Future<Map<String, dynamic>> linkDeviceWithCode({
    required String code,
    required String staffDeviceName,
  }) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        return {
          'success': false,
          'message': 'No internet connection',
          'isOffline': true,
        };
      }

      final prefs = await SharedPreferences.getInstance();
      final currentDeviceId = prefs.getString('device_id') ?? '';
      
      if (currentDeviceId.isEmpty) {
        return {
          'success': false,
          'message': 'Device ID not found',
        };
      }

      // Find the link code
      final linkCodeDocs = await _firestore
          .collection(_linkCodesCollection)
          .where('code', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      if (linkCodeDocs.docs.isEmpty) {
        return {
          'success': false,
          'message': 'Invalid code',
        };
      }

      final linkCodeData = linkCodeDocs.docs.first.data();
      final linkCode = DeviceLinkCode.fromJson(linkCodeData);

      // Validate the code
      if (linkCode.isUsed) {
        return {
          'success': false,
          'message': 'This code has already been used',
        };
      }

      if (linkCode.isExpired) {
        return {
          'success': false,
          'message': 'This code has expired',
        };
      }

      // Get device type
      String deviceType = 'unknown';
      try {
        if (Platform.isAndroid) {
          deviceType = 'android';
        } else if (Platform.isWindows) {
          deviceType = 'windows';
        } else if (Platform.isMacOS) {
          deviceType = 'macos';
        } else if (Platform.isLinux) {
          deviceType = 'linux';
        }
      } catch (e) {
        deviceType = 'web';
      }

      // Register this device with the same company ID
      final deviceData = DeviceModel(
        id: currentDeviceId,
        deviceName: staffDeviceName,
        deviceType: deviceType,
        companyId: linkCode.companyId,
        isMainDevice: false,
        registeredAt: DateTime.now(),
        lastSyncedAt: DateTime.now(),
      ).toJson();

      await _firestore
          .collection(_devicesCollection)
          .add(deviceData);

      // Mark the link code as used
      await linkCodeDocs.docs.first.reference.update({
        'isUsed': true,
        'usedByDeviceId': currentDeviceId,
        'usedByDeviceName': staffDeviceName,
        'usedAt': FieldValue.serverTimestamp(),
      });

      // Save to local preferences
      await prefs.setString('company_id', linkCode.companyId);
      await prefs.setBool('device_sync_enabled', true);
      await prefs.setBool('is_main_device', false);
      await prefs.setString('device_name', staffDeviceName);
      await prefs.setBool('company_registered', true);

      // Copy business info from main device
      await _copyBusinessInfoFromMainDevice(linkCode.companyId);

      // 🆕 INITIALIZE MENU SYNC - fetch all menu items from main device
      debugPrint('🔄 Initializing menu sync for staff device...');
      await MenuSyncService.initializeMenuSync(linkCode.companyId);

      debugPrint('✅ Device linked successfully to company: ${linkCode.companyId}');

      return {
        'success': true,
        'message': 'Device linked successfully',
        'companyId': linkCode.companyId,
        'mainDeviceName': linkCode.mainDeviceName,
      };
    } catch (e) {
      debugPrint('❌ Error linking device: $e');
      return {
        'success': false,
        'message': 'Failed to link device: ${e.toString()}',
      };
    }
  }

  /// Copy business information from main device
  static Future<void> _copyBusinessInfoFromMainDevice(String companyId) async {
    try {
      // Get company details from Firebase
      final companyDetails = await FirebaseService.getCompanyDetails(companyId);
      
      if (companyDetails['success'] && companyDetails['isRegistered']) {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('business_name', companyDetails['businessName'] ?? '');
        await prefs.setString('second_business_name', companyDetails['secondBusinessName'] ?? '');
        await prefs.setString('business_address', companyDetails['businessAddress'] ?? '');
        await prefs.setString('business_phone', companyDetails['businessPhone'] ?? '');
        await prefs.setString('business_email', companyDetails['businessEmail'] ?? '');
        
        debugPrint('✅ Business info copied from main device');
      }
    } catch (e) {
      debugPrint('⚠️ Error copying business info: $e');
    }
  }

  /// Generate a random 6-digit code
  static String _generateSixDigitCode() {
    final random = Random();
    // Generate 6-digit code (100000 to 999999)
    final code = (random.nextInt(900000) + 100000).toString();
    return code;
  }

  /// Get all active link codes for main device
  static Future<List<DeviceLinkCode>> getActiveLinkCodes() async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        return [];
      }

      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id') ?? '';
      
      if (companyId.isEmpty) {
        return [];
      }

      final snapshot = await _firestore
          .collection(_linkCodesCollection)
          .where('companyId', isEqualTo: companyId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => DeviceLinkCode.fromJson(doc.data()))
          .where((code) => !code.isExpired)
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting link codes: $e');
      return [];
    }
  }

  /// Register main device (initial setup)
  static Future<Map<String, dynamic>> registerMainDevice({
    required String deviceName,
  }) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        return {
          'success': false,
          'message': 'No internet connection',
          'isOffline': true,
        };
      }

      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id') ?? '';
      final currentDeviceId = prefs.getString('device_id') ?? '';
      
      if (companyId.isEmpty || currentDeviceId.isEmpty) {
        return {
          'success': false,
          'message': 'Company or device not properly configured',
        };
      }

      // Get device type
      String deviceType = 'unknown';
      try {
        if (Platform.isAndroid) {
          deviceType = 'android';
        } else if (Platform.isWindows) {
          deviceType = 'windows';
        } else if (Platform.isMacOS) {
          deviceType = 'macos';
        } else if (Platform.isLinux) {
          deviceType = 'linux';
        }
      } catch (e) {
        deviceType = 'web';
      }

      // Check if device already exists
      final existingDevice = await _firestore
          .collection(_devicesCollection)
          .where('id', isEqualTo: currentDeviceId)
          .where('companyId', isEqualTo: companyId)
          .limit(1)
          .get();

      final deviceData = DeviceModel(
        id: currentDeviceId,
        deviceName: deviceName,
        deviceType: deviceType,
        companyId: companyId,
        isMainDevice: true,
        registeredAt: DateTime.now(),
        lastSyncedAt: DateTime.now(),
      ).toJson();

      if (existingDevice.docs.isNotEmpty) {
        // Update existing device
        await existingDevice.docs.first.reference.update({
          ...deviceData,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new device
        await _firestore
            .collection(_devicesCollection)
            .add(deviceData);
      }

      // Save locally
      await prefs.setBool('device_sync_enabled', true);
      await prefs.setBool('is_main_device', true);
      await prefs.setString('device_name', deviceName);

      // 🆕 INITIALIZE MENU SYNC - sync all menu items to Firestore
      debugPrint('🔄 Initializing menu sync for main device...');
      await MenuSyncService.initializeMenuSync(companyId);

      debugPrint('✅ Main device registered');

      return {
        'success': true,
        'message': 'Main device registered successfully',
      };
    } catch (e) {
      debugPrint('❌ Error registering main device: $e');
      return {
        'success': false,
        'message': 'Failed to register main device: ${e.toString()}',
      };
    }
  }
    /// Start automatic background sync (UPDATED WITH MENU SYNC)
  static void startAutoSync(String companyId) {
    debugPrint('🔄 Starting auto-sync for company: $companyId');
    
    // Cancel any existing timers
    _syncTimer?.cancel();
    
    // Sync pending orders every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      debugPrint('⏰ Running scheduled sync...');
      await syncPendingOrders();
    });

    // Start listening to orders from other devices
    startListeningToOrders(companyId, (sync_models.SyncOrderModel syncOrder) async {
      debugPrint('📦 Processing incoming order: ${syncOrder.id}');
      await saveSyncedOrderLocally(syncOrder);
    });

    // 🆕 START MENU SYNC LISTENERS
    MenuSyncService.startListeningToMenuItems(
      companyId,
      (syncItem) async {
        debugPrint('📥 Received menu item: ${syncItem.name}');
        await MenuSyncService.saveSyncedMenuItemLocally(syncItem);
      },
      (itemId) async {
        debugPrint('🗑️ Received menu item deletion: $itemId');
        await MenuSyncService.deleteSyncedMenuItemLocally(itemId);
      },
    );

    MenuSyncService.startListeningToBusinessInfo(
      companyId,
      (businessInfo) async {
        debugPrint('📥 Received business info update');
        await MenuSyncService.saveSyncedBusinessInfoLocally(businessInfo);
      },
    );

    MenuSyncService.startListeningToCategories(
      companyId,
      (categories) async {
        debugPrint('📥 Received ${categories.length} categories');
        await MenuSyncService.saveSyncedCategoriesLocally(categories);
      },
    );

    debugPrint('✅ Auto-sync started successfully');
  }

  /// Get all devices for a company
  static Future<List<DeviceModel>> getCompanyDevices(String companyId) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        return [];
      }

      final snapshot = await _firestore
          .collection(_devicesCollection)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => DeviceModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting company devices: $e');
      return [];
    }
  }

  /// Set a device as the main device for order management
  static Future<Map<String, dynamic>> setMainDevice({
    required String deviceId,
    required String companyId,
  }) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        return {
          'success': false,
          'message': 'No internet connection',
        };
      }

      // First, unset all main devices for this company
      final allDevices = await _firestore
          .collection(_devicesCollection)
          .where('companyId', isEqualTo: companyId)
          .get();

      final batch = _firestore.batch();

      for (var doc in allDevices.docs) {
        batch.update(doc.reference, {'isMainDevice': false});
      }

      // Set the new main device
      final targetDevice = allDevices.docs.firstWhere(
        (doc) => doc.data()['id'] == deviceId,
      );

      batch.update(targetDevice.reference, {
        'isMainDevice': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Save main device status locally
      final prefs = await SharedPreferences.getInstance();
      final currentDeviceId = prefs.getString('device_id') ?? '';
      
      if (currentDeviceId == deviceId) {
        await prefs.setBool('is_main_device', true);
      } else {
        await prefs.setBool('is_main_device', false);
      }

      debugPrint('✅ Main device set successfully');

      return {
        'success': true,
        'message': 'Main device set successfully',
      };
    } catch (e) {
      debugPrint('❌ Error setting main device: $e');
      return {
        'success': false,
        'message': 'Failed to set main device: ${e.toString()}',
      };
    }
  }

  /// Sync a single order to Firestore
  static Future<Map<String, dynamic>> syncOrderToFirestore(local_models.Order order) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        debugPrint('⚠️ No internet connection, order will sync later');
        return {
          'success': false,
          'message': 'No internet connection',
          'willRetry': true,
        };
      }

      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? '';
      final companyId = prefs.getString('company_id') ?? '';
      final syncEnabled = prefs.getBool('device_sync_enabled') ?? false;
      
      if (!syncEnabled) {
        debugPrint('ℹ️ Device sync is disabled');
        return {
          'success': false,
          'message': 'Device sync is disabled',
        };
      }
      
      if (deviceId.isEmpty || companyId.isEmpty) {
        return {
          'success': false,
          'message': 'Device or company not configured',
        };
      }

      final syncOrder = sync_models.SyncOrderModel.fromOrder(order, deviceId, companyId);
      
      // Use order ID as document ID to avoid duplicates
      final docId = '${companyId}_${deviceId}_${order.id}';
      
      await _firestore
          .collection(_ordersCollection)
          .doc(docId)
          .set({
        ...syncOrder.toJson(),
        'syncedAt': FieldValue.serverTimestamp(),
        'isSynced': true,
      }, SetOptions(merge: true));

      debugPrint('✅ Order synced to Firestore: $docId');

      return {
        'success': true,
        'message': 'Order synced successfully',
        'orderId': docId,
      };
    } catch (e) {
      debugPrint('❌ Error syncing order: $e');
      return {
        'success': false,
        'message': 'Failed to sync order: ${e.toString()}',
        'willRetry': true,
      };
    }
  }

  /// Listen to orders from other devices in real-time
  static void startListeningToOrders(String companyId, Function(sync_models.SyncOrderModel) onOrderReceived) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        debugPrint('⚠️ Firebase not available, cannot listen to orders');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final currentDeviceId = prefs.getString('device_id') ?? '';

      _orderSubscription?.cancel();

      debugPrint('🔔 Starting to listen for orders from company: $companyId');

      _orderSubscription = _firestore
          .collection(_ordersCollection)
          .where('companyId', isEqualTo: companyId)
          .snapshots()
          .listen(
        (snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added || 
                change.type == DocumentChangeType.modified) {
              final data = change.doc.data();
              if (data != null && data['deviceId'] != currentDeviceId) {
                // This is an order from another device
                try {
                  final syncOrder = sync_models.SyncOrderModel.fromJson(data);
                  debugPrint('📥 Received order from device: ${data['deviceId']}');
                  onOrderReceived(syncOrder);
                } catch (e) {
                  debugPrint('❌ Error parsing synced order: $e');
                }
              }
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Error in order listener: $error');
        },
      );

      debugPrint('✅ Started listening to orders for company: $companyId');
    } catch (e) {
      debugPrint('❌ Error starting order listener: $e');
    }
  }

  /// Save a synced order from another device to local database
  static Future<void> saveSyncedOrderLocally(sync_models.SyncOrderModel syncOrder) async {
    try {
      final localRepo = LocalOrderRepository();
      
      // Check if order already exists locally
      final existingOrder = await localRepo.getOrderById(syncOrder.id ?? 0);
      
      if (existingOrder != null) {
        debugPrint('ℹ️ Order already exists locally, skipping: ${syncOrder.id}');
        return;
      }
      
      final order = syncOrder.toOrder();
      await localRepo.saveOrder(order);
      
      debugPrint('✅ Synced order saved locally: ${order.id}');
    } catch (e) {
      debugPrint('❌ Error saving synced order locally: $e');
    }
  }


  /// Sync all pending orders that haven't been synced yet
  static Future<void> syncPendingOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceSyncEnabled = prefs.getBool('device_sync_enabled') ?? false;
      
      if (!deviceSyncEnabled) {
        debugPrint('ℹ️ Sync disabled, skipping pending orders sync');
        return;
      }

      final localRepo = LocalOrderRepository();
      final orders = await localRepo.getAllOrders();

      int syncedCount = 0;
      int failedCount = 0;

      for (var order in orders) {
        final result = await syncOrderToFirestore(order);
        if (result['success']) {
          syncedCount++;
        } else {
          failedCount++;
        }
      }

      debugPrint('✅ Sync completed: $syncedCount synced, $failedCount failed');
    } catch (e) {
      debugPrint('❌ Error syncing pending orders: $e');
    }
  }

  /// Stop automatic sync and cleanup listeners
  static void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    
    _orderSubscription?.cancel();
    _orderSubscription = null;
    // 🆕 STOP MENU SYNC LISTENERS
    MenuSyncService.stopAllListeners();
    
    debugPrint('🛑 Auto-sync stopped');
  }

  /// Remove a device from the company
  static Future<Map<String, dynamic>> removeDevice(String deviceId, String companyId) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        return {
          'success': false,
          'message': 'No internet connection',
        };
      }

      final deviceDocs = await _firestore
          .collection(_devicesCollection)
          .where('id', isEqualTo: deviceId)
          .where('companyId', isEqualTo: companyId)
          .get();

      for (var doc in deviceDocs.docs) {
        await doc.reference.update({
          'isActive': false,
          'deactivatedAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('✅ Device removed successfully');

      return {
        'success': true,
        'message': 'Device removed successfully',
      };
    } catch (e) {
      debugPrint('❌ Error removing device: $e');
      return {
        'success': false,
        'message': 'Failed to remove device: ${e.toString()}',
      };
    }
  }

  /// Check if current device is set as main device
  static Future<bool> isMainDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_main_device') ?? false;
  }

  /// Update the last sync timestamp for a device
  static Future<void> updateLastSyncTime() async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? '';
      final companyId = prefs.getString('company_id') ?? '';
      
      if (deviceId.isEmpty || companyId.isEmpty) {
        return;
      }

      final deviceDocs = await _firestore
          .collection(_devicesCollection)
          .where('id', isEqualTo: deviceId)
          .where('companyId', isEqualTo: companyId)
          .limit(1)
          .get();

      if (deviceDocs.docs.isNotEmpty) {
        await deviceDocs.docs.first.reference.update({
          'lastSyncedAt': DateTime.now().toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        debugPrint('✅ Updated last sync time');
      }
    } catch (e) {
      debugPrint('⚠️ Error updating sync time: $e');
    }
  }

  /// Get sync statistics
  static Future<Map<String, dynamic>> getSyncStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncEnabled = prefs.getBool('device_sync_enabled') ?? false;
      final isMain = prefs.getBool('is_main_device') ?? false;
      final companyId = prefs.getString('company_id') ?? '';
      
      int totalDevices = 0;
      int syncedOrders = 0;
      
      if (companyId.isNotEmpty) {
        final devices = await getCompanyDevices(companyId);
        totalDevices = devices.length;
        
        if (FirebaseService.isFirebaseAvailable) {
          final orders = await _firestore
              .collection(_ordersCollection)
              .where('companyId', isEqualTo: companyId)
              .get();
          syncedOrders = orders.docs.length;
        }
      }
      // 🆕 GET MENU SYNC STATS
      final menuStats = await MenuSyncService.getSyncStats();
      
      return {
        'syncEnabled': syncEnabled,
        'isMainDevice': isMain,
        'totalDevices': totalDevices,
        'syncedOrders': syncedOrders,
        'syncedMenuItems': menuStats['totalSyncedItems'] ?? 0, 
        'firebaseAvailable': FirebaseService.isFirebaseAvailable,
      };
    } catch (e) {
      debugPrint('❌ Error getting sync stats: $e');
      return {
        'syncEnabled': false,
        'isMainDevice': false,
        'totalDevices': 0,
        'syncedOrders': 0,
        'syncedMenuItems': 0,
        'firebaseAvailable': false,
      };
    }
  }

  /// Force sync all local orders immediately
  static Future<Map<String, dynamic>> forceSyncAll() async {
    debugPrint('🔄 Starting force sync of all orders...');
    
    await syncPendingOrders();
    await updateLastSyncTime();
    
    return {
      'success': true,
      'message': 'Force sync completed',
    };
  }
}