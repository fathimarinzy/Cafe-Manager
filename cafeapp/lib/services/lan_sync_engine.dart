// lib/services/lan_sync_engine.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/lan_sync_models.dart';
import '../repositories/local_order_repository.dart';
import '../repositories/local_menu_repository.dart';
import '../repositories/local_person_repository.dart';
import '../repositories/local_delivery_boy_repository.dart';
import '../repositories/credit_transaction_repository.dart';

/// Core sync engine that handles the actual data reconciliation.
/// Shared logic used by both server and client to apply incoming changes.
class LanSyncEngine {
  static const String _lastSyncedAtKey = 'lan_last_synced_at';

  final _orderRepo = LocalOrderRepository();
  final _menuRepo = LocalMenuRepository();
  final _personRepo = LocalPersonRepository();
  final _deliveryBoyRepo = LocalDeliveryBoyRepository();
  final _creditTxRepo = CreditTransactionRepository();

  Function(String message)? onLog;

  // ══════════════════════════════════════════════════════════════════════════
  // Last Synced At management
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncedAtKey);
  }

  Future<void> setLastSyncedAt(String timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncedAtKey, timestamp);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Apply a full SyncResponse (from either full or incremental sync)
  // ══════════════════════════════════════════════════════════════════════════

  /// Apply all entities from a sync response.
  /// Uses "latest updatedAt wins" conflict resolution.
  Future<void> applySyncResponse(SyncResponse response) async {
    _log('Applying sync response: '
        '${response.orders.length} orders, '
        '${response.menuItems.length} menu items, '
        '${response.persons.length} persons, '
        '${response.deliveryBoys.length} delivery boys, '
        '${response.creditTransactions.length} credit txns');

    await _applyOrders(response.orders);
    await _applyMenuItems(response.menuItems);
    await _applyPersons(response.persons);
    await _applyDeliveryBoys(response.deliveryBoys);
    await _applyCreditTransactions(response.creditTransactions);
    await _applyTables(response.tables);

    // Apply settings if provided
    if (response.settings != null) {
      await _applySettings(response.settings!);
    }

    // Update lastSyncedAt
    await setLastSyncedAt(response.serverTime);
    _log('Sync response applied. lastSyncedAt = ${response.serverTime}');
  }

  /// Apply all entities from a push payload (received by server from client).
  Future<void> applyPushPayload(SyncPushPayload payload) async {
    _log('Applying push payload from ${payload.deviceId}: '
        '${payload.orders.length} orders, '
        '${payload.menuItems.length} menu items, '
        '${payload.persons.length} persons, '
        '${payload.deliveryBoys.length} delivery boys, '
        '${payload.creditTransactions.length} credit txns');

    await _applyOrders(payload.orders);
    await _applyMenuItems(payload.menuItems);
    await _applyPersons(payload.persons);
    await _applyDeliveryBoys(payload.deliveryBoys);
    await _applyCreditTransactions(payload.creditTransactions);
    
    _log('Push payload applied from ${payload.deviceId}');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Apply a single real-time WebSocket event
  // ══════════════════════════════════════════════════════════════════════════

  /// Apply a single real-time event received via WebSocket.
  Future<void> applyEvent(SyncEvent event) async {
    _log('Applying event: ${event.event}');
    try {
      switch (event.event) {
        case SyncEventType.orderCreated:
        case SyncEventType.orderUpdated:
          await _applyOrders([event.data]);
          break;
        case SyncEventType.orderDeleted:
          await _softDeleteOrder(event.data['id']);
          break;
        case SyncEventType.menuUpdated:
          await _applyMenuItems([event.data]);
          break;
        case SyncEventType.menuDeleted:
          await _softDeleteMenuItem(event.data['id']?.toString() ?? '');
          break;
        case SyncEventType.tableUpdated:
          await _applyTables([event.data]);
          break;
        case SyncEventType.personUpdated:
          await _applyPersons([event.data]);
          break;
        case SyncEventType.personDeleted:
          await _softDeletePerson(event.data['id']?.toString() ?? '');
          break;
        case SyncEventType.deliveryBoyUpdated:
          await _applyDeliveryBoys([event.data]);
          break;
        case SyncEventType.deliveryBoyDeleted:
          await _softDeleteDeliveryBoy(event.data['id']?.toString() ?? '');
          break;
        case SyncEventType.creditTxUpdated:
          await _applyCreditTransactions([event.data]);
          break;
        case SyncEventType.settingsChanged:
          await _applySettings(event.data);
          break;
      }
    } catch (e) {
      _log('Error applying event ${event.event}: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Build local changes payload for pushing to server
  // ══════════════════════════════════════════════════════════════════════════

  /// Gather all local changes since [lastSyncedAt] into a SyncPushPayload.
  Future<SyncPushPayload> buildPushPayload(String deviceId) async {
    final lastSyncedAt = await getLastSyncedAt() ?? '1970-01-01T00:00:00.000';

    final orders = await _getLocalChangesSince('orders', 'updated_at', lastSyncedAt, _orderRepo);
    final menuItems = await _getLocalChangesSince('menu_items', 'lastUpdated', lastSyncedAt, _menuRepo);
    final persons = await _getLocalChangesSince('persons', 'updated_at', lastSyncedAt, _personRepo);
    final deliveryBoys = await _getLocalChangesSince('delivery_boys', 'updated_at', lastSyncedAt, _deliveryBoyRepo);
    final creditTxns = await _getLocalChangesSince('credit_transactions', 'updated_at', lastSyncedAt, _creditTxRepo);

    return SyncPushPayload(
      deviceId: deviceId,
      lastSyncedAt: lastSyncedAt,
      orders: orders,
      menuItems: menuItems,
      persons: persons,
      deliveryBoys: deliveryBoys,
      creditTransactions: creditTxns,
    );
  }

  Future<List<Map<String, dynamic>>> _getLocalChangesSince(
    String tableName,
    String timestampColumn,
    String since,
    dynamic repo,
  ) async {
    try {
      final db = await repo.database as Database;
      final results = await db.query(
        tableName,
        where: '$timestampColumn > ?',
        whereArgs: [since],
      );

      // IMPORTANT: If we are fetching orders, we must also eagerly fetch and join their items
      // since the raw 'orders' table does not contain the 'items' relation array natively
      if (tableName == 'orders') {
        final List<Map<String, dynamic>> ordersWithItems = [];
        for (var row in results) {
          final orderId = row['id'];
          final itemsList = await db.query(
            'order_items', 
            where: 'order_id = ?', 
            whereArgs: [orderId]
          );
          
          final Map<String, dynamic> joinedRow = Map<String, dynamic>.from(row);
          joinedRow['items'] = itemsList;
          ordersWithItems.add(joinedRow);
        }
        return ordersWithItems;
      }

      return results;
    } catch (e) {
      _log('Error getting local changes from $tableName: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Entity-specific apply methods with conflict resolution
  // ══════════════════════════════════════════════════════════════════════════

  /// Convert Order JSON (camelCase) to DB column format (snake_case).
  /// Also strips the nested 'items' list which can't be stored in the orders table.
  Map<String, dynamic> _orderJsonToDb(Map<String, dynamic> json) {
    return {
      if (json.containsKey('id')) 'id': json['id'],
      'staff_order_number': json['staffOrderNumber'] ?? json['staff_order_number'],
      'main_order_number': json['mainOrderNumber'] ?? json['main_order_number'],
      'staff_device_id': json['staffDeviceId'] ?? json['staff_device_id'] ?? '',
      'service_type': json['serviceType'] ?? json['service_type'] ?? '',
      'subtotal': json['subtotal'] ?? 0.0,
      'tax': json['tax'] ?? 0.0,
      'discount': json['discount'] ?? 0.0,
      'total': json['total'] ?? 0.0,
      'status': json['status'] ?? 'pending',
      'created_at': json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String(),
      'payment_method': json['paymentMethod'] ?? json['payment_method'] ?? 'cash',
      'customer_id': json['customerId'] ?? json['customer_id'],
      'cash_amount': json['cashAmount'] ?? json['cash_amount'],
      'bank_amount': json['bankAmount'] ?? json['bank_amount'],
      'is_synced': (json['isSynced'] == true || json['is_synced'] == 1) ? 1 : 0,
      'synced_at': json['syncedAt'] ?? json['synced_at'],
      'main_number_assigned': (json['mainNumberAssigned'] == true || json['main_number_assigned'] == 1) ? 1 : 0,
      'delivery_charge': json['deliveryCharge'] ?? json['delivery_charge'],
      'delivery_address': json['deliveryAddress'] ?? json['delivery_address'],
      'delivery_boy': json['deliveryBoy'] ?? json['delivery_boy'],
      'event_date': json['eventDate'] ?? json['event_date'],
      'event_time': json['eventTime'] ?? json['event_time'],
      'event_guest_count': json['eventGuestCount'] ?? json['event_guest_count'],
      'event_type': json['eventType'] ?? json['event_type'],
      'deposit_amount': json['depositAmount'] ?? json['deposit_amount'],
      'token_number': json['tokenNumber'] ?? json['token_number'],
      'customer_name': json['customerName'] ?? json['customer_name'],
      'updated_at': json['updatedAt'] ?? json['updated_at'] ?? DateTime.now().toIso8601String(),
      'is_deleted': (json['isDeleted'] == true || json['is_deleted'] == 1) ? 1 : 0,
      'is_temp_receipt_printed': (json['isTempReceiptPrinted'] == true || json['is_temp_receipt_printed'] == 1) ? 1 : 0,
    };
  }

  /// Convert MenuItem JSON (app-level keys) to DB column format.
  Map<String, dynamic> _menuItemJsonToDb(Map<String, dynamic> json) {
    return {
      'id': json['id']?.toString() ?? '',
      'name': json['name'] ?? '',
      'price': json['price'] ?? 0.0,
      'imageUrl': json['image'] ?? json['imageUrl'] ?? '',
      'category': json['category'] ?? '',
      'isAvailable': (json['available'] == true || json['available'] == 1 || json['isAvailable'] == true || json['isAvailable'] == 1) ? 1 : 0,
      'isDeleted': (json['isDeleted'] == true || json['isDeleted'] == 1) ? 1 : 0,
      'lastUpdated': json['lastUpdated'] ?? DateTime.now().toIso8601String(),
      'taxExempt': (json['taxExempt'] == true || json['taxExempt'] == 1) ? 1 : 0,
      'isPerPlate': (json['isPerPlate'] == true || json['isPerPlate'] == 1) ? 1 : 0,
      'purchasePrice': json['purchasePrice'] ?? 0.0,
      'barcode': json['barcode'] ?? '',
    };
  }

  /// Apply order items from the JSON 'items' list into the order_items table.
  Future<void> _applyOrderItems(Transaction txn, int orderId, List<dynamic> items) async {
    // Delete existing items for this order first
    await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
    
    final seenItems = <String>{};
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        // Ensure menu_item_id is strictly an integer
        final rawMenuId = item['id'] ?? item['menu_item_id'];
        int menuItemId = 0;
        if (rawMenuId is int) {
          menuItemId = rawMenuId;
        } else if (rawMenuId is String) {
          menuItemId = int.tryParse(rawMenuId) ?? 0;
        }

        final name = item['name'] ?? '';
        final price = item['price'] ?? 0.0;
        final qty = item['quantity'] ?? 1;
        final note = item['kitchenNote'] ?? item['kitchen_note'] ?? '';
        
        final hash = '$menuItemId-$name-$price-$qty-$note';
        if (seenItems.contains(hash)) {
          continue; // Skip identical duplicated items
        }
        seenItems.add(hash);

        await txn.insert('order_items', {
          'order_id': orderId,
          'menu_item_id': menuItemId,
          'name': name,
          'price': price,
          'quantity': qty,
          'kitchen_note': note,
          'tax_exempt': item['taxExempt'] == true ? 1 : (item['tax_exempt'] ?? 0),
          'purchase_price': item['purchasePrice'] ?? item['purchase_price'] ?? 0.0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  Future<void> _applyOrders(List<Map<String, dynamic>> remoteOrders) async {
    if (remoteOrders.isEmpty) return;
    try {
      final db = await _orderRepo.database;
      await db.transaction((txn) async {
        for (final remote in remoteOrders) {
          final remoteId = remote['id'];
          if (remoteId == null) continue;

          // Convert JSON keys to DB column names
          final dbMap = _orderJsonToDb(remote);

          final existing = await txn.query('orders', where: 'id = ?', whereArgs: [remoteId]);
          
          if (existing.isEmpty) {
            // INSERT new record
            await txn.insert('orders', dbMap, conflictAlgorithm: ConflictAlgorithm.replace);
            _log('Inserted order #$remoteId');
          } else {
            // Conflict resolution: latest updated_at wins
            final localUpdatedAt = existing.first['updated_at'] as String?;
            final remoteUpdatedAt = dbMap['updated_at'] as String?;
            
            if (_shouldApplyRemote(localUpdatedAt, remoteUpdatedAt)) {
              // Don't overwrite the id column during update
              final updateMap = Map<String, dynamic>.from(dbMap)..remove('id');
              await txn.update('orders', updateMap, where: 'id = ?', whereArgs: [remoteId]);
              _log('Updated order #$remoteId (remote wins)');
            }
          }

          // Also apply the order items if present
          final items = remote['items'];
          if (items is List && items.isNotEmpty) {
            final orderId = remoteId is int ? remoteId : int.tryParse(remoteId.toString());
            if (orderId != null) {
              await _applyOrderItems(txn, orderId, items);
              _log('Applied ${items.length} items for order #$orderId');
            }
          }
        }
      });
    } catch (e) {
      _log('Error applying orders: $e');
    }
  }

  Future<void> _applyMenuItems(List<Map<String, dynamic>> remoteItems) async {
    if (remoteItems.isEmpty) return;
    try {
      final db = await _menuRepo.database;
      for (final remote in remoteItems) {
        final remoteId = remote['id'];
        if (remoteId == null) continue;

        // Convert JSON keys to DB column names
        final dbMap = _menuItemJsonToDb(remote);

        final existing = await db.query('menu_items', where: 'id = ?', whereArgs: [remoteId.toString()]);
        
        if (existing.isEmpty) {
          await db.insert('menu_items', dbMap, conflictAlgorithm: ConflictAlgorithm.replace);
          _log('Inserted menu item $remoteId');
        } else {
          final localUpdatedAt = existing.first['lastUpdated'] as String?;
          final remoteUpdatedAt = dbMap['lastUpdated'] as String?;
          
          if (_shouldApplyRemote(localUpdatedAt, remoteUpdatedAt)) {
            await db.update('menu_items', dbMap, where: 'id = ?', whereArgs: [remoteId.toString()]);
            _log('Updated menu item $remoteId (remote wins)');
          }
        }
      }
    } catch (e) {
      _log('Error applying menu items: $e');
    }
  }

  Future<void> _applyPersons(List<Map<String, dynamic>> remotePersons) async {
    if (remotePersons.isEmpty) return;
    try {
      final db = await _personRepo.database;
      for (final remote in remotePersons) {
        final remoteId = remote['id'];
        if (remoteId == null) continue;

        final existing = await db.query('persons', where: 'id = ?', whereArgs: [remoteId]);
        
        if (existing.isEmpty) {
          await db.insert('persons', remote, conflictAlgorithm: ConflictAlgorithm.replace);
          _log('Inserted person $remoteId');
        } else {
          final localUpdatedAt = existing.first['updated_at'] as String?;
          final remoteUpdatedAt = remote['updated_at'] as String?;
          
          if (_shouldApplyRemote(localUpdatedAt, remoteUpdatedAt)) {
            await db.update('persons', remote, where: 'id = ?', whereArgs: [remoteId]);
            _log('Updated person $remoteId (remote wins)');
          }
        }
      }
    } catch (e) {
      _log('Error applying persons: $e');
    }
  }

  Future<void> _applyDeliveryBoys(List<Map<String, dynamic>> remoteBoys) async {
    if (remoteBoys.isEmpty) return;
    try {
      final db = await _deliveryBoyRepo.database;
      for (final remote in remoteBoys) {
        final remoteId = remote['id'];
        if (remoteId == null) continue;

        final existing = await db.query('delivery_boys', where: 'id = ?', whereArgs: [remoteId]);
        
        if (existing.isEmpty) {
          await db.insert('delivery_boys', remote, conflictAlgorithm: ConflictAlgorithm.replace);
          _log('Inserted delivery boy $remoteId');
        } else {
          final localUpdatedAt = existing.first['updated_at'] as String?;
          final remoteUpdatedAt = remote['updated_at'] as String?;
          
          if (_shouldApplyRemote(localUpdatedAt, remoteUpdatedAt)) {
            await db.update('delivery_boys', remote, where: 'id = ?', whereArgs: [remoteId]);
            _log('Updated delivery boy $remoteId (remote wins)');
          }
        }
      }
    } catch (e) {
      _log('Error applying delivery boys: $e');
    }
  }

  Future<void> _applyCreditTransactions(List<Map<String, dynamic>> remoteTxns) async {
    if (remoteTxns.isEmpty) return;
    try {
      final db = await _creditTxRepo.database;
      for (final remote in remoteTxns) {
        final remoteId = remote['id'];
        if (remoteId == null) continue;

        final existing = await db.query('credit_transactions', where: 'id = ?', whereArgs: [remoteId]);
        
        if (existing.isEmpty) {
          await db.insert('credit_transactions', remote, conflictAlgorithm: ConflictAlgorithm.replace);
          _log('Inserted credit transaction $remoteId');
        } else {
          final localUpdatedAt = existing.first['updated_at'] as String?;
          final remoteUpdatedAt = remote['updated_at'] as String?;
          
          if (_shouldApplyRemote(localUpdatedAt, remoteUpdatedAt)) {
            await db.update('credit_transactions', remote, where: 'id = ?', whereArgs: [remoteId]);
            _log('Updated credit transaction $remoteId (remote wins)');
          }
        }
      }
    } catch (e) {
      _log('Error applying credit transactions: $e');
    }
  }

/// Apply table data to SharedPreferences
  Future<void> _applyTables(List<Map<String, dynamic>> remoteTables) async {
    if (remoteTables.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString('dining_tables');
      
      List<Map<String, dynamic>> currentTables = [];
      if (localJson != null) {
        final List<dynamic> decoded = jsonDecode(localJson);
        currentTables = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      
      // Merge logic for tables
      for (var remoteTable in remoteTables) {
        final id = remoteTable['id']?.toString() ?? '';
        final number = remoteTable['number'];
        
        if (id.isEmpty && number == null) continue;

        // Try matching by ID first
        int index = -1;
        if (id.isNotEmpty) {
          index = currentTables.indexWhere((t) => t['id']?.toString() == id);
        }
        
        // If not found by ID, match by table number
        // (Default tables generate random IDs locally, so 'number' is the true logical identifier)
        if (index == -1 && number != null) {
          index = currentTables.indexWhere((t) => t['number'] == number);
        }
        
        if (index >= 0) {
          // Overwrite with remote data but preserve the local ID
          final localId = currentTables[index]['id'];
          currentTables[index] = Map<String, dynamic>.from(remoteTable);
          currentTables[index]['id'] = localId;
        } else {
          currentTables.add(remoteTable);
        }
      }

      await prefs.setString('dining_tables', jsonEncode(currentTables));
      await prefs.reload(); // Force cache update after setting
      _log('Merged ${remoteTables.length} remote tables into local shared prefs');
    } catch (e) {
      _log('Error applying tables: $e');
    }
  }

  /// Apply settings to SharedPreferences
  Future<void> _applySettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in settings.entries) {
        final value = entry.value;
        if (value is String) {
          await prefs.setString(entry.key, value);
        } else if (value is int) {
          await prefs.setInt(entry.key, value);
        } else if (value is double) {
          await prefs.setDouble(entry.key, value);
        } else if (value is bool) {
          await prefs.setBool(entry.key, value);
        }
      }
      _log('Applied settings');
    } catch (e) {
      _log('Error applying settings: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Soft-delete helpers
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _softDeleteOrder(dynamic id) async {
    if (id == null) return;
    try {
      final db = await _orderRepo.database;
      await db.update('orders', {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [id]);
      _log('Soft-deleted order #$id');
    } catch (e) {
      _log('Error soft-deleting order: $e');
    }
  }

  Future<void> _softDeleteMenuItem(String id) async {
    if (id.isEmpty) return;
    try {
      final db = await _menuRepo.database;
      await db.update('menu_items', {
        'isDeleted': 1,
        'lastUpdated': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [id]);
      _log('Soft-deleted menu item $id');
    } catch (e) {
      _log('Error soft-deleting menu item: $e');
    }
  }

  Future<void> _softDeletePerson(String id) async {
    if (id.isEmpty) return;
    try {
      final db = await _personRepo.database;
      await db.update('persons', {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [id]);
      _log('Soft-deleted person $id');
    } catch (e) {
      _log('Error soft-deleting person: $e');
    }
  }

  Future<void> _softDeleteDeliveryBoy(String id) async {
    if (id.isEmpty) return;
    try {
      final db = await _deliveryBoyRepo.database;
      await db.update('delivery_boys', {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [id]);
      _log('Soft-deleted delivery boy $id');
    } catch (e) {
      _log('Error soft-deleting delivery boy: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Conflict resolution
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns true if the remote record should overwrite the local one.
  /// Strategy: latest updatedAt wins.
  bool _shouldApplyRemote(String? localUpdatedAt, String? remoteUpdatedAt) {
    if (remoteUpdatedAt == null) return false;
    if (localUpdatedAt == null) return true;

    try {
      final localTime = DateTime.parse(localUpdatedAt);
      final remoteTime = DateTime.parse(remoteUpdatedAt);
      return remoteTime.isAfter(localTime);
    } catch (e) {
      // If parsing fails, apply remote to be safe
      return true;
    }
  }

  void _log(String message) {
    debugPrint('[LanSyncEngine] $message');
    onLog?.call(message);
  }
}
