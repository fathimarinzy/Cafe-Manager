import 'package:intl/intl.dart';
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
import '../utils/logger.dart';
import 'order_query_filters.dart';

// SQLite caps the number of bound variables in a single statement. The Windows
// ffi build allows 32,766, but Android's system SQLite is historically compiled
// with SQLITE_MAX_VARIABLE_NUMBER=999, so any query that binds one variable per
// row has to be chunked well under the lower bound. Exceeding it throws
// "too many SQL variables", which the catch blocks below would turn into an
// empty result - a blank report rather than a visible error.
const int _kSqlVarChunk = 500;

// Payment methods stored as translated UI labels instead of canonical codes.
//
// tender_screen used to write _selectedPaymentMethod straight to the database.
// That string is localised, so an Arabic till recorded 'بنك' rather than 'bank'
// and - because the same value failed an `== 'bank'` test - never added the
// paid amount to bank_amount. Only 'en' and 'ar' exist, so this mapping is
// closed. See _canonicalPaymentMethod() in tender_screen.dart for the forward
// fix.
const Map<String, String> kTranslatedPaymentMethodRepairs = {
  'نقدي': 'cash',
  'بنك': 'bank',
  'بنك + نقد': 'bank+cash',
  'ائتمان العميل': 'customer_credit',
};

/// Repairs orders written with a translated payment method (schema v18).
///
/// Deliberately conservative, because this rewrites historical financial
/// records:
///  - the method string is always normalised, since that mapping is lossless;
///  - amounts are only backfilled for a fully-paid, single-method order
///    (`status='completed'`, both amounts empty, no deposit) where `total` is
///    unambiguously the amount taken.
/// Split ('bank+cash') and deposit-bearing orders are left untouched - their
/// division between cash and bank cannot be recovered and must not be guessed.
///
/// Exposed (rather than private) so tests can run it against a seeded database.
/// [log] defaults to the persistent crash-log appender; tests pass a capturing
/// function so a test run does not append to the real log file.
Future<void> repairTranslatedPaymentMethods(
  Database db, {
  Future<void> Function(String message)? log,
}) async {
  final write = log ?? logErrorToFile;
  try {
    var methodsFixed = 0;
    var cashBackfilled = 0;
    var bankBackfilled = 0;

    for (final entry in kTranslatedPaymentMethodRepairs.entries) {
      methodsFixed += await db.update(
        'orders',
        {'payment_method': entry.value},
        where: 'payment_method = ?',
        whereArgs: [entry.key],
      );
    }

    // Only where the paid amount is unambiguous.
    const backfillWhere =
        "status = 'completed' "
        'AND COALESCE(cash_amount, 0) = 0 '
        'AND COALESCE(bank_amount, 0) = 0 '
        'AND COALESCE(deposit_amount, 0) = 0 '
        'AND COALESCE(total, 0) > 0 '
        'AND payment_method = ?';

    cashBackfilled = await db.rawUpdate(
      'UPDATE orders SET cash_amount = total WHERE $backfillWhere',
      ['cash'],
    );
    bankBackfilled = await db.rawUpdate(
      'UPDATE orders SET bank_amount = total WHERE $backfillWhere',
      ['bank'],
    );

    if (methodsFixed > 0 || cashBackfilled > 0 || bankBackfilled > 0) {
      await write(
        '🔧 v18 payment repair: normalised $methodsFixed payment_method values, '
        'backfilled cash_amount on $cashBackfilled and bank_amount on '
        '$bankBackfilled orders',
      );
    } else {
      await write('🔧 v18 payment repair: nothing to repair');
    }
  } catch (e) {
    // Never block the upgrade on a repair failure - the forward fix already
    // prevents new bad rows, and a half-open database is worse.
    await write('❌ v18 payment repair failed: $e');
  }
}

class LocalOrderRepository {
  static Database? _database;

  static Future<Database>? _dbOpenFuture;

  static bool _isResetting = false; // 🛡️ Guard flag

