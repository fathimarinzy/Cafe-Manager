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
        columns: ['is_synced', 'server_id'],
        where: 'id = ?',
        whereArgs: [localOrderId]
      );
      
      if (existing.isNotEmpty && existing.first['is_synced'] == 1) {
        debugPrint('Order $localOrderId already marked as synced. Skipping.');
        return;
      }
      
      try {
        await db.update(
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
      } catch (e) {
        // If the columns don't exist, try a simpler update
        debugPrint('Falling back to simple update without new columns: $e');
        await db.update(
          'orders',
          {
            'is_synced': 1,
            'server_id': serverOrderId,
          },
          where: 'id = ?',
          whereArgs: [localOrderId],
        );
      }
      
      debugPrint('Order $localOrderId marked as synced. Server ID: $serverOrderId');
    } catch (e) {
      debugPrint('Error marking order as synced: $e');
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
  Future<Order> saveOrder(Order order) async {
    try {
      final db = await database;
        // Generate a timestamp for local orders that is clearly a local timestamp
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final localTimestamp = 'local_${timestamp}';
      
      final orderMap = {
        'service_type': order.serviceType,
        'subtotal': order.subtotal,
        'tax': order.tax,
        'discount': order.discount,
        'total': order.total,
        'status': order.status,
        'created_at':order.createdAt ?? localTimestamp,
        'payment_method': order.paymentMethod ?? 'cash',
        'customer_id': order.customerId,
        'is_synced': 0,
      };
      
      // If it's an existing order with an ID, update rather than insert
      if (order.id != null) {
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
          
          debugPrint('Updated existing local order with ID: ${order.id}');
        } else {
          // Insert as new order with the provided ID
          orderMap['id'] = order.id;
          await db.insert('orders', orderMap);
          debugPrint('Inserted new local order with specified ID: ${order.id}');
        }
      } else {
        // Insert new order
        final orderId = await db.insert('orders', orderMap);
        order = Order(
          id: orderId,
          serviceType: order.serviceType,
          items: order.items,
          subtotal: order.subtotal,
          tax: order.tax,
          discount: order.discount,
          total: order.total,
          status: order.status,
          createdAt: localTimestamp,
          customerId: order.customerId,
          paymentMethod: order.paymentMethod,
        );
        debugPrint('New order saved locally with ID: ${order.id}');
      }
      
      // Save order items
      for (var item in order.items) {
        await db.insert('order_items', {
          'order_id': order.id!,
          'menu_item_id': item.id,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          // 'kitchen_note': item.kitchenNote ?? '',
        });
      }
      
      return order;
    } catch (e) {
      debugPrint('Error saving order locally: $e');
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
      final orders = await db.query('orders', orderBy: 'created_at DESC');
      
      // Keep track of server_ids to avoid duplicates
      final processedServerIds = <int>{};
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
        
        result.add(Order(
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
        ));
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
  
}