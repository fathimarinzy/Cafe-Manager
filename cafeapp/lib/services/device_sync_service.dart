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
import 'dart:convert';
import '../models/table_model.dart';
import '../models/person.dart';
import '../models/credit_transaction.dart';
import '../repositories/local_person_repository.dart';
import '../repositories/credit_transaction_repository.dart';
import '../services/menu_sync_service.dart';
import '../models/order_item.dart' as local_order_item;

// Helper extension for firstWhereOrNull
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class DeviceSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _devicesCollection = 'devices';
  static const String _ordersCollection = 'synced_orders';
  static const String _linkCodesCollection = 'device_link_codes';
  static const String _configCollection = 'config';
  // Use same key as TableProvider
  static const String _tableStorageKey = 'dining_tables'; 

  /// Helper to get current device ID
  static Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_id') ?? '';
  }

  /// Update table status locally in SharedPreferences
  static Future<void> _updateTableStatusLocally(int tableNumber, bool isOccupied) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? tablesJson = prefs.getString(_tableStorageKey);
      
      if (tablesJson != null) {
        final List<dynamic> decodedData = jsonDecode(tablesJson);
        final List<TableModel> tables = decodedData.map((item) => TableModel.fromJson(item)).toList();
        
        final index = tables.indexWhere((t) => t.number == tableNumber);
        
        if (index >= 0) {
          // Check if status actually needs changing to avoid unnecessary writes
          if (tables[index].isOccupied != isOccupied) {
            tables[index].isOccupied = isOccupied;
            
            final String updatedJson = jsonEncode(tables.map((table) => table.toJson()).toList());
            await prefs.setString(_tableStorageKey, updatedJson);
            // Force reload to ensure persistence
            await prefs.reload();
            
            debugPrint('✅ Updated table $tableNumber status to ${isOccupied ? 'occupied' : 'available'} (Sync)');
            _notifyTablesChanged();
          } else {
             debugPrint('ℹ️ Table $tableNumber status already ${isOccupied ? 'occupied' : 'available'}');
          }
        } else {
          debugPrint('⚠️ Table $tableNumber not found for sync update');
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating local table status: $e');
    }
  }

  /// Helper to check if order is for a table and update status
  static Future<void> _checkAndUpdateTableStatus(String serviceType, String status) async {
    if (serviceType.startsWith('Dining - Table')) {
      final match = RegExp(r'Table (\d+)').firstMatch(serviceType);
      if (match != null && match.groupCount >= 1) {
        final tableNum = int.tryParse(match.group(1)!);
        if (tableNum != null) {
          // If status is 'completed' or 'paid', free the table
          // Otherwise mark as occupied
          final bool isOccupied = !(status.toLowerCase() == 'completed' || status.toLowerCase() == 'paid');
          await _updateTableStatusLocally(tableNum, isOccupied);
        }
      }
    }
  }
  
  static Timer? _syncTimer;
  static StreamSubscription? _orderSubscription;
  static Timer? _mainOrderProcessingTimer;

  // 🆕 Callback for UI refresh
  static Function()? _onOrdersChangedCallback;

  static void setOnOrdersChangedCallback(Function() callback) {
    _onOrdersChangedCallback = callback;
    debugPrint('✅ Order change callback registered');
  }

  static void _notifyOrdersChanged() {
    if (_onOrdersChangedCallback != null) {
      debugPrint('📢 Notifying UI of order changes');
      _onOrdersChangedCallback!();
    }
  }

  // 🆕 Callback for Table UI refresh
  static Function()? _onTablesChangedCallback;

  static void setOnTablesChangedCallback(Function() callback) {
    _onTablesChangedCallback = callback;
    debugPrint('✅ Table change callback registered');
  }

  static void _notifyTablesChanged() {
    if (_onTablesChangedCallback != null) {
      debugPrint('📢 Notifying UI of table changes');
      _onTablesChangedCallback!();
    }
  }

  /// Sync a single order to Firestore (from staff device)
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
      
      // Use composite document ID: company_staffDevice_staffOrderNum
      final docId = '${companyId}_${deviceId}_${order.staffOrderNumber}';
      
      // Store order
      await _firestore
          .collection(_ordersCollection)
          .doc(docId)
          .set({
        ...syncOrder.toJson(),
        'syncedAt': FieldValue.serverTimestamp(),
        'isSynced': true,
        // Only set to null if not already assigned. If assigned, preserve it.
        'mainOrderNumber': order.mainNumberAssigned ? order.mainOrderNumber : null,
        'mainNumberAssigned': order.mainNumberAssigned,
        'lastUpdatedBy': deviceId,
      }, SetOptions(merge: true));

      // Update local order sync status
      final localRepo = LocalOrderRepository();
      final updatedOrder = order.copyWith(
        isSynced: true,
        syncedAt: DateTime.now().toIso8601String(),
      );
      await localRepo.saveOrder(updatedOrder);

      debugPrint('✅ Order synced to Firestore: $docId (Staff #${order.staffOrderNumber})');

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

  /// Fetch orders without main number and assign them (MAIN DEVICE ONLY)
  static Future<Map<String, dynamic>> processUnassignedOrders() async {
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
      final isMainDevice = prefs.getBool('is_main_device') ?? false;
      final companyId = prefs.getString('company_id') ?? '';
      
      if (!isMainDevice) {
        debugPrint('⚠️ Only main device can assign main order numbers');
        return {
          'success': false,
          'message': 'Only main device can assign order numbers',
        };
      }

      if (companyId.isEmpty) {
        return {
          'success': false,
          'message': 'Company ID not configured',
        };
      }

      debugPrint('🔍 Fetching orders without main order numbers...');

      // Query orders where mainNumberAssigned is false
      final unassignedOrders = await _firestore
          .collection(_ordersCollection)
          .where('companyId', isEqualTo: companyId)
          .where('mainNumberAssigned', isEqualTo: false)
          .orderBy('createdAt', descending: false) // Process oldest first
          .limit(50) // Process in batches
          .get();

      if (unassignedOrders.docs.isEmpty) {
        debugPrint('ℹ️ No unassigned orders found');
        return {
          'success': true,
          'message': 'No orders to process',
          'processedCount': 0,
        };
      }

      debugPrint('📦 Found ${unassignedOrders.docs.length} unassigned orders');

      int processedCount = 0;
      int failedCount = 0;
      final localRepo = LocalOrderRepository();

      for (var doc in unassignedOrders.docs) {
        try {
          final data = doc.data();
          debugPrint('🔍 Processing order document: ${doc.id}');
          
          final syncOrder = sync_models.SyncOrderModel.fromJson(data);
          debugPrint('📋 Parsed sync order: Staff#${syncOrder.staffOrderNumber}, ID=${syncOrder.id}');
          
          // Assign main order number using transaction
          final mainOrderNumber = await _getNextMainOrderNumber(companyId);
          
          if (mainOrderNumber == null) {
            debugPrint('❌ Failed to get next main order number');
            failedCount++;
            continue;
          }

          debugPrint('🔢 Assigned main order number: $mainOrderNumber');

          // Update order in Firestore first
          await doc.reference.update({
            'mainOrderNumber': mainOrderNumber,
            'mainNumberAssigned': true,
            'mainNumberAssignedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('✅ Firestore updated with main number');

          // Search for existing order by staff device ID and staff order number
          debugPrint('🔍 Searching for existing local order...');
          
          final allOrdersFuture = localRepo.getAllOrders();
          final allOrders = await allOrdersFuture.timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⏱️ Timeout getting all orders, returning empty list');
              return <local_models.Order>[];
            },
          );
          
          debugPrint('📊 Found ${allOrders.length} total local orders');
          
          final existingOrder = allOrders.firstWhereOrNull(
            (o) => o.staffDeviceId == syncOrder.staffDeviceId && 
                   o.staffOrderNumber == syncOrder.staffOrderNumber,
          );
          
          if (existingOrder != null) {
            debugPrint('✏️ Found existing local order #${existingOrder.id}, updating...');
            // Update the existing order with the main number
            final updatedOrder = existingOrder.copyWith(
              mainOrderNumber: mainOrderNumber,
              mainNumberAssigned: true,
            );
            
            await localRepo.saveOrder(updatedOrder).timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('⏱️ Timeout saving order update');
                return updatedOrder;
              },
            );
            
            debugPrint('✅ Updated existing local order #${existingOrder.id} with main number $mainOrderNumber');
            
            // 🆕 Notify UI to refresh
            _notifyOrdersChanged();
          } else {
            debugPrint('➕ No existing order found, creating new...');
            // This is a new order from another device - save it with the main number
            final localOrder = syncOrder.toOrder().copyWith(
              mainOrderNumber: mainOrderNumber,
              mainNumberAssigned: true,
            );
            
            await localRepo.saveOrder(localOrder).timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('⏱️ Timeout saving new order');
                return localOrder;
              },
            );
            
            debugPrint('✅ Saved new order from staff device with main number $mainOrderNumber');
            
            // 🆕 Notify UI to refresh
            _notifyOrdersChanged();
          }

          debugPrint('✅ Assigned main order #$mainOrderNumber to staff order #${syncOrder.staffOrderNumber} from device ${syncOrder.staffDeviceId}');
          processedCount++;

        } catch (e, stackTrace) {
          debugPrint('❌ Error processing order ${doc.id}: $e');
          debugPrint('Stack trace: $stackTrace');
          failedCount++;
        }
      }

      debugPrint('🎯 Processed $processedCount orders, $failedCount failed');

      return {
        'success': true,
        'message': 'Orders processed successfully',
        'processedCount': processedCount,
        'failedCount': failedCount,
      };
    } catch (e) {
      debugPrint('❌ Error processing unassigned orders: $e');
      return {
        'success': false,
        'message': 'Failed to process orders: ${e.toString()}',
      };
    }
  }
  
  // Add this method to sync order updates
  static Future<Map<String, dynamic>> syncOrderUpdate(local_models.Order order) async {
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        debugPrint('⚠️ No internet connection, order update will sync later');
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
      final isMainDevice = prefs.getBool('is_main_device') ?? false;

      
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
      
      // 🆕 Get the staff device ID from the order (it might be from another device)
      final orderStaffDeviceId = order.staffDeviceId.isNotEmpty 
          ? order.staffDeviceId 
          : deviceId;

      final syncOrder = sync_models.SyncOrderModel.fromOrder(order, orderStaffDeviceId, companyId);
      
      // Use composite document ID: company_staffDevice_staffOrderNum
      final docId = '${companyId}_${orderStaffDeviceId}_${order.staffOrderNumber}';
      
      debugPrint('🔄 Syncing order update from ${isMainDevice ? "MAIN" : "STAFF"} device');
      debugPrint('   Document ID: $docId');
      debugPrint('   Staff Device ID: $orderStaffDeviceId');
      debugPrint('   Current Device ID: $deviceId');

      // Update the existing document with the new order data
      await _firestore
          .collection(_ordersCollection)
          .doc(docId)
          .update({
        ...syncOrder.toJson(),
        'syncedAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(), // Track when it was last edited
        'lastUpdatedBy': deviceId, // 🆕 Track which device made the edit
        'lastUpdatedByMain': isMainDevice, // 🆕 Track if edit was by main device
        'isEdited': true,
      });

      // Update local order sync status
      final localRepo = LocalOrderRepository();
      final updatedOrder = order.copyWith(
        isSynced: true,
        syncedAt: DateTime.now().toIso8601String(),
      );
      await localRepo.saveOrder(updatedOrder);

      debugPrint('✅ Order update synced to Firestore: $docId (Staff #${order.staffOrderNumber})');
      debugPrint('   Edited by: ${isMainDevice ? "Main Device" : "Staff Device"}');

      return {
        'success': true,
        'message': 'Order update synced successfully',
        'orderId': docId,
        'editedByMain': isMainDevice,

      };
    } catch (e) {
      debugPrint('❌ Error syncing order update: $e');
      return {
        'success': false,
        'message': 'Failed to sync order update: ${e.toString()}',
        'willRetry': true,
      };
    }
  }

  /// Get next main order number using Firestore transaction
  static Future<int?> _getNextMainOrderNumber(String companyId) async {
    try {
      debugPrint('🔢 Getting next main order number for company: $companyId');
      
      final counterRef = _firestore
          .collection(_configCollection)
          .doc('${companyId}_main_order_counter');

      debugPrint('  → Reading counter document...');
      
      final snapshot = await counterRef.get().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('  ⏱️ Timeout reading counter document');
          throw TimeoutException('Counter read timeout');
        },
      );

      int currentCounter = 1;
      if (snapshot.exists) {
        currentCounter = (snapshot.data()?['counter'] as int?) ?? 1;
        debugPrint('  → Current counter: $currentCounter');
      } else {
        debugPrint('  → Counter document does not exist, will create with counter: 1');
      }

      final nextCounter = currentCounter + 1;
      debugPrint('  → Next counter will be: $nextCounter');

      // Update the counter
      await counterRef.set({
        'companyId': companyId,
        'counter': nextCounter,
        'lastUpdated': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('  ⏱️ Timeout updating counter document');
          throw TimeoutException('Counter update timeout');
        },
      );
      
      debugPrint('✅ Successfully assigned order number: $currentCounter');
      return currentCounter;
    } on TimeoutException catch (e) {
      debugPrint('⏱️ Timeout getting next main order number: $e');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting next main order number: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Start automatic sync and order processing
  static void startAutoSync(String companyId) async {
    debugPrint('🔄 Starting auto-sync for company: $companyId');
    
    _syncTimer?.cancel();
    _mainOrderProcessingTimer?.cancel();
    
    final prefs = await SharedPreferences.getInstance();
    final isMainDevice = prefs.getBool('is_main_device') ?? false;

    // Sync pending orders every 1 minutes (all devices)
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      debugPrint('⏰ Running scheduled sync...');
      await syncPendingOrders();
    });

    // Process unassigned orders every 30 seconds (main device only)
    if (isMainDevice) {
      _mainOrderProcessingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        debugPrint('⏰ Processing unassigned orders...');
        await processUnassignedOrders();
      });
      
      // Process immediately on startup
      Timer(const Duration(seconds: 5), () async {
        await processUnassignedOrders();
      });
    }

    // Listen to orders from other devices
    startListeningToOrders(companyId, (sync_models.SyncOrderModel syncOrder) async {
      debugPrint('📦 Processing incoming order: ${syncOrder.id}');
      await saveSyncedOrderLocally(syncOrder);
    });

    // Start menu sync listeners
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

    // 🆕 Start listening to Persons and Credit Transactions
    startListeningToPersons(companyId);
    startListeningToCreditTransactions(companyId);

    debugPrint('✅ Auto-sync started successfully');
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
      debugPrint('🔔 Current device ID: $currentDeviceId');

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
              if (data != null) {
                // ⭐ CRITICAL FIX: Check lastUpdatedBy instead of staffDeviceId
                // This allows devices to receive updates even on orders they created
                final lastUpdatedBy = data['lastUpdatedBy'] as String?;
                final staffDeviceId = data['staffDeviceId'] as String?;
                
                // Only skip if WE made the last update (prevents processing our own changes)
                if (lastUpdatedBy != null && lastUpdatedBy == currentDeviceId) {
                  debugPrint('⏭️ Skipping order update - we made this change (lastUpdatedBy: $lastUpdatedBy)');
                  continue;
                }
                
                try {
                  final syncOrder = sync_models.SyncOrderModel.fromJson(data);
                  final updateType = change.type == DocumentChangeType.modified ? "UPDATE" : "NEW";
                  debugPrint('📥 Received order $updateType from device: $staffDeviceId (lastUpdatedBy: $lastUpdatedBy)');
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

  /// Save a synced order from another device to local database - FIXED VERSION
  static Future<void> saveSyncedOrderLocally(sync_models.SyncOrderModel syncOrder) async {
    try {
      final localRepo = LocalOrderRepository();
      final prefs = await SharedPreferences.getInstance();
      final currentDeviceId = prefs.getString('device_id') ?? '';
      final isMainDevice = prefs.getBool('is_main_device') ?? false;

      // ⭐ CRITICAL FIX: Check who last updated the order
      final lastUpdatedBy = syncOrder.lastUpdatedBy ?? syncOrder.staffDeviceId;
      
      debugPrint('📥 Checking if we should process order update');
      debugPrint('   Current Device: $currentDeviceId (${isMainDevice ? "MAIN" : "STAFF"})');
      debugPrint('   Order Created By: ${syncOrder.staffDeviceId}');
      debugPrint('   Order Last Updated By: $lastUpdatedBy');
      
      // ⭐ FIXED: Skip only if WE are the one who made the last update
      // This prevents infinite loops while allowing cross-device updates
      if (lastUpdatedBy == currentDeviceId) {
        debugPrint('ℹ️ Skipping - we are the last updater for Staff#${syncOrder.staffOrderNumber}');
        return;
      }

      debugPrint('✅ Processing order update from remote device');
      
      // First try to find by local ID if it exists
      local_models.Order? existingOrder;
      if (syncOrder.id != null) {
        existingOrder = await localRepo.getOrderById(syncOrder.id!);
      }
      
      // If not found by ID, search by staff device ID and staff order number
      if (existingOrder == null) {
        final allOrders = await localRepo.getAllOrders();
        existingOrder = allOrders.firstWhereOrNull(
          (o) => o.staffDeviceId == syncOrder.staffDeviceId && 
                 o.staffOrderNumber == syncOrder.staffOrderNumber,
        );
      }
      
      if (existingOrder != null) {
        debugPrint('ℹ️ Order already exists locally (ID=${existingOrder.id}), checking for updates...');
        
        // Check what needs to be updated
        bool needsUpdate = false;
        List<String> changes = [];
        
        // Check all fields for changes
        if (existingOrder.mainOrderNumber != syncOrder.mainOrderNumber && 
            syncOrder.mainNumberAssigned) {
          needsUpdate = true;
          changes.add('Main number: ${existingOrder.mainOrderNumber} → ${syncOrder.mainOrderNumber}');
        }
        
        // Update status if different
        if (existingOrder.status != syncOrder.status) {
          needsUpdate = true;
          changes.add('Status: ${existingOrder.status} → ${syncOrder.status}');
        }
        
        // Update payment method if different
        if (existingOrder.paymentMethod != syncOrder.paymentMethod) {
          needsUpdate = true;
          changes.add('Payment: ${existingOrder.paymentMethod} → ${syncOrder.paymentMethod}');
        }
        
        // Check if items changed (for edits)
        if (!_areItemsEqual(existingOrder.items, syncOrder.items)) {
          needsUpdate = true;
          changes.add('Items changed (${existingOrder.items.length} → ${syncOrder.items.length} items)');
        }
        
        // Check if amounts changed (subtotal, tax, discount, total)
        if (existingOrder.subtotal != syncOrder.subtotal ||
            existingOrder.tax != syncOrder.tax ||
            existingOrder.discount != syncOrder.discount ||
            existingOrder.total != syncOrder.total) {
          needsUpdate = true;
          changes.add('Amounts changed (Total: ${existingOrder.total} → ${syncOrder.total})');
        }
        
        // 🆕 Check payment amounts (for split payments)
        if (existingOrder.cashAmount != syncOrder.cashAmount ||
            existingOrder.bankAmount != syncOrder.bankAmount) {
          needsUpdate = true;
          changes.add('Payment amounts updated');
        }
        
        if (needsUpdate) {
          debugPrint('📝 Updating order with changes:');
          for (var change in changes) {
            debugPrint('   - $change');
          }
          
          final updatedOrder = existingOrder.copyWith(
            items: syncOrder.items,
            subtotal: syncOrder.subtotal,
            tax: syncOrder.tax,
            discount: syncOrder.discount,
            total: syncOrder.total,
            mainOrderNumber: syncOrder.mainNumberAssigned ? syncOrder.mainOrderNumber : existingOrder.mainOrderNumber,
            mainNumberAssigned: syncOrder.mainNumberAssigned || existingOrder.mainNumberAssigned,
            status: syncOrder.status,
            paymentMethod: syncOrder.paymentMethod,
            cashAmount: syncOrder.cashAmount,
            bankAmount: syncOrder.bankAmount,
            isSynced: true,
          );
          await localRepo.saveOrder(updatedOrder);
          debugPrint('✅ Updated order: Staff#${syncOrder.staffOrderNumber}, Main#${updatedOrder.mainOrderNumber ?? "pending"}');
          
          // 🆕 Update table status if needed
          await _checkAndUpdateTableStatus(updatedOrder.serviceType, updatedOrder.status);

          // Notify UI to refresh
          _notifyOrdersChanged();
        } else {
          debugPrint('ℹ️ No updates needed for order Staff#${syncOrder.staffOrderNumber}');
        }
        return;
      }
      
      // Order doesn't exist locally - create new
      debugPrint('➕ Creating new order from remote device');
      final order = syncOrder.toOrder();
      await localRepo.saveOrder(order);
      
      debugPrint('✅ Synced NEW order saved locally: Staff#${order.staffOrderNumber}, Main#${order.mainOrderNumber ?? "pending"}');
      
      // 🆕 Update table status if needed
      await _checkAndUpdateTableStatus(order.serviceType, order.status);
      
      // Notify UI to refresh
      _notifyOrdersChanged();
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving synced order locally: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // 🆕 Helper method to compare order items
  static bool _areItemsEqual(List<local_order_item.OrderItem> items1, List<local_order_item.OrderItem> items2) {
    if (items1.length != items2.length) return false;
    
    for (int i = 0; i < items1.length; i++) {
      final item1 = items1[i];
      final item2 = items2[i];
      
      if (item1.id != item2.id ||
          item1.name != item2.name ||
          item1.price != item2.price ||
          item1.quantity != item2.quantity ||
          item1.kitchenNote != item2.kitchenNote ||
          item1.taxExempt != item2.taxExempt) {
        return false;
      }
    }
    
    return true;
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
      
      // Only sync orders that haven't been synced yet
      final unsyncedOrders = orders.where((o) => !o.isSynced).toList();

      if (unsyncedOrders.isEmpty) {
        debugPrint('ℹ️ No unsynced orders to process');
        return;
      }

      int syncedCount = 0;
      int failedCount = 0;
      
      final currentDeviceId = prefs.getString('device_id') ?? '';

      for (var order in unsyncedOrders) {
        Map<String, dynamic> result;
        
        // Determine if this is a NEW order or an UPDATE to an existing order
        // It's an update if:
        // 1. It belongs to another device (we are editing someone else's order)
        // 2. OR it has been synced before (syncedAt is not null)
        final isRemoteOrder = order.staffDeviceId.isNotEmpty && order.staffDeviceId != currentDeviceId;
        final wasSyncedBefore = order.syncedAt != null;
        
        if (isRemoteOrder || wasSyncedBefore) {
          debugPrint('🔄 Syncing UPDATE for order #${order.id} (Remote: $isRemoteOrder, WasSynced: $wasSyncedBefore)');
          result = await syncOrderUpdate(order);
        } else {
          debugPrint('➕ Syncing NEW order #${order.id}');
          result = await syncOrderToFirestore(order);
        }

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
    
    _mainOrderProcessingTimer?.cancel();
    _mainOrderProcessingTimer = null;
    
    _orderSubscription?.cancel();
    _orderSubscription = null;
    
    MenuSyncService.stopAllListeners();
    
    debugPrint('🛑 Auto-sync stopped');
  }

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

  // ---------------------------------------------------------------------------
  // PERSON SYNCING
  // ---------------------------------------------------------------------------

  static const String _syncedPersonsCollection = 'synced_persons';
  static StreamSubscription<QuerySnapshot>? _personsSubscription;
  static Function()? _onPersonsChangedCallback;

  static void setOnPersonsChangedCallback(Function() callback) {
    _onPersonsChangedCallback = callback;
  }

  static void _notifyPersonsChanged() {
    if (_onPersonsChangedCallback != null) {
      _onPersonsChangedCallback!();
    }
  }

  /// Start listening to person changes in Firestore
  static void startListeningToPersons(String companyId) async {
    if (_personsSubscription != null) return;
    
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        debugPrint('⚠️ Firebase not available, cannot listen to persons');
        return;
      }
    
      debugPrint('👂 Starting to listen for PERSON updates for company: $companyId');
      
      _personsSubscription = _firestore
          .collection(_syncedPersonsCollection)
          .where('companyId', isEqualTo: companyId)
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
            _processincomingPerson(change.doc);
          }
        }
      }, onError: (e) {
        debugPrint('❌ Error listening to persons: $e');
      });
    } catch (e) {
      debugPrint('❌ Error starting person listener: $e');
    }
  }

  static void stopListeningToPersons() {
    _personsSubscription?.cancel();
    _personsSubscription = null;
  }

  /// Process incoming person data
  static Future<void> _processincomingPerson(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final lastUpdatedBy = data['lastUpdatedBy'] as String?;
      final currentDeviceId = await _getDeviceId();

      // Skip if we made the update
      if (lastUpdatedBy == currentDeviceId) {
        return;
      }

      debugPrint('📥 Received PERSON update: ${doc.id}');
      
      final personData = data['person'] as Map<String, dynamic>;
      // Ensure 'credit' is handled as double
      if (personData['credit'] is int) {
        personData['credit'] = (personData['credit'] as int).toDouble();
      }

      final person = Person.fromJson(personData);
      
      final repo = LocalPersonRepository();
      await repo.savePerson(person); // This saves or updates
      
      _notifyPersonsChanged();
      
    } catch (e) {
      debugPrint('❌ Error processing incoming person: $e');
    }
  }

  /// Sync a local person update to Firestore
  static Future<void> syncPersonToFirestore(Person person) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id');
      final deviceId = await _getDeviceId();

      if (companyId == null) {
        debugPrint('⚠️ Cannot sync person: No company ID');
        return;
      }

      // Use composite ID to associate with company, or just use person ID if unique enough.
      // Assuming person.id is unique per installation or synced correctly.
      final docId = '${companyId}_${person.id}';

      debugPrint('📤 Syncing PERSON to Firestore: $docId');

      await _firestore.collection(_syncedPersonsCollection).doc(docId).set({
        'companyId': companyId,
        'person': person.toJson(),
        'lastUpdatedBy': deviceId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      debugPrint('❌ Error syncing person: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // CREDIT TRANSACTION SYNCING
  // ---------------------------------------------------------------------------

  static const String _syncedCreditCollection = 'synced_credit_transactions';
  static StreamSubscription<QuerySnapshot>? _creditSubscription;
  static Function()? _onCreditChangedCallback;

  static void setOnCreditChangedCallback(Function() callback) {
    _onCreditChangedCallback = callback;
  }

  static void _notifyCreditChanged() {
    if (_onCreditChangedCallback != null) {
      _onCreditChangedCallback!();
    }
  }

  static void startListeningToCreditTransactions(String companyId) async {
    if (_creditSubscription != null) return;
    
    try {
      await FirebaseService.ensureInitialized();
      
      if (!FirebaseService.isFirebaseAvailable) {
        debugPrint('⚠️ Firebase not available, cannot listen to credit transactions');
        return;
      }
    
      debugPrint('👂 Starting to listen for CREDIT updates for company: $companyId');
      
      _creditSubscription = _firestore
          .collection(_syncedCreditCollection)
          .where('companyId', isEqualTo: companyId)
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
            _processIncomingCredit(change.doc);
          }
        }
      }, onError: (e) {
        debugPrint('❌ Error listening to credit transactions: $e');
      });
    } catch (e) {
      debugPrint('❌ Error starting credit transaction listener: $e');
    }
  }

  static void stopListeningToCreditTransactions() {
    _creditSubscription?.cancel();
    _creditSubscription = null;
  }

  static Future<void> _processIncomingCredit(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final lastUpdatedBy = data['lastUpdatedBy'] as String?;
      final currentDeviceId = await _getDeviceId();

      if (lastUpdatedBy == currentDeviceId) {
        return;
      }

      debugPrint('📥 Received CREDIT update: ${doc.id}');
      
      final txData = data['transaction'] as Map<String, dynamic>;
      
      if (txData['isCompleted'] is bool) {
        txData['isCompleted'] = (txData['isCompleted'] as bool) ? 1 : 0;
      }
      
      final transaction = CreditTransaction.fromJson(txData);
      
      final repo = CreditTransactionRepository();
      await repo.saveCreditTransaction(transaction);
      
      _notifyCreditChanged();
    } catch (e) {
      debugPrint('❌ Error processing incoming credit: $e');
    }
  }

  static Future<void> syncCreditTransactionToFirestore(CreditTransaction transaction) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id');
      final deviceId = await _getDeviceId();

      if (companyId == null) return;

      final docId = '${companyId}_${transaction.id}';
      debugPrint('📤 Syncing CREDIT to Firestore: $docId');

      final jsonMap = transaction.toJson();
      
      await _firestore.collection(_syncedCreditCollection).doc(docId).set({
        'companyId': companyId,
        'transaction': jsonMap,
        'lastUpdatedBy': deviceId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      debugPrint('❌ Error syncing credit transaction: $e');
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