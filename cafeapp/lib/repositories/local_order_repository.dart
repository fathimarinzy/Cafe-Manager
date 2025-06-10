import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import 'package:flutter/foundation.dart';

class LocalOrderRepository {
  static Database? _database;

  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database with updated schema
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cafe_orders.db');
    
    return await openDatabase(
      path,
      version: 3, // Increment version to trigger onUpgrade
      onCreate: (db, version) async {
        // Create orders table with all necessary fields from the start
        await db.execute('''
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            service_type TEXT NOT NULL,
            subtotal REAL NOT NULL,
            tax REAL NOT NULL,
            discount REAL NOT NULL,
            total REAL NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            payment_method TEXT DEFAULT 'cash',
            customer_id TEXT,
            is_synced INTEGER NOT NULL DEFAULT 0,
            server_id INTEGER,
            last_sync_attempt TEXT,
            sync_error TEXT,
            sync_id TEXT
          )
        ''');
        
        // Create order items table
        await db.execute('''
          CREATE TABLE order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            menu_item_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            quantity INTEGER NOT NULL,
            kitchen_note TEXT,
            FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
          )
        ''');

        // Create indices for faster lookups
        await db.execute('CREATE INDEX idx_orders_sync ON orders (is_synced)');
        await db.execute('CREATE INDEX idx_orders_server_id ON orders (server_id)');
        await db.execute('CREATE INDEX idx_order_items_order_id ON order_items (order_id)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('Upgrading database from version $oldVersion to $newVersion');
        
        if (oldVersion < 2) {
          // Add columns that were missing in version 1
          try {
            await db.execute('ALTER TABLE orders ADD COLUMN last_sync_attempt TEXT');
            await db.execute('ALTER TABLE orders ADD COLUMN sync_error TEXT');
          } catch (e) {
            debugPrint('Error adding columns: $e');
          }
          
          // Create indices if they don't exist
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_sync ON orders (is_synced)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_server_id ON orders (server_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items (order_id)');
          } catch (e) {
            debugPrint('Error creating indices: $e');
          }
        }
        
        if (oldVersion < 3) {
          // Add sync_id column to prevent duplicate syncs
          try {
            await db.execute('ALTER TABLE orders ADD COLUMN sync_id TEXT');
          } catch (e) {
            debugPrint('Error adding sync_id column: $e');
          }
        }
      },
    );
  }

