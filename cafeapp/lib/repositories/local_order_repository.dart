// lib/repositories/local_order_repository.dart
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

  // Initialize database with simplified schema
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cafe_orders.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create orders table with simplified fields
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
            customer_id TEXT
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
        await db.execute('CREATE INDEX idx_order_items_order_id ON order_items (order_id)');
      },
    );
  }

  // Save order to local database
  Future<Order> saveOrder(Order order) async {
    try {
      final db = await database;
      
      // Determine if this is an update or new order
      final bool isUpdate = order.id != null;
      debugPrint(isUpdate ? 'Updating existing order #${order.id}' : 'Creating new order');
      
      // Generate a timestamp for local orders
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;
      final localTimestamp = order.createdAt ?? 'local_${timestamp}';
      
      int orderId;

      // If it's an existing order with an ID, update rather than insert
      if (isUpdate) {
        // Check if the order exists and get its original creation timestamp
        final existingOrder = await db.query(
          'orders',
          columns: ['id', 'created_at'],
          where: 'id = ?',
          whereArgs: [order.id],
        );
        
        if (existingOrder.isNotEmpty) {
          // Use the original creation timestamp when updating
          // final createdAtTimestamp = existingOrder.first['created_at'] as String? ?? localTimestamp;
          
          // Update existing order WITHOUT changing the created_at field
          final orderMap = {
            'service_type': order.serviceType,
            'subtotal': order.subtotal,
            'tax': order.tax,
            'discount': order.discount,
            'total': order.total,
            'status': order.status,
            // Do NOT update created_at field to preserve original timestamp
            'payment_method': order.paymentMethod ?? 'cash',
            'customer_id': order.customerId,
          };
          
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
          // Use the provided createdAt or generate a new timestamp
          final createdAtTimestamp = order.createdAt ?? localTimestamp;
          
          final orderMap = {
            'id': order.id,
            'service_type': order.serviceType,
            'subtotal': order.subtotal,
            'tax': order.tax,
            'discount': order.discount,
            'total': order.total,
            'status': order.status,
            'created_at': createdAtTimestamp,
            'payment_method': order.paymentMethod ?? 'cash',
            'customer_id': order.customerId,
          };
          
          orderId = await db.insert('orders', orderMap);
          debugPrint('Inserted order with specified ID: $orderId');
        }
      } else {
        // Insert as a new order
        // For new orders, use the provided createdAt or generate a new timestamp
        final createdAtTimestamp = order.createdAt ?? localTimestamp;
        
        final orderMap = {
          'service_type': order.serviceType,
          'subtotal': order.subtotal,
          'tax': order.tax,
          'discount': order.discount,
          'total': order.total,
          'status': order.status,
          'created_at': createdAtTimestamp,
          'payment_method': order.paymentMethod ?? 'cash',
          'customer_id': order.customerId,
        };
        
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
      
      // Return the order with the updated ID and preserved timestamp
      return Order(
        id: orderId,
        serviceType: order.serviceType,
        items: order.items,
        subtotal: order.subtotal,
        tax: order.tax,
        discount: order.discount,
        total: order.total,
        status: order.status,
        createdAt: localTimestamp, // Use the preserved or new timestamp
        customerId: order.customerId,
        paymentMethod: order.paymentMethod,
      );
    } catch (e) {
      debugPrint('Error saving order to local database: $e');
      rethrow;
    }
  }

  // Get all local orders
  Future<List<Order>> getAllOrders() async {
    try {
      final db = await database;
      
      // Get all orders
      final orders = await db.query(
        'orders',
        orderBy: 'created_at DESC'
      );
      
      debugPrint('Retrieved ${orders.length} orders from local database');
      
      final result = <Order>[];
      
      for (var orderMap in orders) {
        final orderId = orderMap['id'] as int;
        
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
  
  // Get a specific order by ID
  Future<Order?> getOrderById(int orderId) async {
    try {
      final db = await database;
      
      // Find by local ID
      var orders = await db.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
      );
      
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
  
  // Delete old orders
  Future<int> cleanupOldOrders(DateTime olderThan) async {
    try {
      final db = await database;
      final result = await db.delete(
        'orders',
        where: 'created_at < ?',
        whereArgs: [olderThan.toIso8601String()],
      );
      return result;
    } catch (e) {
      debugPrint('Error cleaning up old orders: $e');
      return 0;
    }
  }
  Future<void> printDatabaseContents() async {
  final db = await database;
  
  debugPrint('====== ORDERS TABLE ======');
  final orders = await db.query('orders');
  for (var order in orders) {
    debugPrint(order.toString());
  }

  debugPrint('====== ORDER ITEMS TABLE ======');
  final items = await db.query('order_items');
  for (var item in items) {
    debugPrint(item.toString());
  }
}
}