import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import 'package:flutter/foundation.dart';
import '../repositories/local_expense_repository.dart';
import '../repositories/local_menu_repository.dart';
import '../repositories/local_person_repository.dart';
import '../utils/database_helper.dart';

class LocalOrderRepository {
  static Database? _database;

  static Future<Database>? _dbOpenFuture;

  // Get database instance safely (avoid race conditions)
  Future<Database> get database async {
    if (_database != null) return _database!;
    
    // If initialization is already in progress, return that future
    if (_dbOpenFuture != null) return _dbOpenFuture!;
    
    // Otherwise start initialization
    _dbOpenFuture = _initDatabase();
    
    try {
      _database = await _dbOpenFuture;
      return _database!;
    } catch (e) {
      _dbOpenFuture = null; // Reset on failure so we can try again
      rethrow;
    }
  }

  // Initialize database with simplified schema
  Future<Database> _initDatabase() async {
    final path = await DatabaseHelper.getDatabasePath('cafe_orders.db');
    
    return await openDatabase(
      path,
      version: 12, // Increment version to trigger repair
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL;');
      },
      onCreate: (db, version) async {
        // Create orders table with simplified fields
        await db.execute('''
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            staff_order_number INTEGER,
            main_order_number INTEGER,
            staff_device_id TEXT NOT NULL,
            service_type TEXT NOT NULL,
            subtotal REAL NOT NULL,
            tax REAL NOT NULL,
            discount REAL NOT NULL,
            total REAL NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            payment_method TEXT DEFAULT 'cash',
            customer_id TEXT,
            cash_amount REAL,
            bank_amount REAL,
            is_synced INTEGER NOT NULL DEFAULT 0,
            synced_at TEXT,
            main_number_assigned INTEGER NOT NULL DEFAULT 0,
            delivery_charge REAL,
            delivery_address TEXT,
            delivery_boy TEXT,
            event_date TEXT,
            event_time TEXT,
            event_guest_count INTEGER,
            event_type TEXT,
            deposit_amount REAL,
            token_number TEXT,
            customer_name TEXT
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
            tax_exempt INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
          )
        ''');

        // Create indices for faster lookups
        await db.execute('CREATE INDEX idx_order_items_order_id ON order_items (order_id)');
        await db.execute('CREATE INDEX idx_orders_staff_device ON orders (staff_device_id)');
        await db.execute('CREATE INDEX idx_orders_main_number ON orders (main_order_number)');
        await db.execute('CREATE INDEX idx_orders_deposit_amount ON orders (deposit_amount)');
        await db.execute('CREATE INDEX idx_orders_event_date ON orders (event_date)');
        await db.execute('CREATE INDEX idx_orders_created_at ON orders (created_at)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('Upgrading orders database from version $oldVersion to $newVersion');
        
        if (oldVersion < 4) {
          // Add new columns for dual numbering
          try {
            await db.execute('ALTER TABLE orders ADD COLUMN staff_order_number INTEGER');
            await db.execute('ALTER TABLE orders ADD COLUMN main_order_number INTEGER');
            await db.execute('ALTER TABLE orders ADD COLUMN staff_device_id TEXT DEFAULT ""');
            await db.execute('ALTER TABLE orders ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0');
            await db.execute('ALTER TABLE orders ADD COLUMN synced_at TEXT');
            await db.execute('ALTER TABLE orders ADD COLUMN main_number_assigned INTEGER NOT NULL DEFAULT 0');
            
            // Create indices
            await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_staff_device ON orders (staff_device_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_main_number ON orders (main_order_number)');
            
            debugPrint('Added dual numbering columns and indexes');
          } catch (e) {
            debugPrint('Error adding dual numbering columns: $e');
          }
        }
        
        if (oldVersion < 5) {
          // Add delivery columns
          try {
             await db.execute('ALTER TABLE orders ADD COLUMN delivery_charge REAL');
             await db.execute('ALTER TABLE orders ADD COLUMN delivery_address TEXT');
             await db.execute('ALTER TABLE orders ADD COLUMN delivery_boy TEXT');
             debugPrint('Added delivery columns to orders table');
          } catch (e) {
            debugPrint('Error adding delivery columns: $e');
          }
        }
        
        if (oldVersion < 7) {
          // Add deposit_amount column
          try {
             await db.execute('ALTER TABLE orders ADD COLUMN deposit_amount REAL');
             debugPrint('Added deposit_amount column to orders table');
          } catch (e) {
            debugPrint('Error adding deposit_amount column: $e');
          }
        }

        if (oldVersion < 8) {
          // Add catering columns
          try {
             await db.execute('ALTER TABLE orders ADD COLUMN event_date TEXT');
             await db.execute('ALTER TABLE orders ADD COLUMN event_time TEXT');
             await db.execute('ALTER TABLE orders ADD COLUMN event_guest_count INTEGER');
             await db.execute('ALTER TABLE orders ADD COLUMN event_type TEXT');
             debugPrint('Added catering columns to orders table');
          } catch (e) {
            debugPrint('Error adding catering columns: $e');
          }
        }

        if (oldVersion < 9) {
          // Add catering token and customer name columns
          try {
             await db.execute('ALTER TABLE orders ADD COLUMN token_number TEXT');
             await db.execute('ALTER TABLE orders ADD COLUMN customer_name TEXT');
             debugPrint('Added token_number and customer_name columns to orders table');
          } catch (e) {
            debugPrint('Error adding catering token/customer columns: $e');
          }
        }

        if (oldVersion < 10) {
           // Add indexes for optimization
           try {
             await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_deposit_amount ON orders (deposit_amount)');
             await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_event_date ON orders (event_date)');
             await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders (created_at)');
             debugPrint('Added optimization indexes');
           } catch (e) {
             debugPrint('Error adding optimization indexes: $e');
           }
        }

        if (oldVersion < 11) {
          // Add tax_exempt column to order_items
          try {
            await db.execute('ALTER TABLE order_items ADD COLUMN tax_exempt INTEGER NOT NULL DEFAULT 0');
            debugPrint('Added tax_exempt column to order_items table');
          } catch (e) {
            debugPrint('Error adding tax_exempt column: $e');
          }
        }
        
        if (oldVersion < 12) {
          // REPAIR: Ensure token_number and customer_name exist even if skipped previously
          try {
             await db.execute('ALTER TABLE orders ADD COLUMN token_number TEXT');
             debugPrint('Repaired: Added token_number to orders table');
          } catch (e) {
            // Ignore error if column exists
          }
          try {
             await db.execute('ALTER TABLE orders ADD COLUMN customer_name TEXT');
             debugPrint('Repaired: Added customer_name to orders table');
          } catch (e) {
            // Ignore error if column exists
          }
        }
      },
    );
  }
   // Get the next staff order number for this device
  Future<int> _getNextStaffOrderNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final currentNumber = prefs.getInt('staff_order_counter') ?? 0;
    final nextNumber = currentNumber + 1;
    await prefs.setInt('staff_order_counter', nextNumber);
    return nextNumber;
  }
  // Save order to local database
  Future<Order> saveOrder(Order order) async {
    try {
      final db = await database;
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? '';
      
      // Determine if this is an update or new order
      final bool isUpdate = order.id != null;
      debugPrint(isUpdate ? 'Updating existing order #${order.id}' : 'Creating new order');
      
      return await db.transaction((txn) async {
        // FIXED: Always use current local time for new orders, preserve existing for updates
        String timestampToUse;
        int? staffOrderNum = order.staffOrderNumber;

        if (isUpdate && order.createdAt != null) {
          // For updates, preserve the original timestamp
          timestampToUse = order.createdAt!;
        } else {
          // For new orders, use current local time in ISO format
          timestampToUse = DateTime.now().toIso8601String();
          // Assign staff order number only for new orders
          staffOrderNum ??= await _getNextStaffOrderNumber();
        }
        
        int orderId;

        // If it's an existing order with an ID, update rather than insert
        if (isUpdate) {
          // Check if the order exists and get its original creation timestamp
          final existingOrder = await txn.query(
            'orders',
            columns: ['id', 'created_at','staff_order_number'],
            where: 'id = ?',
            whereArgs: [order.id],
          );
          
          if (existingOrder.isNotEmpty) {
            // Use the original creation timestamp when updating
            // final createdAtTimestamp = existingOrder.first['created_at'] as String? ?? localTimestamp;
            
            // Update existing order WITHOUT changing the created_at field
            final orderMap = {
              'staff_device_id': order.staffDeviceId.isNotEmpty ? order.staffDeviceId : deviceId,
              'service_type': order.serviceType,
              'subtotal': order.subtotal,
              'tax': order.tax,
              'discount': order.discount,
              'total': order.total,
              'status': order.status,
              'payment_method': order.paymentMethod ?? 'cash',
              'customer_id': order.customerId,
              'cash_amount': order.cashAmount,
              'bank_amount': order.bankAmount,
              'staff_order_number': existingOrder.first['staff_order_number'] as int?,
              'main_order_number': order.mainOrderNumber,
              'is_synced': order.isSynced ? 1 : 0,
              'synced_at': order.syncedAt,
              'main_number_assigned': order.mainNumberAssigned ? 1 : 0,
              'delivery_charge': order.deliveryCharge,
              'delivery_address': order.deliveryAddress,
              'delivery_boy': order.deliveryBoy,
              'event_date': order.eventDate,
              'event_time': order.eventTime,
              'event_guest_count': order.eventGuestCount,
              'event_type': order.eventType,
              'token_number': order.tokenNumber,
              'customer_name': order.customerName,
              'deposit_amount': order.depositAmount,
            };
            
            await txn.update(
              'orders',
              orderMap,
              where: 'id = ?',
              whereArgs: [order.id],
            );
            
            // Delete existing items for this order
            await txn.delete(
              'order_items',
              where: 'order_id = ?',
              whereArgs: [order.id],
            );
            
            orderId = order.id!;
            staffOrderNum = existingOrder.first['staff_order_number'] as int?;
            // Use the original timestamp for updates
            timestampToUse = existingOrder.first['created_at'] as String;
            debugPrint('Updated existing order: ID=$orderId, StaffNum=$staffOrderNum');
          } else {
           
            final orderMap = {
              'id': order.id,
              'staff_order_number': staffOrderNum,
              'main_order_number': order.mainOrderNumber,
              'staff_device_id': order.staffDeviceId.isNotEmpty ? order.staffDeviceId : deviceId,
              'service_type': order.serviceType,
              'subtotal': order.subtotal,
              'tax': order.tax,
              'discount': order.discount,
              'total': order.total,
              'status': order.status,
              'created_at': timestampToUse,
              'payment_method': order.paymentMethod ?? 'cash',
              'customer_id': order.customerId,
              'cash_amount': order.cashAmount,
              'bank_amount': order.bankAmount,
              'is_synced': order.isSynced ? 1 : 0,
              'synced_at': order.syncedAt,
              'main_number_assigned': order.mainNumberAssigned ? 1 : 0,
              'delivery_charge': order.deliveryCharge,
              'delivery_address': order.deliveryAddress,
              'delivery_boy': order.deliveryBoy,
              'event_date': order.eventDate,
              'event_time': order.eventTime,
              'event_guest_count': order.eventGuestCount,
              'event_type': order.eventType,
              'token_number': order.tokenNumber,
              'customer_name': order.customerName,
              'deposit_amount': order.depositAmount,
            };
            
            orderId = await txn.insert('orders', orderMap);
            debugPrint('Inserted order with specified ID: $orderId, timestamp: $timestampToUse, StaffNum: $staffOrderNum');
          }
        } else {
          // Insert new order
          final orderMap = {
            'staff_order_number': staffOrderNum,
            'main_order_number': order.mainOrderNumber,
            'staff_device_id': order.staffDeviceId.isNotEmpty ? order.staffDeviceId : deviceId,
            'service_type': order.serviceType,
            'subtotal': order.subtotal,
            'tax': order.tax,
            'discount': order.discount,
            'total': order.total,
            'status': order.status,
            'created_at': timestampToUse,
            'payment_method': order.paymentMethod ?? 'cash',
            'customer_id': order.customerId,
            'cash_amount': order.cashAmount,
            'bank_amount': order.bankAmount,
            'is_synced': order.isSynced ? 1 : 0,
            'synced_at': order.syncedAt,
            'main_number_assigned': order.mainNumberAssigned ? 1 : 0,
            'delivery_charge': order.deliveryCharge,
            'delivery_address': order.deliveryAddress,
            'delivery_boy': order.deliveryBoy,
            'event_date': order.eventDate,
            'event_time': order.eventTime,
            'event_guest_count': order.eventGuestCount,
            'event_type': order.eventType,
            'token_number': order.tokenNumber,
            'customer_name': order.customerName,
            'deposit_amount': order.depositAmount,
          };
          
          orderId = await txn.insert('orders', orderMap);
          debugPrint('Inserted new order: ID=$orderId, timestamp: $timestampToUse, StaffNum: $staffOrderNum');
          debugPrint('DB Insert Payload: Addr=${orderMap['delivery_address']}, Charge=${orderMap['delivery_charge']}');
        }
        
        // Now insert the order items
        for (var item in order.items) {
          await txn.insert('order_items', {
            'order_id': orderId,
            'menu_item_id': item.id,
            'name': item.name,
            'price': item.price,
            'quantity': item.quantity,
            'kitchen_note': item.kitchenNote,
            'tax_exempt': item.taxExempt ? 1 : 0, // NEW
          });
        }
        
        // Return the order with the updated ID and preserved timestamp
        return Order(
          id: orderId,
          staffOrderNumber: staffOrderNum,
          mainOrderNumber: order.mainOrderNumber,
          staffDeviceId: order.staffDeviceId.isNotEmpty ? order.staffDeviceId : deviceId,
          serviceType: order.serviceType,
          items: order.items,
          subtotal: order.subtotal,
          tax: order.tax,
          discount: order.discount,
          total: order.total,
          status: order.status,
          createdAt: timestampToUse,
          customerId: order.customerId,
          paymentMethod: order.paymentMethod,
          cashAmount: order.cashAmount,
          bankAmount: order.bankAmount,
          isSynced: order.isSynced,
          syncedAt: order.syncedAt,
          mainNumberAssigned: order.mainNumberAssigned,
          deliveryCharge: order.deliveryCharge,
          deliveryAddress: order.deliveryAddress,
          deliveryBoy: order.deliveryBoy,
          eventDate: order.eventDate,
          eventTime: order.eventTime,
          eventGuestCount: order.eventGuestCount,
          eventType: order.eventType,
          tokenNumber: order.tokenNumber,
          customerName: order.customerName,
          depositAmount: order.depositAmount,
        );
      });
    } catch (e) {
      debugPrint('Error saving order to local database: $e');
      rethrow;
    }
  }