  // Mark an order as synced
  Future<void> markOrderAsSynced(int localOrderId, int? serverOrderId) async {
  try {
    final db = await database;
    
    // Generate a unique sync ID to prevent duplicate syncs
    final syncId = '${localOrderId}_${DateTime.now().millisecondsSinceEpoch}';
    
    // First check if this order has already been synced
    final existing = await db.query(
      'orders',
      columns: ['is_synced', 'server_id', 'sync_id'],
      where: 'id = ?',
      whereArgs: [localOrderId]
    );
    
    if (existing.isNotEmpty && existing.first['is_synced'] == 1) {
      // Check if the sync_id is present, indicating this was synced with the improved system
      final existingSyncId = existing.first['sync_id'];
      if (existingSyncId != null && existingSyncId.toString().isNotEmpty) {
        debugPrint('Order $localOrderId already marked as synced with sync_id: $existingSyncId. Skipping.');
        return;
      }
      
      // If there's no sync_id but is_synced is 1, it was synced with an older version
      // Let's update it with the new sync_id to prevent future duplicate syncs
      debugPrint('Order $localOrderId was synced with older system. Updating with new sync_id.');
      try {
        await db.update(
          'orders',
          {'sync_id': syncId},
          where: 'id = ?',
          whereArgs: [localOrderId],
        );
      } catch (e) {
        debugPrint('Error updating sync_id for previously synced order: $e');
      }
      return;
    }
    
    // Add a transaction to ensure atomicity
    await db.transaction((txn) async {
      // First check again within the transaction to ensure another thread hasn't synced it
      final checkResult = await txn.query(
        'orders',
        columns: ['is_synced'],
        where: 'id = ?',
        whereArgs: [localOrderId]
      );
      
      if (checkResult.isNotEmpty && checkResult.first['is_synced'] == 1) {
        debugPrint('Order $localOrderId marked as synced during transaction check. Skipping.');
        return;
      }
      
      // Not synced yet, proceed with update
      try {
        await txn.update(
          'orders',
          {
            'is_synced': 1,
            'server_id': serverOrderId,
            'last_sync_attempt': DateTime.now().toIso8601String(),
            'sync_id': syncId,
          },
          where: 'id = ?',
          whereArgs: [localOrderId],
        );
        
        debugPrint('Order $localOrderId marked as synced. Server ID: $serverOrderId, Sync ID: $syncId');
      } catch (e) {
        // If the columns don't exist, try a simpler update
        debugPrint('Falling back to simple update without new columns: $e');
        await txn.update(
          'orders',
          {
            'is_synced': 1,
            'server_id': serverOrderId,
          },
          where: 'id = ?',
          whereArgs: [localOrderId],
        );
        
        debugPrint('Order $localOrderId marked as synced with simple update. Server ID: $serverOrderId');
      }
    });
  } catch (e) {
    debugPrint('Error marking order as synced: $e');
    
    // Try a simplified version if the transaction fails
    try {
      final db = await database;
      await db.update(
        'orders',
        {'is_synced': 1, 'server_id': serverOrderId},
        where: 'id = ?',
        whereArgs: [localOrderId],
      );
      debugPrint('Order $localOrderId marked as synced with fallback method. Server ID: $serverOrderId');
    } catch (fallbackError) {
      debugPrint('Fallback error marking order as synced: $fallbackError');
    }
  }
}


  // Record sync error with fallback
  Future<void> recordSyncError(int localOrderId, String error) async {
    try {
      final db = await database;
      try {
        await db.update(
          'orders',
          {
            'last_sync_attempt': DateTime.now().toIso8601String(),
            'sync_error': error,
          },
          where: 'id = ?',
          whereArgs: [localOrderId],
        );
      } catch (e) {
        // If the columns don't exist, we'll just log the error
        debugPrint('Cannot record sync error due to missing columns: $e');
      }
      
      debugPrint('Recorded sync error for order $localOrderId: $error');
    } catch (e) {
      debugPrint('Error recording sync error: $e');
    }
  }

  // Save order to local database
  // Enhanced saveOrder method in lib/repositories/local_order_repository.dart
Future<Order> saveOrder(Order order) async {
  try {
    final db = await database;
    // Generate a timestamp for local orders that is clearly a local timestamp
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final localTimestamp = 'local_${timestamp}';
    
    // Determine if this is an update or new order
    final bool isUpdate = order.id != null;
    debugPrint(isUpdate ? 'Updating existing order #${order.id}' : 'Creating new order');
    
    final orderMap = {
      'service_type': order.serviceType,
      'subtotal': order.subtotal,
      'tax': order.tax,
      'discount': order.discount,
      'total': order.total,
      'status': order.status,
      'created_at': order.createdAt ?? localTimestamp,
      'payment_method': order.paymentMethod ?? 'cash',
      'customer_id': order.customerId,
      'is_synced': 0,
    };
    
    int orderId;
    
    // If it's an existing order with an ID, update rather than insert
    if (isUpdate) {
      // Check if the order exists
      final existingOrder = await db.query(
        'orders',
        where: 'id = ?',
        whereArgs: [order.id],
      );
      
      if (existingOrder.isNotEmpty) {
        // Update existing order
        await db.update(
          'orders',
          orderMap,
          where: 'id = ?',
          whereArgs: [order.id],
        );
        
        // Delete existing items for this order
        await db.delete(
          'order_items',
          where: 'order_id = ?',
          whereArgs: [order.id],
        );
        
        orderId = order.id!;
        debugPrint('Updated existing order in local database: ID=$orderId');
      } else {
        // If the order doesn't exist, insert it with the specified ID
        orderMap['id'] = order.id;
        orderId = await db.insert('orders', orderMap);
        debugPrint('Inserted order with specified ID: $orderId');
      }
    } else {
      // Insert as a new order
      orderId = await db.insert('orders', orderMap);
      debugPrint('Inserted new order: ID=$orderId');
    }
    
    // Now insert the order items
    for (var item in order.items) {
      await db.insert('order_items', {
        'order_id': orderId,
        'menu_item_id': item.id,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'kitchen_note': item.kitchenNote,
      });
    }
    
    // Return the order with the updated ID
    return Order(
      id: orderId,
      serviceType: order.serviceType,
      items: order.items,
      subtotal: order.subtotal,
      tax: order.tax,
      discount: order.discount,
      total: order.total,
      status: order.status,
      createdAt: order.createdAt ?? localTimestamp,
      customerId: order.customerId,
      paymentMethod: order.paymentMethod,
    );
  } catch (e) {
    debugPrint('Error saving order to local database: $e');
    rethrow;
  }
}


