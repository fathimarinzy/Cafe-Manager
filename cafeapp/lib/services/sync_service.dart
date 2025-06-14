import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../repositories/local_menu_repository.dart';
import '../repositories/local_order_repository.dart';
import '../repositories/local_person_repository.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../models/menu_item.dart';
import '../utils/deduplication_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SyncStatus {
  idle,
  syncing,
  completed,
  error,
  
}

/// Service that handles synchronization between local database and server API
class SyncService {
  // Singleton pattern
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal() {
    debugPrint('SyncService constructor - should only happen once');
  }
  
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  final LocalMenuRepository _localMenuRepo = LocalMenuRepository();
  final LocalOrderRepository _localOrderRepo = LocalOrderRepository();
  final LocalPersonRepository _localPersonRepo = LocalPersonRepository();
  final ApiService _apiService = ApiService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final DeduplicationHelper _deduplicationHelper = DeduplicationHelper();
  
  SyncStatus _currentStatus = SyncStatus.idle;
  bool _isInitialized = false;
  Timer? _syncResetTimer;
  
  // Lock file path
  String? _lockFilePath;
  
  // Track synced orders to prevent duplicates
  Set<String> _syncedOrdersCache = {};
  final String _syncedOrdersCacheKey = 'synced_orders';
  
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  SyncStatus get currentStatus => _currentStatus;
  
  void initialize() {
    if (_isInitialized) {
      debugPrint('SyncService already initialized, skipping');
      return;
    }
    
    _isInitialized = true;
    debugPrint('Initializing SyncService - singleton instance');
    
    // Initialize lock file path
    _initLockFile();
    
    // Initialize deduplication helper
    _deduplicationHelper.initialize();
    
    // Load synced orders cache
    _loadSyncedOrdersCache();
    
    // Listen for connectivity changes
    _connectivityService.connectivityStream.listen((isConnected) {
      if (isConnected) {
        // If we regain connectivity, try to sync after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          syncChanges();
        });
      }
    });
    
    // Debug the pending operations on init
    _debugPendingOperations();

  }
  
  // Load synced orders cache from shared preferences
  Future<void> _loadSyncedOrdersCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedOrders = prefs.getStringList(_syncedOrdersCacheKey) ?? [];
      _syncedOrdersCache = cachedOrders.toSet();
      debugPrint('Loaded ${_syncedOrdersCache.length} synced order IDs from cache');
    } catch (e) {
      debugPrint('Error loading synced orders cache: $e');
    }
  }
  // Add this method to your SyncService class