  // Optimized: Get only Advanced Orders (with deposit)
  Future<List<Order>> getAdvancedOrders() async {
    try {
      final db = await database;
      
      // Fetch only orders with deposit > 0, ordered by event date
      final orders = await db.query(
        'orders',
        where: 'deposit_amount > 0',
        orderBy: 'event_date ASC, created_at DESC' 
      );
      
      return await _mapOrdersWithItems(db, orders);
    } catch (e) {
      debugPrint('Error getting advanced orders: $e');
      return [];
    }
  }

  // Optimized: Get Orders for a specific date range
  Future<List<Order>> getOrdersByDateRange(DateTime start, DateTime end) async {
    try {
      final db = await database;
      
      final startStr = start.toIso8601String();
      final endStr = end.toIso8601String();
      
      // Fetch orders within range
      final orders = await db.query(
        'orders',
        where: 'created_at >= ? AND created_at <= ?',
        whereArgs: [startStr, endStr],
        orderBy: 'created_at DESC'
      );
      
      return await _mapOrdersWithItems(db, orders);
    } catch (e) {
      debugPrint('Error getting orders by date range: $e');
      return [];
    }
  }

  // Helper to map DB rows to Order objects with items
  Future<List<Order>> _mapOrdersWithItems(Database db, List<Map<String, Object?>> orders) async {
    final result = <Order>[];
      
    for (var orderMap in orders) {
      final orderId = orderMap['id'] as int;
      
      // Get order items
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
        taxExempt: (item['tax_exempt'] as int?) == 1,
      )).toList();
      