  // Get all unsynced orders
    Future<List<Order>> getUnsyncedOrders() async {
    try {
      final db = await database;
      
      // Check if sync_id column exists
      bool hasSyncIdColumn = false;
      try {
        final tableInfo = await db.rawQuery("PRAGMA table_info(orders)");
        hasSyncIdColumn = tableInfo.any((col) => col['name'] == 'sync_id');
        debugPrint('Table has sync_id column: $hasSyncIdColumn');
      } catch (e) {
        debugPrint('Error checking table structure: $e');
      }
      
      // Query for unsynced orders with additional check for sync_id if it exists
      final orders = await db.query(
        'orders',
        where: 'is_synced = ?',
        whereArgs: [0],
        orderBy: 'created_at ASC', // Sync oldest first
      );
      
      // Check for duplicates by tracking IDs
      final processedIds = <int>{};
      final uniqueOrders = <Map<String, dynamic>>[];
      
      for (var order in orders) {
        final orderId = order['id'] as int;
        if (!processedIds.contains(orderId)) {
          processedIds.add(orderId);
          uniqueOrders.add(order);
        } else {
          debugPrint('Skipping duplicate order ID: $orderId');
        }
      }
      
      debugPrint('Found ${uniqueOrders.length} unique unsynced orders');
      
      return await Future.wait(uniqueOrders.map((orderMap) async {
        final orderId = orderMap['id'] as int;
        final items = await db.query(
          'order_items',
          where: 'order_id = ?',
          whereArgs: [orderId],
        );
        
        final orderItems = items.map((item) => OrderItem(
          id: item['menu_item_id'] as int,
          name: item['name'] as String,
          price: (item['price'] as num).toDouble(),
          quantity: item['quantity'] as int,
          kitchenNote: item['kitchen_note'] as String? ?? '',
        )).toList();
        
        return Order(
          id: orderId,
          serviceType: orderMap['service_type'] as String,
          items: orderItems,
          subtotal: (orderMap['subtotal'] as num).toDouble(),
          tax: (orderMap['tax'] as num).toDouble(),
          discount: (orderMap['discount'] as num).toDouble(),
          total: (orderMap['total'] as num).toDouble(),
          status: orderMap['status'] as String,
          createdAt: orderMap['created_at'] as String?,
          customerId: orderMap['customer_id'] as String?,
          paymentMethod: orderMap['payment_method'] as String?,
        );
      }).toList());
    } catch (e) {
      debugPrint('Error getting unsynced orders: $e');
      return [];
    }
  }
 