Future<void> _saveSyncedOrdersCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_syncedOrdersCacheKey, _syncedOrdersCache.toList());
    debugPrint('Saved ${_syncedOrdersCache.length} synced order IDs to cache');
  } catch (e) {
    debugPrint('Error saving synced orders cache: $e');
  }
}
  
  // Initialize lock file path
  Future<void> _initLockFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _lockFilePath = '${dir.path}/sync_lock.txt';
      debugPrint('Lock file path: $_lockFilePath');
    } catch (e) {
      debugPrint('Error initializing lock file: $e');
    }
  }
  
  // Check if sync is in progress using file lock
  Future<bool> _isSyncInProgress() async {
    if (_lockFilePath == null) await _initLockFile();
    if (_lockFilePath == null) return false;
    
    try {
      final file = File(_lockFilePath!);
      if (await file.exists()) {
        // Check if lock is stale (older than 5 minutes)
        final stat = await file.stat();
        final now = DateTime.now();
        final lockAge = now.difference(stat.modified);
        
        if (lockAge.inMinutes > 5) {
          // Lock is stale, remove it
          await file.delete();
          return false;
        }
        
        return true; // Lock exists and is not stale
      }
      return false;
    } catch (e) {
      debugPrint('Error checking sync lock: $e');
      return false;
    }
  }
  
  // Create lock file
  Future<bool> _createLock() async {
    if (_lockFilePath == null) await _initLockFile();
    if (_lockFilePath == null) return false;
    
    try {
      final file = File(_lockFilePath!);
      await file.writeAsString(DateTime.now().toIso8601String());
      return true;
    } catch (e) {
      debugPrint('Error creating sync lock: $e');
      return false;
    }
  }
  
  // Remove lock file
  Future<void> _removeLock() async {
    if (_lockFilePath == null) return;
    
    try {
      final file = File(_lockFilePath!);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error removing sync lock: $e');
    }
  }
  
  // Debug method to inspect pending operations
  Future<void> _debugPendingOperations() async {
    try {
      final menuOps = await _localMenuRepo.getPendingOperations();
      debugPrint('===== DEBUG: PENDING MENU OPERATIONS =====');
      debugPrint('Total count: ${menuOps.length}');
      
      // Debug pending orders
      final pendingOrders = await _localOrderRepo.getUnsyncedOrders();
      debugPrint('===== DEBUG: PENDING ORDERS =====');
      debugPrint('Total count: ${pendingOrders.length}');
      
      // Group operations by operation type for better debugging
      final Map<String, List<Map<String, dynamic>>> operationsByType = {
        'ADD': [],
        'UPDATE': [],
        'DELETE': [],
        'UNKNOWN': [],
      };
      
      for (final op in menuOps) {
        final opType = op['operation']?.toString().toUpperCase() ?? 'UNKNOWN';
        if (operationsByType.containsKey(opType)) {
          operationsByType[opType]!.add(op);
        } else {
          operationsByType['UNKNOWN']!.add(op);
        }
      }
      
      // Print summary by operation type
      for (final type in operationsByType.keys) {
        final count = operationsByType[type]!.length;
        if (count > 0) {
          debugPrint('$type operations: $count');
        }
      }
    } catch (e) {
      debugPrint('Error debugging pending operations: $e');
    }
  }
  
  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
    
    // Set a safety timer to reset the syncing state after a timeout
    _syncResetTimer?.cancel();
    if (status == SyncStatus.syncing) {
      _syncResetTimer = Timer(const Duration(seconds: 30), () {
        if (_currentStatus == SyncStatus.syncing) {
          debugPrint('Sync safety timeout triggered - resetting sync state');
          _resetSyncState();
        }
      });
    }
  }
  
  // Parse JSON data with robust error handling
  Map<String, dynamic> _parseJsonData(dynamic data) {
    if (data == null) return {};
    
    try {
      if (data is String) {
        // Try to parse as JSON
        try {
          return json.decode(data);
        } catch (e) {
          // Try to extract JSON from string representation
          final regExp = RegExp(r'{.*}');
          final match = regExp.firstMatch(data);
          if (match != null) {
            final jsonStr = match.group(0);
            if (jsonStr != null) {
              try {
                return json.decode(jsonStr);
              } catch (e) {
                // Failed to parse extracted JSON
              }
            }
          }
          
          // Return empty map if all parsing attempts fail
          return {};
        }
      } else if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint('Error parsing JSON data: $e');
    }
    
    return {};
  }
  
  // Convert Map to MenuItem object with better error handling
  MenuItem _mapToMenuItem(Map<String, dynamic> map) {
    String id = '';
    
    // Ensure id is never null - use a default if needed
    if (map['id'] != null) {
      id = map['id'].toString();
    } else {
      // Generate a temporary ID if none exists
      id = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('Warning: Created temporary ID for item: $id');
    }
    
    return MenuItem(
      id: id,
      name: map['name']?.toString() ?? '',
      price: map['price'] is num ? map['price'].toDouble() : 0.0,
      imageUrl: map['image']?.toString() ?? map['imageUrl']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      isAvailable: map['available'] == 1 || map['available'] == true || map['isAvailable'] == true,
    );
  }
  
  // Method to reset the sync state manually
  Future<void> _resetSyncState() async {
    _updateStatus(SyncStatus.idle);
    await _removeLock();
    debugPrint('Sync state reset');
  }
  
  // Determine if an item ID is a local temporary ID or a server ID
  bool _isLocalId(String id) {
    // Local IDs typically start with "local_" or are long timestamps
    return id.startsWith('local_') || 
           id.length > 10 && double.tryParse(id) != null;
  }
  
  // Helper to handle 404 errors gracefully during delete
  Future<bool> _safeDeleteItem(String itemId) async {
    try {
      await _apiService.deleteMenuItem(itemId);
      return true;
    } catch (e) {
      // If the error message contains "not found", consider it a success
      if (e.toString().toLowerCase().contains('not found')) {
        debugPrint('Item $itemId not found on server, considering delete successful');
        return true;
      }
      rethrow;
    }
  }
  
  /// Main synchronization method with improved deduplication
  Future<bool> syncChanges() async {
    // Check if we're online
    final isOnline = await _connectivityService.checkConnection();
    if (!isOnline) {
      debugPrint('Cannot sync - device is offline');
      return false;
    }
    
    // Check if sync is already in progress using file lock
    final syncInProgress = await _isSyncInProgress();
    if (syncInProgress) {
      debugPrint('Sync already in progress (file lock exists)');
      return false;
    }
    
    // Create lock file BEFORE any other async operations
    final lockCreated = await _createLock();
    if (!lockCreated) {
      debugPrint('Failed to create sync lock, aborting');
      return false;
    }
    
    // Update status to syncing
    _updateStatus(SyncStatus.syncing);
    
    try {
      // Debug pending operations
      await _debugPendingOperations();
      
      // First sync menu operations
      await _syncMenuOperations();
      
      // Then sync order operations
      await _syncOrderOperations();
       // Sync persons
      await _syncPersons();
      
      _updateStatus(SyncStatus.completed);
      await _removeLock();
      return true;
    } catch (e) {
      debugPrint('Error during sync: $e');
      _updateStatus(SyncStatus.error);
      await _removeLock();
      return false;
    } finally {
      // Always remove the lock
      await _removeLock();
      
      // Cancel the safety timer
      _syncResetTimer?.cancel();
    }
  }

  // Sync menu operations - unchanged from original
  Future<void> _syncMenuOperations() async {
    // [Keep your existing menu sync code here]
    // Get all pending menu operations
    final pendingOps = await _localMenuRepo.getPendingOperations();
    debugPrint('Found ${pendingOps.length} pending menu operations to sync');
    
    if (pendingOps.isEmpty) {
      return;
    }
    
    // Track successfully processed operations
    final List<int> processedOpIds = [];
    
    // Process each operation individually, with careful duplicate checking
    for (final operation in pendingOps) {
      final operationId = operation['id'] as int;
      final itemId = operation['itemId']?.toString() ?? '';
      final opType = operation['operation']?.toString().toUpperCase() ?? '';
      
      // Skip if no itemId or invalid operation type
      if (itemId.isEmpty || opType.isEmpty) {
        processedOpIds.add(operationId);
        continue;
      }
      
      // Parse the item data
      Map<String, dynamic> itemData = {};
      try {
        if (operation['itemData'] != null) {
          itemData = _parseJsonData(operation['itemData']);
        }
      } catch (e) {
        debugPrint('Error parsing item data: $e');
        continue;
      }
      
      // Skip operations with empty data
      if (itemData.isEmpty) {
        debugPrint('Skipping operation: Empty item data');
        processedOpIds.add(operationId);
        continue;
      }
      
      // CRITICAL: Check if this operation has already been processed
      // using the deduplication helper (persistent across app restarts)
      final alreadyProcessed = await _deduplicationHelper.isOperationProcessed(
        opType, itemId, itemData);
      
      if (alreadyProcessed) {
        debugPrint('Skipping $opType operation for item $itemId - already processed (from deduplication DB)');
        processedOpIds.add(operationId);
        continue;
      }
      
      try {
        bool success = false;
        
        if (opType == 'ADD') {
          // Create a new MenuItem from the data
          final MenuItem menuItem = _mapToMenuItem(itemData);
          
          // Call the API to add the item
          debugPrint('Adding item to server: ${menuItem.name}');
          final addedItem = await _apiService.addMenuItem(menuItem);
          await _localMenuRepo.markItemAsSynced(itemId);
          
          // Mark as processed in deduplication database
          await _deduplicationHelper.markOperationProcessed(opType, itemId, itemData);
          
          success = true;
          debugPrint('Successfully added item to server: ${addedItem.id}');
        } else if (opType == 'UPDATE') {
          // Create a MenuItem from the data
          final MenuItem menuItem = _mapToMenuItem(itemData);
          
          // Skip local IDs - they can't be updated on server
          if (_isLocalId(itemId)) {
            debugPrint('Skipping UPDATE for local ID $itemId - cannot update on server');
            await _deduplicationHelper.markOperationProcessed(opType, itemId, itemData);
            processedOpIds.add(operationId);
            continue;
          }
          
          // Call the API to update the item
          debugPrint('Updating item on server: ${menuItem.name}');
          await _apiService.updateMenuItem(menuItem);
          await _localMenuRepo.markItemAsSynced(itemId);
          
          // Mark as processed in deduplication database
          await _deduplicationHelper.markOperationProcessed(opType, itemId, itemData);
          
          success = true;
          debugPrint('Successfully updated item on server: ${menuItem.id}');
        } else if (opType == 'DELETE') {
          // Skip local IDs - they don't exist on server
          if (_isLocalId(itemId)) {
            debugPrint('Skipping DELETE for local ID $itemId - does not exist on server');
            await _deduplicationHelper.markOperationProcessed(opType, itemId, itemData);
            processedOpIds.add(operationId);
            continue;
          }
          
          // Delete the item on the server
          debugPrint('Deleting item from server: $itemId');
          final success = await _safeDeleteItem(itemId);
          
          if (success) {
            // Mark as processed in deduplication database
            await _deduplicationHelper.markOperationProcessed(opType, itemId, itemData);
            
            processedOpIds.add(operationId);
            debugPrint('Successfully deleted item from server: $itemId');
          }
        }
        
        // If successful, mark operation as processed
        if (success) {
          processedOpIds.add(operationId);
        }
      } catch (e) {
        debugPrint('Error processing operation: $e');
        
        // If we get a "not found" error for DELETE or UPDATE, mark as processed anyway
        if ((opType == 'DELETE' || opType == 'UPDATE') && 
            e.toString().toLowerCase().contains('not found')) {
          await _deduplicationHelper.markOperationProcessed(opType, itemId, itemData);
          processedOpIds.add(operationId);
        }
      }
      
      // Small delay between operations to prevent overloading the server
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // Debug log before removing operations
    debugPrint('Removing ${processedOpIds.length} processed menu operations');
    
    // Remove processed operations
    for (final id in processedOpIds) {
      await _localMenuRepo.removePendingOperation(id);
    }
  }

  // Updated sync order operations with better deduplication
  // Replace the _syncOrderOperations method in lib/services/sync_service.dart

Future<void> _syncOrderOperations() async {
  // Get all unsynced orders
  final unsyncedOrders = await _localOrderRepo.getUnsyncedOrders();
  debugPrint('Found ${unsyncedOrders.length} unsynced orders to sync');
  
  if (unsyncedOrders.isEmpty) {
    return;
  }
  
  // Track successfully processed orders
  final List<int> processedOrderIds = [];
  
  // Enhanced deduplication: Keep track of already synced orders by ID
  // This is a temporary in-memory cache just for this sync session
  final Set<int> alreadySyncedInThisSession = {};
  
  // Process each order with improved deduplication
  for (final order in unsyncedOrders) {
    if (order.id == null) continue; // Skip orders without ID
    
    // CRITICAL: Skip if we've already processed this order in the current session
    if (alreadySyncedInThisSession.contains(order.id)) {
      debugPrint('Skipping order ${order.id} - already synced in this session');
      processedOrderIds.add(order.id!);
      continue;
    }
    
    // Check if this order is already marked as synced in the database
    // This should be a definitive check, not a heuristic
    bool isAlreadySynced = false;
    try {
      final db = await _localOrderRepo.database;
      final result = await db.query(
        'orders',
        columns: ['is_synced', 'server_id', 'sync_id'],
        where: 'id = ?',
        whereArgs: [order.id!],
      );
      
      if (result.isNotEmpty) {
        final isSynced = result.first['is_synced'] == 1;
        final syncId = result.first['sync_id'];
        final serverId = result.first['server_id'];
        
        if (isSynced && syncId != null) {
          debugPrint('Order ${order.id} already synced with sync_id: $syncId and server_id: $serverId');
          isAlreadySynced = true;
          processedOrderIds.add(order.id!);
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error checking order sync status: $e');
    }
    
    // Skip if this order has already been synced (using cache)
    final syncKey = '${order.id}_';
    final alreadySyncedInCache = _syncedOrdersCache.any((key) => key.startsWith(syncKey));
    if (alreadySyncedInCache) {
      debugPrint('Order ${order.id} already synced based on cache. Skipping.');
      processedOrderIds.add(order.id!);
      continue;
    }
    
    // If we've made it this far, we need to sync the order
    if (!isAlreadySynced) {
      try {
        // Add to our temporary session tracking to prevent duplicates even within one sync
        alreadySyncedInThisSession.add(order.id!);
        
        // Convert order items to server format
        final items = order.items.map((item) => {
          'id': item.id.toString(),
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'kitchenNote': item.kitchenNote,
        }).toList();
        
        // Create order on server
        debugPrint('Creating order on server: ${order.serviceType}, ID: ${order.id}');
        final serverOrder = await _apiService.createOrder(
          order.serviceType,
          items,
          order.subtotal,
          order.tax,
          order.discount,
          order.total,
          paymentMethod: order.paymentMethod ?? 'cash',
          customerId: order.customerId,
        );
        
        if (serverOrder != null) {
          // Generate a unique sync ID for this order
          final syncId = '${order.id}_${DateTime.now().millisecondsSinceEpoch}';
          
          // Mark order as synced with the new server ID
          await _localOrderRepo.markOrderAsSynced(order.id!, serverOrder.id);
          
          // Add to processed IDs
          processedOrderIds.add(order.id!);
          
          // Add to synced orders cache to prevent future duplicates
          _syncedOrdersCache.add(syncId);
          
          debugPrint('Successfully synced order ${order.id} to server ID ${serverOrder.id}');
        } else {
          debugPrint('Failed to create order on server: ${order.id}');
        }
      } catch (e) {
        debugPrint('Error syncing order ${order.id}: $e');
        
        // Record the sync error
        await _localOrderRepo.recordSyncError(order.id!, e.toString());
      }
    }
    
    // Small delay between operations to prevent overloading the server
    await Future.delayed(const Duration(milliseconds: 300));
  }
  
  // Save the updated synced orders cache
  await _saveSyncedOrdersCache();
  
  debugPrint('Successfully synced ${processedOrderIds.length} orders');
}
 

// New helper method to check if an order is already marked as synced in the database
// Future<bool> _checkIfOrderSynced(int orderId) async {
//   try {
//     final db = await _localOrderRepo.database;
//     final result = await db.query(
//       'orders',
//       columns: ['is_synced'],
//       where: 'id = ?',
//       whereArgs: [orderId],
//     );
    
//     if (result.isNotEmpty) {
//       final isSynced = result.first['is_synced'] == 1;
//       debugPrint('Order $orderId sync status in database: ${isSynced ? 'synced' : 'not synced'}');
//       return isSynced;
//     }
//     return false;
//   } catch (e) {
//     debugPrint('Error checking order sync status: $e');
//     return false;
//   }
// }
  // Sync persons
  Future<void> _syncPersons() async {
    final unsyncedPersons = await _localPersonRepo.getUnsyncedPersons();
    debugPrint('Found ${unsyncedPersons.length} unsynced persons to sync');
    
    if (unsyncedPersons.isEmpty) {
      return;
    }
    
    // Track successfully processed persons
    final List<String> processedIds = [];
    
    // Process each person individually
    for (final person in unsyncedPersons) {
      // Skip if no ID
      if (person.id == null || person.id!.isEmpty) continue;
      
      // Skip already synced persons or those with server IDs
      if (!person.id!.startsWith('local_')) {
        processedIds.add(person.id!);
        continue;
      }
      
      try {
        // Create person on server
        final serverPerson = await _apiService.createPerson(person);
        
        // Update local record with server ID
        await _localPersonRepo.markPersonAsSynced(person.id!, serverPerson.id);
        
        // Add to processed IDs
        processedIds.add(person.id!);
        
        debugPrint('Synced person successfully: ${person.id} -> ${serverPerson.id}');
      } catch (e) {
        debugPrint('Error syncing person ${person.id}: $e');
      }
      
      // Small delay between operations to prevent overloading the server
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    debugPrint('Successfully synced ${processedIds.length} persons');
  }
  
  
   void dispose() {
    _syncResetTimer?.cancel();
    _syncStatusController.close();
    _removeLock(); // Clean up lock file when service is disposed
  }
}