      // Extract and verify fields
      final serviceType = orderMap['service_type'] as String? ?? '';
      final status = orderMap['status'] as String? ?? 'pending';
      final createdAt = orderMap['created_at'] as String?;

      final cashAmount = orderMap['cash_amount'] != null 
          ? (orderMap['cash_amount'] as num).toDouble() 
          : null;
      final bankAmount = orderMap['bank_amount'] != null 
          ? (orderMap['bank_amount'] as num).toDouble() 
          : null;
      
      result.add(Order(
        id: orderId,
        staffOrderNumber: orderMap['staff_order_number'] as int?,
        mainOrderNumber: orderMap['main_order_number'] as int?,
        staffDeviceId: orderMap['staff_device_id'] as String? ?? '',
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
        cashAmount: cashAmount,
        bankAmount: bankAmount,
        isSynced: (orderMap['is_synced'] as int?) == 1,
        syncedAt: orderMap['synced_at'] as String?,
        mainNumberAssigned: (orderMap['main_number_assigned'] as int?) == 1,
        deliveryCharge: orderMap['delivery_charge'] as double?,
        deliveryAddress: orderMap['delivery_address'] as String?,
        deliveryBoy: orderMap['delivery_boy'] as String?,
        eventDate: orderMap['event_date'] as String?,
        eventTime: orderMap['event_time'] as String?,
        eventGuestCount: orderMap['event_guest_count'] as int?,
        eventType: orderMap['event_type'] as String?,
        tokenNumber: orderMap['token_number'] as String?,
        customerName: orderMap['customer_name'] as String?,
        depositAmount: orderMap['deposit_amount'] != null ? (orderMap['deposit_amount'] as num).toDouble() : null,
      ));
    }
    return result;
  }
  
  // Get all local orders (delegates to common mapper for consistency)
  Future<List<Order>> getAllOrders() async {
    try {
      final db = await database;
      
      // Get all orders
      final orders = await db.query(
        'orders',
        orderBy: 'created_at DESC'
      );
      
      // debugPrint('Retrieved ${orders.length} orders from local database');
      
      return await _mapOrdersWithItems(db, orders);
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
        taxExempt: (item['tax_exempt'] as int?) == 1, // NEW
      )).toList();
      
       // ✅ NEW: Read cash_amount and bank_amount
      final cashAmount = orderMap['cash_amount'] != null 
          ? (orderMap['cash_amount'] as num).toDouble() 
          : null;
      final bankAmount = orderMap['bank_amount'] != null 
          ? (orderMap['bank_amount'] as num).toDouble() 
          : null;
      return Order(
        id: orderMap['id'] as int,
        staffOrderNumber: orderMap['staff_order_number'] as int?,
        mainOrderNumber: orderMap['main_order_number'] as int?,
        staffDeviceId: orderMap['staff_device_id'] as String? ?? '',
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
        cashAmount: cashAmount,
        bankAmount: bankAmount,
        isSynced: (orderMap['is_synced'] as int?) == 1,
        syncedAt: orderMap['synced_at'] as String?,
        mainNumberAssigned: (orderMap['main_number_assigned'] as int?) == 1,
        deliveryBoy: orderMap['delivery_boy'] as String?,
        deliveryCharge: orderMap['delivery_charge'] != null ? (orderMap['delivery_charge'] as num).toDouble() : null,
        deliveryAddress: orderMap['delivery_address'] as String?,
        eventDate: orderMap['event_date'] as String?,
        eventTime: orderMap['event_time'] as String?,
        eventGuestCount: orderMap['event_guest_count'] as int?,
        eventType: orderMap['event_type'] as String?,
        tokenNumber: orderMap['token_number'] as String?,
        customerName: orderMap['customer_name'] as String?,
        depositAmount: orderMap['deposit_amount'] != null ? (orderMap['deposit_amount'] as num).toDouble() : null,
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
 /// Print the contents of all database tables for debugging
Future<void> printDatabaseContents() async {
  debugPrint('\n======== DATABASE CONTENTS DUMP ========');
  
  // Print Orders database tables
  // try {
  //   final orderDb = await LocalOrderRepository().database;
    
  //   debugPrint('\n====== ORDERS TABLE ======');
  //   final orders = await orderDb.query('orders');
  //   debugPrint('Found ${orders.length} orders');
  //   for (var order in orders) {
  //     debugPrint(order.toString());
  //   }
    
  //   debugPrint('\n====== ORDER ITEMS TABLE ======');
  //   final orderItems = await orderDb.query('order_items');
  //   debugPrint('Found ${orderItems.length} order items');
  //   for (var item in orderItems) {
  //     debugPrint(item.toString());
  //   }
  // } catch (e) {
  //   debugPrint('Error printing order database: $e');
  // }
  
  // Print Menu database tables
  try {
    final menuDb = await LocalMenuRepository().database;
    
    debugPrint('\n====== MENU ITEMS TABLE ======');
    final menuItems = await menuDb.query('menu_items');
    debugPrint('Found ${menuItems.length} menu items');
    for (var item in menuItems) {
      debugPrint(item.toString());
    }
  } catch (e) {
    debugPrint('Error printing menu database: $e');
  }
  
  // Print Person database tables
  try {
    final personDb = await LocalPersonRepository().database;
    
    debugPrint('\n====== PERSONS TABLE ======');
    final persons = await personDb.query('persons');
    debugPrint('Found ${persons.length} persons');
    for (var person in persons) {
      debugPrint(person.toString());
    }
  } catch (e) {
    debugPrint('Error printing person database: $e');
  }
  
  // Print Expense database tables
  try {
    final expenseDb = await LocalExpenseRepository().database;
    
    debugPrint('\n====== EXPENSES TABLE ======');
    final expenses = await expenseDb.query('expenses');
    debugPrint('Found ${expenses.length} expenses');
    for (var expense in expenses) {
      debugPrint(expense.toString());
    }
    
    debugPrint('\n====== EXPENSE ITEMS TABLE ======');
    final expenseItems = await expenseDb.query('expense_items');
    debugPrint('Found ${expenseItems.length} expense items');
    for (var item in expenseItems) {
      debugPrint(item.toString());
    }
  } catch (e) {
    debugPrint('Error printing expense database: $e');
  }
  
  // // Print table structure information
  // try {
  //   final orderDb = await LocalOrderRepository().database;
  //   debugPrint('\n====== DATABASE STRUCTURE ======');
    
  //   // Get list of all tables
  //   final tablesList = await orderDb.rawQuery(
  //     "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
  //   );
    
  //   debugPrint('Tables in database: ${tablesList.map((t) => t['name']).join(', ')}');
    
  //   // Try to check if SQLITE_SEQUENCE exists
  //   try {
  //     final seqTable = await orderDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='sqlite_sequence'");
  //     if (seqTable.isNotEmpty) {
  //       final seqRows = await orderDb.query('sqlite_sequence');
  //       debugPrint('\n====== SQLITE_SEQUENCE TABLE ======');
  //       debugPrint('Found ${seqRows.length} rows in sequence table');
  //       for (var row in seqRows) {
  //         debugPrint(row.toString());
  //       }
  //     } else {
  //       debugPrint('SQLITE_SEQUENCE table does not exist in this database');
  //     }
  //   } catch (e) {
  //     debugPrint('Error checking SQLITE_SEQUENCE: $e');
  //   }
  // } catch (e) {
  //   debugPrint('Error checking database structure: $e');
  // }
  
  debugPrint('\n======== END DATABASE CONTENTS ========\n');
}


  // Close the database connection explicitly
  Future<void> close() async {
    try {
      if (_database != null && _database!.isOpen) {
        await _database!.close();
        _database = null;
        debugPrint('Order database closed successfully');
      }
    } catch (e) {
      debugPrint('Error closing order database: $e');
    }
  }
}