  // Get all local orders with better deduplication logic
Future<List<Order>> getAllOrders() async {
  try {
    final db = await database;
    
    // Get all orders
    final orders = await db.query(
      'orders',
      orderBy: 'created_at DESC'
    );
    
    debugPrint('Retrieved ${orders.length} orders from local database');
    
    // Keep track of server_ids to avoid duplicates
    final processedServerIds = <int?>{};
    final result = <Order>[];
    
    for (var orderMap in orders) {
      final orderId = orderMap['id'] as int;
      final serverId = orderMap['server_id'] as int?;
      
      // Skip if we already have an order with this server_id
      if (serverId != null && processedServerIds.contains(serverId)) {
        debugPrint('Skipping duplicate order with server ID: $serverId');
        continue;
      }
      
      // Add server_id to processed set if it exists
      if (serverId != null) {
        processedServerIds.add(serverId);
      }
      
      // Get order items
      final items = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      
      if (items.isEmpty) {
        debugPrint('Warning: Order #$orderId has no items');
      }
      
      final orderItems = items.map((item) => OrderItem(
        id: item['menu_item_id'] as int,
        name: item['name'] as String,
        price: (item['price'] as num).toDouble(),
        quantity: item['quantity'] as int,
        kitchenNote: item['kitchen_note'] as String? ?? '',
      )).toList();
      
      // Extract and verify important fields for debugging
      final serviceType = orderMap['service_type'] as String? ?? '';
      final status = orderMap['status'] as String? ?? 'pending';
      final createdAt = orderMap['created_at'] as String?;
      
      // Add to result list
      result.add(Order(
        id: orderId,
        serviceType: serviceType,
        items: orderItems,
        subtotal: (orderMap['subtotal'] as num? ?? 0).toDouble(),
        tax: (orderMap['tax'] as num? ?? 0).toDouble(),
        discount: (orderMap['discount'] as num? ?? 0).toDouble(),
        total: (orderMap['total'] as num? ?? 0).toDouble(),
        status: status,
        createdAt: createdAt,
        customerId: orderMap['customer_id'] as String?,
        paymentMethod: orderMap['payment_method'] as String? ?? 'cash',
      ));
      
      // Log the order for debugging
      debugPrint('Local order: ID=$orderId, Type=$serviceType, Status=$status, Items=${orderItems.length}');
    }
    
    return result;
  } catch (e) {
    debugPrint('Error getting all orders: $e');
    return [];
  }
}
  