  // Get database instance safely (avoid race conditions)
  Future<Database> get database async {
    if (_isResetting) {
      throw StateError('Database is currently resetting - access denied');
    }
    
    if (_database != null) return _database!;
    
    // If initialization is already in progress, return that future
    if (_dbOpenFuture != null) return _dbOpenFuture!;
    
    // Otherwise start initialization
    _dbOpenFuture = _initDatabase().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _dbOpenFuture = null;
        throw Exception('Database took too long to open. Please restart the app.');
      },
    );

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
      version: 18, // v18: repair payment methods stored as translated labels
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
            customer_name TEXT,
            updated_at TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            is_temp_receipt_printed INTEGER NOT NULL DEFAULT 0
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
            purchase_price REAL NOT NULL DEFAULT 0.0,
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
        await db.execute('CREATE INDEX idx_orders_updated_at ON orders (updated_at)');
        await db.execute('CREATE INDEX idx_orders_is_synced ON orders (is_synced)');
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
        
        if (oldVersion < 13) {
          // Add purchase_price column
          try {
             await db.execute('ALTER TABLE order_items ADD COLUMN purchase_price REAL NOT NULL DEFAULT 0.0');
             debugPrint('Added purchase_price to order_items table');
          } catch (e) {
            debugPrint('Error adding purchase_price to order_items: $e');
          }
        }

        if (oldVersion < 14) {
          // Repair: Ensure purchase_price exists
          try {
             await db.execute('ALTER TABLE order_items ADD COLUMN purchase_price REAL NOT NULL DEFAULT 0.0');
             debugPrint('Repaired: Added purchase_price to order_items table');
          } catch (e) {
            // Ignore error if column exists
          }
        }

        if (oldVersion < 15) {
          // LAN Sync: Add updated_at and is_deleted columns
          try {
            await db.execute('ALTER TABLE orders ADD COLUMN updated_at TEXT');
            await db.execute('ALTER TABLE orders ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
            // Backfill updated_at from created_at for existing rows
            await db.execute('UPDATE orders SET updated_at = created_at WHERE updated_at IS NULL');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_updated_at ON orders (updated_at)');
            debugPrint('Added LAN sync columns (updated_at, is_deleted) to orders table');
          } catch (e) {
            debugPrint('Error adding LAN sync columns to orders: $e');
          }
        }

        if (oldVersion < 16) {
          try {
            await db.execute('ALTER TABLE orders ADD COLUMN is_temp_receipt_printed INTEGER NOT NULL DEFAULT 0');
            debugPrint('Added is_temp_receipt_printed column to orders table');
          } catch (e) {
            debugPrint('Error adding is_temp_receipt_printed column to orders: $e');
          }
        }

        if (oldVersion < 17) {
          // Backs getUnsyncedOrders(), which replaced a full-table scan in
          // device sync.
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_is_synced ON orders (is_synced)');
            debugPrint('Added idx_orders_is_synced index to orders table');
          } catch (e) {
            debugPrint('Error adding idx_orders_is_synced index to orders: $e');
          }
        }

        if (oldVersion < 18) {
          await repairTranslatedPaymentMethods(db);
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

  // Get the next main order number (only used by Server/Host device)
  Future<int> getNextMainOrderNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final currentNumber = prefs.getInt('main_order_counter') ?? 0;
    final nextNumber = currentNumber + 1;
    await prefs.setInt('main_order_counter', nextNumber);
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

      // Preserve the original timestamp only when updating an existing order.
      final bool preservesTimestamp = isUpdate && order.createdAt != null;

      // Allocate the staff order number BEFORE opening the transaction.
      // _getNextStaffOrderNumber() does SharedPreferences disk I/O, and awaiting
      // non-database I/O while holding the write lock stalls every other query.
      int? preAllocatedStaffNum = order.staffOrderNumber;
      if (!preservesTimestamp) {
        preAllocatedStaffNum ??= await _getNextStaffOrderNumber();
      }

      return await db.transaction((txn) async {
        // FIXED: Always use current local time for new orders, preserve existing for updates
        int? staffOrderNum = preAllocatedStaffNum;
        // Reassigned below when updating an existing row, so it can't be final.
        String timestampToUse = preservesTimestamp
            ? order.createdAt!
            : DateTime.now().toIso8601String();

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
              'updated_at': DateTime.now().toIso8601String(),
              'is_temp_receipt_printed': order.isTempReceiptPrinted ? 1 : 0,
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
              'updated_at': timestampToUse,
              'is_temp_receipt_printed': order.isTempReceiptPrinted ? 1 : 0,
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
            'updated_at': timestampToUse,
            'is_temp_receipt_printed': order.isTempReceiptPrinted ? 1 : 0,
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
            'purchase_price': item.purchasePrice,
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
          isTempReceiptPrinted: order.isTempReceiptPrinted,
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
      // Persisted, not debugPrint: a windowed release build has no console, so
      // an empty result here would otherwise reach the user with no trail.
      await logErrorToFile('❌ getAdvancedOrders failed, returning empty list: $e');
      return [];
    }
  }

  // Optimized: Get Orders for a specific date range
  // [limit] defaults to null - unbounded - so the report screen's call site
  // keeps the behaviour it relies on. The order list passes a page size, which
  // is what stops the Yearly filter materialising a whole year: measured at
  // 22,383 rows / 996ms on a seeded dataset, extrapolating to ~5s for a cafe
  // taking 300 orders a day.
  Future<List<Order>> getOrdersByDateRange(
    DateTime start,
    DateTime end, {
    int? limit,
    int offset = 0,
    OrderQueryFilters filters = OrderQueryFilters.none,
  }) async {
    try {
      return await _queryOrders(
        conditions: const ['created_at >= ? AND created_at <= ?'],
        args: [start.toIso8601String(), end.toIso8601String()],
        filters: filters,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      await logErrorToFile('❌ getOrdersByDateRange failed, returning empty list: $e');
      return [];
    }
  }

  // Runs [query] once per chunk of [ids] and concatenates the rows. Callers use
  // this for any "WHERE col IN (...)" lookup whose id list is unbounded, so the
  // number of bound variables in one statement stays under the SQLite limit.
  // See _kSqlVarChunk.
  Future<List<Map<String, Object?>>> _queryInChunks(
    List<int> ids,
    Future<List<Map<String, Object?>>> Function(List<int> chunk) query,
  ) async {
    if (ids.isEmpty) return const [];

    // Common case: small enough for a single round trip.
    if (ids.length <= _kSqlVarChunk) return query(ids);

    final results = <Map<String, Object?>>[];
    for (var i = 0; i < ids.length; i += _kSqlVarChunk) {
      final end = i + _kSqlVarChunk;
      results.addAll(await query(ids.sublist(i, end > ids.length ? ids.length : end)));
    }
    return results;
  }

  // Helper to map DB rows to Order objects with items
  Future<List<Order>> _mapOrdersWithItems(Database db, List<Map<String, Object?>> orders) async {
    if (orders.isEmpty) return [];
    
    final result = <Order>[];
    
    // Fetch order items in batched queries rather than one per order, which
    // avoids the N+1 problem. Batches are capped at _kSqlVarChunk ids so the
    // statement never exceeds SQLite's bound-variable limit.
    final orderIds = orders.map((o) => o['id'] as int).toList();

    final allItems = await _queryInChunks(
      orderIds,
      (chunk) => db.query(
        'order_items',
        where: 'order_id IN (${chunk.map((_) => '?').join(',')})',
        whereArgs: chunk,
      ),
    );

    // Group items by order_id in memory
    final itemsByOrderId = <int, List<Map<String, Object?>>>{};
    for (var item in allItems) {
      final orderId = item['order_id'] as int;
      itemsByOrderId.putIfAbsent(orderId, () => []).add(item);
    }
    
    // Now map each order with its items (no more queries!)
    for (var orderMap in orders) {
      final orderId = orderMap['id'] as int;
      
      // Get items for this order from the grouped map
      final items = itemsByOrderId[orderId] ?? [];
      
      final orderItems = items.map((item) => OrderItem(
        id: item['menu_item_id'] as int,
        name: item['name'] as String,
        price: (item['price'] as num).toDouble(),
        quantity: item['quantity'] as int,
        kitchenNote: item['kitchen_note'] as String? ?? '',
        taxExempt: (item['tax_exempt'] as int?) == 1,
        purchasePrice: item['purchase_price'] != null ? (item['purchase_price'] as num).toDouble() : 0.0,
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
        deliveryCharge: orderMap['delivery_charge'] != null ? (orderMap['delivery_charge'] as num).toDouble() : null,
        deliveryAddress: orderMap['delivery_address'] as String?,
        deliveryBoy: orderMap['delivery_boy'] as String?,
        eventDate: orderMap['event_date'] as String?,
        eventTime: orderMap['event_time'] as String?,
        eventGuestCount: orderMap['event_guest_count'] as int?,
        eventType: orderMap['event_type'] as String?,
        tokenNumber: orderMap['token_number'] as String?,
        customerName: orderMap['customer_name'] as String?,
        depositAmount: orderMap['deposit_amount'] != null ? (orderMap['deposit_amount'] as num).toDouble() : null,
        isTempReceiptPrinted: (orderMap['is_temp_receipt_printed'] as int?) == 1,
      ));
    }
    return result;
  }
  
  // Get all local orders (delegates to common mapper for consistency).
  // Used by reports, tender reconciliation and sync, which need the full
  // dataset for correctness - do NOT add a default limit here. UI list views
  // that only need a page of recent orders should use getOrdersPage() below.
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
      await logErrorToFile('❌ getAllOrders failed, returning empty list: $e');
      return [];
    }
  }

  // Counts for the dashboard stat cards. Uses SQL aggregates so no order rows
  // or order_items are materialised - the dashboard only needs a few integers,
  // and loading the whole table for them does not scale as history grows.
  //
  // 'pending'      - all pending orders regardless of date (desktop dashboard)
  // 'today'        - orders created today
  // 'pendingToday' - pending orders created today (mobile dashboard)
  Future<Map<String, int>> getDashboardCounts() async {
    try {
      final db = await database;

      // created_at is stored as an ISO8601 string, so a prefix match on the
      // local date selects "today" without parsing every row in Dart.
      final todayPrefix = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final like = '$todayPrefix%';

      final rows = await db.rawQuery(
        'SELECT '
        "  (SELECT COUNT(*) FROM orders WHERE status = 'pending') AS pending, "
        '  (SELECT COUNT(*) FROM orders WHERE created_at LIKE ?) AS today, '
        "  (SELECT COUNT(*) FROM orders WHERE created_at LIKE ? AND status = 'pending') AS pending_today",
        [like, like],
      );

      final row = rows.first;
      return {
        'pending': (row['pending'] as int?) ?? 0,
        'today': (row['today'] as int?) ?? 0,
        'pendingToday': (row['pending_today'] as int?) ?? 0,
      };
    } catch (e) {
      await logErrorToFile('❌ getDashboardCounts failed, returning zeros: $e');
      return {'pending': 0, 'today': 0, 'pendingToday': 0};
    }
  }

  // Get a page of local orders, most recent first. Used by the Order List
  // screen's "All Orders" view so it stays fast regardless of how many
  // orders a customer has accumulated over time.
  Future<List<Order>> getOrdersPage({
    int limit = 200,
    int offset = 0,
    OrderQueryFilters filters = OrderQueryFilters.none,
  }) async {
    try {
      return await _queryOrders(filters: filters, limit: limit, offset: offset);
    } catch (e) {
      await logErrorToFile('❌ getOrdersPage failed, returning empty list: $e');
      return [];
    }
  }

  // One builder behind every paged order listing, so getOrdersPage and
  // getOrdersByDateRange cannot drift apart in how they apply filters.
  //
  // [conditions] are the caller's own WHERE fragments (a date range, say) and
  // [args] their bound values, in the same order. Filter conditions are
  // appended after them, which keeps placeholders and arguments aligned.
  Future<List<Order>> _queryOrders({
    List<String> conditions = const [],
    List<Object?> args = const [],
    OrderQueryFilters filters = OrderQueryFilters.none,
    int? limit,
    int offset = 0,
  }) async {
    final db = await database;

    final (filterConditions, filterArgs) = filters.toConditions();
    final allConditions = [...conditions, ...filterConditions];
    final allArgs = [...args, ...filterArgs];

    final orders = await db.query(
      'orders',
      where: allConditions.isEmpty ? null : allConditions.join(' AND '),
      whereArgs: allArgs.isEmpty ? null : allArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      // SQL has no OFFSET without LIMIT, so an offset alone would build an
      // invalid statement. Callers that want everything pass neither.
      offset: (limit != null && offset > 0) ? offset : null,
    );

    return await _mapOrdersWithItems(db, orders);
  }

  // Search orders directly in SQL (indexed columns where available) instead
  // of loading the whole table into memory and filtering in Dart.
  Future<List<Order>> searchOrders(String query, {int limit = 200}) async {
    try {
      final db = await database;
      final like = '%$query%';

      final orders = await db.query(
        'orders',
        where: 'CAST(id AS TEXT) LIKE ? '
            'OR CAST(main_order_number AS TEXT) LIKE ? '
            'OR token_number LIKE ? '
            'OR customer_name LIKE ? '
            'OR service_type LIKE ?',
        whereArgs: [like, like, like, like, like],
        orderBy: 'created_at DESC',
        limit: limit,
      );

      return await _mapOrdersWithItems(db, orders);
    } catch (e) {
      await logErrorToFile('❌ searchOrders failed, returning empty list: $e');
      return [];
    }
  }
  
  // Fetch just the orders whose ids are already known, instead of loading the
  // whole table and filtering in Dart. Chunked, so the caller's id set can be
  // any size.
  Future<List<Order>> getOrdersByIds(Set<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final db = await database;

      final orders = await _queryInChunks(
        ids.toList(),
        (chunk) => db.query(
          'orders',
          where: 'id IN (${chunk.map((_) => '?').join(',')})',
          whereArgs: chunk,
        ),
      );

      return await _mapOrdersWithItems(db, orders);
    } catch (e) {
      await logErrorToFile('❌ getOrdersByIds failed, returning empty list: $e');
      return [];
    }
  }

  // Locate a single order by the (device, staff order number) pair used during
  // device sync. Backed by idx_orders_staff_device.
  Future<Order?> findByStaffOrder(String staffDeviceId, int? staffOrderNumber) async {
    if (staffDeviceId.isEmpty || staffOrderNumber == null) return null;
    try {
      final db = await database;

      final orders = await db.query(
        'orders',
        where: 'staff_device_id = ? AND staff_order_number = ?',
        whereArgs: [staffDeviceId, staffOrderNumber],
        limit: 1,
      );

      if (orders.isEmpty) return null;
      final mapped = await _mapOrdersWithItems(db, orders);
      return mapped.isEmpty ? null : mapped.first;
    } catch (e) {
      await logErrorToFile('❌ findByStaffOrder failed, returning null: $e');
      return null;
    }
  }

  // Orders still awaiting upload. Backed by idx_orders_is_synced (schema v17)
  // so this stays cheap as history grows.
  Future<List<Order>> getUnsyncedOrders() async {
    try {
      final db = await database;

      final orders = await db.query(
        'orders',
        where: 'is_synced = ?',
        whereArgs: [0],
        orderBy: 'created_at DESC',
      );

      return await _mapOrdersWithItems(db, orders);
    } catch (e) {
      await logErrorToFile('❌ getUnsyncedOrders failed, returning empty list: $e');
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
        purchasePrice: item['purchase_price'] != null ? (item['purchase_price'] as num).toDouble() : 0.0,
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
        isTempReceiptPrinted: (orderMap['is_temp_receipt_printed'] as int?) == 1,
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
        {
          'status': status,
          'updated_at': DateTime.now().toIso8601String(), // Trigger LAN Sync Incremental sync
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }

  // Update order discount
  Future<bool> updateOrderDiscount(int orderId, double discount, double newTotal) async {
    try {
      final db = await database;
      await db.update(
        'orders',
        {
          'discount': discount,
          'total': newTotal,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      return true;
    } catch (e) {
      debugPrint('Error updating order discount: $e');
      return false;
    }
  }

  // Set temporary receipt printed status
  Future<bool> setTempReceiptPrinted(int orderId, bool printed) async {
    try {
      final db = await database;
      await db.update(
        'orders',
        {
          'is_temp_receipt_printed': printed ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      return true;
    } catch (e) {
      debugPrint('Error setting temp receipt printed status: $e');
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

  // Clear all data from the database
  Future<void> clearData() async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('order_items');
        await txn.delete('orders');
        
        // Reset auto-increment counters so order numbers start from 1 again
        try {
          await txn.execute("DELETE FROM sqlite_sequence WHERE name='orders'");
          await txn.execute("DELETE FROM sqlite_sequence WHERE name='order_items'");
        } catch (e) {
          debugPrint('Notice: sqlite_sequence missing or could not be reset: $e');
        }
      });
      
      // Also reset the staff order counter in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('staff_order_counter');
      
      debugPrint('Order data cleared and counters reset');
    } catch (e) {
      debugPrint('Error clearing order data: $e');
    }
  }

  // Force reset the database connection
  static Future<void> resetConnection() async {
    try {
      _isResetting = true; // 🛡️ Block access during reset
      _dbOpenFuture = null; // Clear stale future so next open starts fresh
      if (_database != null) {
        if (_database!.isOpen) {
          await _database!.close();
        }
        _database = null;
        debugPrint('Order database connection reset');
      }
    } catch (e) {
      debugPrint('Error resetting order database connection: $e');
    } finally {
      // NOTE: We do NOT set _isResetting = false here.
      // The app is expected to restart or navigate to/from AppInitializer
      // which creates a fresh environment (or we assume static reset on reload if hot restart).
      // However, if we just navigate, static fields PERSIST.
      // So we MUST allow re-initialization if accessed again later (e.g. after reset completes).
       _isResetting = false; 
    }
  }

  // Force reset the database connection


  // Close the database connection
  Future<void> close() async {
     await resetConnection();
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


}