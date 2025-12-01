// lib/services/menu_sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';
import '../models/sync_menu_item_model.dart';
import '../repositories/local_menu_repository.dart';
import 'firebase_service.dart';
import 'dart:async';

class MenuSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _menuItemsCollection = 'synced_menu_items';
  static const String _businessInfoCollection = 'synced_business_info';
  static const String _categoriesCollection = 'synced_categories';
  
  static StreamSubscription? _menuSubscription;
  static StreamSubscription? _businessInfoSubscription;
  static StreamSubscription? _categoriesSubscription;

  /// Sync a single menu item to Firestore
  static Future<Map<String, dynamic>> syncMenuItemToFirestore(MenuItem item) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        debugPrint('⚠️ No internet connection, menu item will sync later');
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

      final syncItem = SyncMenuItemModel.fromMenuItem(item, deviceId, companyId);
      
      // Use item ID as document ID to avoid duplicates
      final docId = '${companyId}_${item.id}';
      
      await _firestore
          .collection(_menuItemsCollection)
          .doc(docId)
          .set({
        ...syncItem.toJson(),
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Menu item synced to Firestore: $docId');

      return {
        'success': true,
        'message': 'Menu item synced successfully',
        'itemId': docId,
      };
    } catch (e) {
      debugPrint('❌ Error syncing menu item: $e');
      return {
        'success': false,
        'message': 'Failed to sync menu item: ${e.toString()}',
        'willRetry': true,
      };
    }
  }

  /// Sync menu item deletion to Firestore
  static Future<Map<String, dynamic>> syncMenuItemDeletionToFirestore(String itemId) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        debugPrint('⚠️ No internet connection, deletion will sync later');
        return {
          'success': false,
          'message': 'No internet connection',
          'willRetry': true,
        };
      }

      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id') ?? '';
      final syncEnabled = prefs.getBool('device_sync_enabled') ?? false;
      
      if (!syncEnabled || companyId.isEmpty) {
        return {
          'success': false,
          'message': 'Sync not enabled or not configured',
        };
      }

      final docId = '${companyId}_$itemId';
      
      await _firestore
          .collection(_menuItemsCollection)
          .doc(docId)
          .delete();

      debugPrint('✅ Menu item deletion synced: $docId');

      return {
        'success': true,
        'message': 'Deletion synced successfully',
      };
    } catch (e) {
      debugPrint('❌ Error syncing deletion: $e');
      return {
        'success': false,
        'message': 'Failed to sync deletion: ${e.toString()}',
        'willRetry': true,
      };
    }
  }

  /// Sync business information to Firestore
  static Future<Map<String, dynamic>> syncBusinessInfoToFirestore({
    required String businessName,
    String? secondBusinessName,
    required String businessAddress,
    required String businessPhone,
    required String businessEmail,
  }) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        return {
          'success': false,
          'message': 'No internet connection',
          'willRetry': true,
        };
      }

      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id') ?? '';
      final syncEnabled = prefs.getBool('device_sync_enabled') ?? false;
      
      if (!syncEnabled || companyId.isEmpty) {
        return {
          'success': false,
          'message': 'Sync not enabled or not configured',
        };
      }

      final businessInfo = SyncBusinessInfoModel(
        companyId: companyId,
        businessName: businessName,
        secondBusinessName: secondBusinessName ?? '',
        businessAddress: businessAddress,
        businessPhone: businessPhone,
        businessEmail: businessEmail,
        lastUpdated: DateTime.now(),
      );

      await _firestore
          .collection(_businessInfoCollection)
          .doc(companyId)
          .set({
        ...businessInfo.toJson(),
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Business info synced to Firestore');

      return {
        'success': true,
        'message': 'Business info synced successfully',
      };
    } catch (e) {
      debugPrint('❌ Error syncing business info: $e');
      return {
        'success': false,
        'message': 'Failed to sync business info: ${e.toString()}',
        'willRetry': true,
      };
    }
  }

  /// Sync categories to Firestore
  static Future<Map<String, dynamic>> syncCategoriesToFirestore(List<String> categories) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        return {
          'success': false,
          'message': 'No internet connection',
          'willRetry': true,
        };
      }

      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id') ?? '';
      final syncEnabled = prefs.getBool('device_sync_enabled') ?? false;
      
      if (!syncEnabled || companyId.isEmpty) {
        return {
          'success': false,
          'message': 'Sync not enabled or not configured',
        };
      }

      await _firestore
          .collection(_categoriesCollection)
          .doc(companyId)
          .set({
        'categories': categories,
        'companyId': companyId,
        'lastUpdated': DateTime.now().toIso8601String(),
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Categories synced to Firestore');

      return {
        'success': true,
        'message': 'Categories synced successfully',
      };
    } catch (e) {
      debugPrint('❌ Error syncing categories: $e');
      return {
        'success': false,
        'message': 'Failed to sync categories: ${e.toString()}',
        'willRetry': true,
      };
    }
  }

  /// Start listening to menu items from main device
  static void startListeningToMenuItems(
    String companyId,
    Function(SyncMenuItemModel) onItemReceived,
    Function(String) onItemDeleted,
  ) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        debugPrint('⚠️ Firebase not available, cannot listen to menu items');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final currentDeviceId = prefs.getString('device_id') ?? '';

      _menuSubscription?.cancel();

      debugPrint('🔔 Starting to listen for menu items from company: $companyId');

      _menuSubscription = _firestore
          .collection(_menuItemsCollection)
          .where('companyId', isEqualTo: companyId)
          .snapshots()
          .listen(
        (snapshot) {
          for (var change in snapshot.docChanges) {
            // Handle removed items separately because removed changes often
            // do not include the document data payload. We want deletions
            // to be applied on staff devices regardless of the originating
            // device id, so call onItemDeleted directly for removed events.
            if (change.type == DocumentChangeType.removed) {
              try {
                final docId = change.doc.id; // format: <companyId>_<itemId>
                final itemId = docId.split('_').last;
                debugPrint('🗑️ Received deletion for item doc: $docId -> local id: $itemId');
                onItemDeleted(itemId);
              } catch (e) {
                debugPrint('❌ Error handling removed menu item change: $e');
              }
              continue;
            }

            // For added/modified events we expect data to be present.
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              final data = change.doc.data();
              // Only process items coming from other devices (avoid re-applying
              // changes emitted by this same device).
              if (data != null && data['deviceId'] != currentDeviceId) {
                try {
                  final syncItem = SyncMenuItemModel.fromJson(data);
                  debugPrint('📥 Received menu item from device: ${data['deviceId']}');
                  onItemReceived(syncItem);
                } catch (e) {
                  debugPrint('❌ Error parsing synced menu item: $e');
                }
              }
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Error in menu item listener: $error');
        },
      );

      debugPrint('✅ Started listening to menu items');
    } catch (e) {
      debugPrint('❌ Error starting menu item listener: $e');
    }
  }

  /// Start listening to business info changes
  static void startListeningToBusinessInfo(
    String companyId,
    Function(SyncBusinessInfoModel) onBusinessInfoReceived,
  ) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        debugPrint('⚠️ Firebase not available, cannot listen to business info');
        return;
      }

      _businessInfoSubscription?.cancel();

      debugPrint('🔔 Starting to listen for business info changes: $companyId');

      _businessInfoSubscription = _firestore
          .collection(_businessInfoCollection)
          .doc(companyId)
          .snapshots()
          .listen(
        (snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data();
            if (data != null) {
              try {
                final businessInfo = SyncBusinessInfoModel.fromJson(data);
                debugPrint('📥 Received business info update');
                onBusinessInfoReceived(businessInfo);
              } catch (e) {
                debugPrint('❌ Error parsing business info: $e');
              }
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Error in business info listener: $error');
        },
      );

      debugPrint('✅ Started listening to business info');
    } catch (e) {
      debugPrint('❌ Error starting business info listener: $e');
    }
  }

  /// Start listening to category changes
  static void startListeningToCategories(
    String companyId,
    Function(List<String>) onCategoriesReceived,
  ) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        debugPrint('⚠️ Firebase not available, cannot listen to categories');
        return;
      }

      _categoriesSubscription?.cancel();

      debugPrint('🔔 Starting to listen for category changes: $companyId');

      _categoriesSubscription = _firestore
          .collection(_categoriesCollection)
          .doc(companyId)
          .snapshots()
          .listen(
        (snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data();
            if (data != null && data['categories'] is List) {
              final categories = List<String>.from(data['categories']);
              debugPrint('📥 Received ${categories.length} categories');
              onCategoriesReceived(categories);
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Error in categories listener: $error');
        },
      );

      debugPrint('✅ Started listening to categories');
    } catch (e) {
      debugPrint('❌ Error starting categories listener: $e');
    }
  }

  /// Save synced menu item to local database
  static Future<void> saveSyncedMenuItemLocally(SyncMenuItemModel syncItem) async {
    try {
      final localRepo = LocalMenuRepository();
      final menuItem = syncItem.toMenuItem();
      
      // Check if item exists
      final existingItems = await localRepo.getMenuItems();
      final exists = existingItems.any((item) => item.id == menuItem.id);
      
      if (exists) {
        await localRepo.updateMenuItem(menuItem);
        debugPrint('✅ Updated synced menu item locally: ${menuItem.id}');
      } else {
        await localRepo.addMenuItem(menuItem);
        debugPrint('✅ Added synced menu item locally: ${menuItem.id}');
      }
    } catch (e) {
      debugPrint('❌ Error saving synced menu item locally: $e');
    }
  }

  /// Delete synced menu item from local database
  static Future<void> deleteSyncedMenuItemLocally(String itemId) async {
    try {
      final localRepo = LocalMenuRepository();
      await localRepo.deleteMenuItem(itemId);
      debugPrint('✅ Deleted synced menu item locally: $itemId');
    } catch (e) {
      debugPrint('❌ Error deleting synced menu item locally: $e');
    }
  }

  /// Save synced business info locally
  static Future<void> saveSyncedBusinessInfoLocally(SyncBusinessInfoModel businessInfo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('business_name', businessInfo.businessName);
      await prefs.setString('second_business_name', businessInfo.secondBusinessName);
      await prefs.setString('business_address', businessInfo.businessAddress);
      await prefs.setString('business_phone', businessInfo.businessPhone);
      await prefs.setString('business_email', businessInfo.businessEmail);
      
      debugPrint('✅ Business info updated locally');
    } catch (e) {
      debugPrint('❌ Error saving business info locally: $e');
    }
  }

  /// Save synced categories locally
  static Future<void> saveSyncedCategoriesLocally(List<String> categories) async {
    try {
      final localRepo = LocalMenuRepository();
      
      // Get existing categories
      final existingCategories = await localRepo.getCategories();
      
      // Add new categories that don't exist
      for (final category in categories) {
        if (!existingCategories.contains(category)) {
          await localRepo.addCategory(category);
        }
      }
      
      debugPrint('✅ Categories synced locally: ${categories.length}');
    } catch (e) {
      debugPrint('❌ Error saving categories locally: $e');
    }
  }

  /// Sync all menu items from local database to Firestore
  static Future<void> syncAllMenuItemsToFirestore() async {
    try {
      final localRepo = LocalMenuRepository();
      final items = await localRepo.getMenuItems();
      final categories = await localRepo.getCategories();

      int syncedCount = 0;
      int failedCount = 0;

      // Sync categories first
      await syncCategoriesToFirestore(categories);

      // Sync all items
      for (var item in items) {
        final result = await syncMenuItemToFirestore(item);
        if (result['success']) {
          syncedCount++;
        } else {
          failedCount++;
        }
      }

      debugPrint('✅ Menu sync completed: $syncedCount synced, $failedCount failed');
    } catch (e) {
      debugPrint('❌ Error syncing all menu items: $e');
    }
  }

  /// Initialize menu sync (call when main device is set up or staff device links)
  static Future<void> initializeMenuSync(String companyId) async {
    debugPrint('🔄 Initializing menu sync for company: $companyId');
    
    final prefs = await SharedPreferences.getInstance();
    final isMainDevice = prefs.getBool('is_main_device') ?? false;
    
    if (isMainDevice) {
      // Main device: sync all menu items to Firestore
      await syncAllMenuItemsToFirestore();
      
      // Also sync business info
      final businessName = prefs.getString('business_name') ?? '';
      final secondBusinessName = prefs.getString('second_business_name') ?? '';
      final businessAddress = prefs.getString('business_address') ?? '';
      final businessPhone = prefs.getString('business_phone') ?? '';
      final businessEmail = prefs.getString('business_email') ?? '';
      
      await syncBusinessInfoToFirestore(
        businessName: businessName,
        secondBusinessName: secondBusinessName,
        businessAddress: businessAddress,
        businessPhone: businessPhone,
        businessEmail: businessEmail,
      );
    } else {
      // Staff device: fetch all menu items from Firestore
      await fetchAllMenuItemsFromFirestore(companyId);
      await fetchBusinessInfoFromFirestore(companyId);
      await fetchCategoriesFromFirestore(companyId);
    }
    
    debugPrint('✅ Menu sync initialized');
  }

  /// Fetch all menu items from Firestore (for staff devices)
  static Future<void> fetchAllMenuItemsFromFirestore(String companyId) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        debugPrint('⚠️ Firebase not available');
        return;
      }

      final snapshot = await _firestore
          .collection(_menuItemsCollection)
          .where('companyId', isEqualTo: companyId)
          .get();

      // final localRepo = LocalMenuRepository();
      final localRepo = LocalMenuRepository();

      // Collect fetched item IDs so we can remove any stale local items
      final fetchedIds = <String>{};

      for (var doc in snapshot.docs) {
        try {
          final syncItem = SyncMenuItemModel.fromJson(doc.data());
          fetchedIds.add(syncItem.id);
          await saveSyncedMenuItemLocally(syncItem);
        } catch (e) {
          debugPrint('⚠️ Error saving item: $e');
        }
      }

      // Reconcile: delete local items that are not present in Firestore
      try {
        final localItems = await localRepo.getMenuItems();
        for (var local in localItems) {
          if (!fetchedIds.contains(local.id)) {
            await localRepo.deleteMenuItem(local.id);
            debugPrint('🗑️ Reconciled and deleted local stale item: ${local.id}');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error during reconciliation of local menu items: $e');
      }

      debugPrint('✅ Fetched ${snapshot.docs.length} menu items from Firestore');
    } catch (e) {
      debugPrint('❌ Error fetching menu items: $e');
    }
  }

  /// Fetch business info from Firestore
  static Future<void> fetchBusinessInfoFromFirestore(String companyId) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        return;
      }

      final doc = await _firestore
          .collection(_businessInfoCollection)
          .doc(companyId)
          .get();

      if (doc.exists) {
        final businessInfo = SyncBusinessInfoModel.fromJson(doc.data()!);
        await saveSyncedBusinessInfoLocally(businessInfo);
        debugPrint('✅ Fetched business info from Firestore');
      }
    } catch (e) {
      debugPrint('❌ Error fetching business info: $e');
    }
  }

  /// Fetch categories from Firestore
  static Future<void> fetchCategoriesFromFirestore(String companyId) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        return;
      }

      final doc = await _firestore
          .collection(_categoriesCollection)
          .doc(companyId)
          .get();

      if (doc.exists && doc.data()?['categories'] is List) {
        final categories = List<String>.from(doc.data()!['categories']);
        await saveSyncedCategoriesLocally(categories);
        debugPrint('✅ Fetched ${categories.length} categories from Firestore');
      }
    } catch (e) {
      debugPrint('❌ Error fetching categories: $e');
    }
  }

  /// Stop all listeners
  static void stopAllListeners() {
    _menuSubscription?.cancel();
    _menuSubscription = null;
    
    _businessInfoSubscription?.cancel();
    _businessInfoSubscription = null;
    
    _categoriesSubscription?.cancel();
    _categoriesSubscription = null;
    
    debugPrint('🛑 Menu sync listeners stopped');
  }

  /// Get sync statistics
  static Future<Map<String, dynamic>> getSyncStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id') ?? '';
      
      int totalItems = 0;
      
      if (companyId.isNotEmpty && FirebaseService.isFirebaseAvailable) {
        final items = await _firestore
            .collection(_menuItemsCollection)
            .where('companyId', isEqualTo: companyId)
            .get();
        totalItems = items.docs.length;
      }
      
      return {
        'totalSyncedItems': totalItems,
        'firebaseAvailable': FirebaseService.isFirebaseAvailable,
      };
    } catch (e) {
      debugPrint('❌ Error getting menu sync stats: $e');
      return {
        'totalSyncedItems': 0,
        'firebaseAvailable': false,
      };
    }
  }
}