  // Get a specific order by ID with server ID fallback
  Future<Order?> getOrderById(int orderId) async {
    try {
      final db = await database;
      
      // First try to find by local ID
      var orders = await db.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
      );
      
      // If not found by local ID, try server ID
      if (orders.isEmpty) {
        orders = await db.query(
          'orders',
          where: 'server_id = ?',
          whereArgs: [orderId],
        );
      }
      
      if (orders.isEmpty) return null;
      
      final orderMap = orders.first;
      final items = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderMap['id']],
      );
      
      final orderItems = items.map((item) => OrderItem(
        id: item['menu_item_id'] as int,
        name: item['name'] as String,
        price: (item['price'] as num).toDouble(),
        quantity: item['quantity'] as int,
        kitchenNote: item['kitchen_note'] as String? ?? '',
      )).toList();
      
      return Order(
        id: orderMap['id'] as int,
        serviceType: orderMap['service_type'] as String,
        items: orderItems,
        subtotal: (orderMap['subtotal'] as num).toDouble(),
        tax: (orderMap['tax'] as num).toDouble(),
        discount: (orderMap['discount'] as num).toDouble(),
        total: (orderMap['total'] as num).toDouble(),
        status: orderMap['status'] as String,
        createdAt: orderMap['created_at'] as String?,
        customerId: orderMap['customer_id'] as String?,
        paymentMethod: orderMap['payment_method'] as String?,
      );
    } catch (e) {
      debugPrint('Error getting order by ID: $e');
      return null;
    }
  }
  
  // Update an order's status
  Future<bool> updateOrderStatus(int orderId, String status) async {
    try {
      final db = await database;
      await db.update(
        'orders',
        {'status': status},
        where: 'id = ?',
        whereArgs: [orderId],
      );
      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }
  
  // Delete all synced orders older than a certain date
  Future<int> cleanupSyncedOrders(DateTime olderThan) async {
    try {
      final db = await database;
      final result = await db.delete(
        'orders',
        where: 'is_synced = 1 AND created_at < ?',
        whereArgs: [olderThan.toIso8601String()],
      );
      return result;
    } catch (e) {
      debugPrint('Error cleaning up synced orders: $e');
      return 0;
    }
  }
  
  // Get the count of unsynced orders
  Future<int> getUnsyncedOrderCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) FROM orders WHERE is_synced = 0');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('Error getting unsynced order count: $e');
      return 0;
    }
  }
  
  // Check if an order exists by server ID
  Future<bool> orderExistsByServerId(int serverId) async {
    try {
      final db = await database;
      final result = await db.query(
        'orders',
        where: 'server_id = ?',
        whereArgs: [serverId],
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if order exists by server ID: $e');
      return false;
    }
  }
Future<Order> saveOrderAsSynced(Order order, int? serverOrderId) async {
  try {
    final db = await database;
    // Generate a timestamp for local orders that is clearly a local timestamp
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final localTimestamp = 'local_${timestamp}';
    final syncId = 'server_sync_${timestamp}';
    
    // Determine if this is an update or new order
    final bool isUpdate = order.id != null;
    debugPrint(isUpdate 
      ? 'Updating existing order #${order.id} as synced with server ID $serverOrderId' 
      : 'Creating new synced order with server ID $serverOrderId');
    
    final orderMap = {
      'service_type': order.serviceType,
      'subtotal': order.subtotal,
      'tax': order.tax,
      'discount': order.discount,
      'total': order.total,
      'status': order.status,
      'created_at': order.createdAt ?? localTimestamp,
      'payment_method': order.paymentMethod ?? 'cash',
      'customer_id': order.customerId,
      // Mark as synced immediately
      'is_synced': 1,
      'server_id': serverOrderId,
      'last_sync_attempt': now.toIso8601String(),
      'sync_id': syncId,
    };
    
    int orderId;
    
    // If it's an existing order with an ID, update rather than insert
    if (isUpdate) {
      // Check if the order exists
      final existingOrder = await db.query(
        'orders',
        where: 'id = ?',
        whereArgs: [order.id],
      );
      
      if (existingOrder.isNotEmpty) {
        // Update existing order
        await db.update(
          'orders',
          orderMap,
          where: 'id = ?',
          whereArgs: [order.id],
        );
        
        // Delete existing items for this order
        await db.delete(
          'order_items',
          where: 'order_id = ?',
          whereArgs: [order.id],
        );
        
        orderId = order.id!;
        debugPrint('Updated existing order in local database as synced: ID=$orderId, ServerID=$serverOrderId');
      } else {
        // If the order doesn't exist, insert it with the specified ID
        orderMap['id'] = order.id;
        orderId = await db.insert('orders', orderMap);
        debugPrint('Inserted synced order with specified ID: $orderId, ServerID=$serverOrderId');
      }
    } else {
      // Insert as a new order - use the server ID if provided
      if (serverOrderId != null) {
        orderMap['id'] = serverOrderId;
        orderId = await db.insert('orders', orderMap);
        debugPrint('Inserted new synced order using server ID: $orderId');
      } else {
        // No server ID, let SQLite generate one
        orderId = await db.insert('orders', orderMap);
        debugPrint('Inserted new synced order with generated ID: $orderId');
      }
    }
    
    // Now insert the order items
    for (var item in order.items) {
      await db.insert('order_items', {
        'order_id': orderId,
        'menu_item_id': item.id,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'kitchen_note': item.kitchenNote,
      });
    }
    
    // Return the order with the updated ID
    return Order(
      id: orderId,
      serviceType: order.serviceType,
      items: order.items,
      subtotal: order.subtotal,
      tax: order.tax,
      discount: order.discount,
      total: order.total,
      status: order.status,
      createdAt: order.createdAt ?? localTimestamp,
      customerId: order.customerId,
      paymentMethod: order.paymentMethod,
    );
  } catch (e) {
    debugPrint('Error saving synced order to local database: $e');
    rethrow;
  }
}
  
}