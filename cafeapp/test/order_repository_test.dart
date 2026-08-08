// Regression tests for the order repository query paths.
//
// The bug these exist for: _mapOrdersWithItems used to bind one SQL variable
// per order into a single "order_id IN (?,?,?...)" clause. Past SQLite's
// bound-variable limit that statement throws, and the repository's catch block
// turns the throw into an empty list - so reports and device sync silently
// render nothing instead of failing loudly. The limit is 32,766 on the Windows
// ffi build and 999 on Android's system SQLite, so this reproduced at roughly
// 1,000 orders on a phone.
//
// These tests exercise the same query shapes against sqflite_common_ffi, which
// is the same engine the Windows app uses. They need no path_provider, so they
// run headless:
//
//   flutter test test/order_repository_test.dart --no-pub

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Mirrors _kSqlVarChunk in lib/repositories/local_order_repository.dart.
/// If that constant changes, change this one and the boundary test still holds.
const int kSqlVarChunk = 500;

const _schemaOrders = '''
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
''';

const _schemaItems = '''
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
''';

const _indexes = [
  'CREATE INDEX idx_order_items_order_id ON order_items (order_id)',
  'CREATE INDEX idx_orders_staff_device ON orders (staff_device_id)',
  'CREATE INDEX idx_orders_created_at ON orders (created_at)',
  'CREATE INDEX idx_orders_is_synced ON orders (is_synced)',
];

/// Number of line items seeded for order [i]. Deterministic so tests can assert
/// exact totals without holding the whole dataset in memory.
int _lineCountFor(int i) => (i % 4) + 1;

/// Seeds [orderCount] orders, each with 1-4 items, spread backwards in time at
/// ~14 minute intervals. Device id cycles over 4 devices.
Future<Database> seedDb(int orderCount, {DateTime? now}) async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute(_schemaOrders);
  await db.execute(_schemaItems);
  for (final ix in _indexes) {
    await db.execute(ix);
  }

  final base = now ?? DateTime(2026, 8, 2, 12);
  final batch = db.batch();
  for (var i = 1; i <= orderCount; i++) {
    final created = base.subtract(Duration(minutes: (orderCount - i) * 14));
    batch.insert('orders', {
      'id': i,
      'staff_order_number': i,
      'main_order_number': i,
      'staff_device_id': 'device-${i % 4}',
      'service_type': 'Dining',
      'subtotal': 100.0,
      'tax': 5.0,
      'discount': 0.0,
      'total': 105.0,
      'status': i.isEven ? 'completed' : 'pending',
      'created_at': created.toIso8601String(),
      'updated_at': created.toIso8601String(),
      'is_synced': i % 3 == 0 ? 0 : 1,
      'is_deleted': 0,
      'main_number_assigned': 1,
      'is_temp_receipt_printed': 0,
    });
    for (var j = 0; j < _lineCountFor(i); j++) {
      batch.insert('order_items', {
        'order_id': i,
        'menu_item_id': j + 1,
        'name': 'Item $j',
        'price': 10.0,
        'quantity': 1,
        'kitchen_note': '',
        'tax_exempt': 0,
        'purchase_price': 5.0,
      });
    }
  }
  await batch.commit(noResult: true);
  return db;
}

/// The chunked item fetch, matching LocalOrderRepository._queryInChunks +
/// _mapOrdersWithItems. Returns items grouped by order id.
Future<Map<int, List<Map<String, Object?>>>> fetchItemsChunked(
    Database db, List<int> orderIds) async {
  final allItems = <Map<String, Object?>>[];
  if (orderIds.isNotEmpty) {
    for (var i = 0; i < orderIds.length; i += kSqlVarChunk) {
      final end = i + kSqlVarChunk;
      final chunk =
          orderIds.sublist(i, end > orderIds.length ? orderIds.length : end);
      allItems.addAll(await db.query(
        'order_items',
        where: 'order_id IN (${chunk.map((_) => '?').join(',')})',
        whereArgs: chunk,
      ));
    }
  }
  final grouped = <int, List<Map<String, Object?>>>{};
  for (final item in allItems) {
    grouped.putIfAbsent(item['order_id'] as int, () => []).add(item);
  }
  return grouped;
}

/// The pre-fix implementation: every id bound into one statement. Kept so the
/// tests can prove the limit is real rather than assuming it.
Future<List<Map<String, Object?>>> fetchItemsUnchunked(
    Database db, List<int> orderIds) {
  return db.query(
    'order_items',
    where: 'order_id IN (${orderIds.map((_) => '?').join(',')})',
    whereArgs: orderIds,
  );
}

int _expectedItemCount(int orderCount) {
  var total = 0;
  for (var i = 1; i <= orderCount; i++) {
    total += _lineCountFor(i);
  }
  return total;
}

void main() {
  sqfliteFfiInit();

  group('IN (...) chunking', () {
    test('every order keeps its items well past the Android 999 limit',
        () async {
      final db = await seedDb(1200);
      final ids = List.generate(1200, (i) => i + 1);

      final grouped = await fetchItemsChunked(db, ids);

      expect(grouped.length, 1200, reason: 'every order should have items');
      for (final i in [1, 500, 501, 999, 1000, 1200]) {
        expect(grouped[i]!.length, _lineCountFor(i),
            reason: 'order $i lost or gained items');
      }
      final total = grouped.values.fold<int>(0, (s, v) => s + v.length);
      expect(total, _expectedItemCount(1200));

      await db.close();
    });

    test('survives past the Windows 32,766 limit', () async {
      final db = await seedDb(40000);
      final ids = List.generate(40000, (i) => i + 1);

      final grouped = await fetchItemsChunked(db, ids);

      expect(grouped.length, 40000);
      final total = grouped.values.fold<int>(0, (s, v) => s + v.length);
      expect(total, _expectedItemCount(40000));

      await db.close();
    });

    test('the unchunked query really does throw - the bug was not theoretical',
        () async {
      final db = await seedDb(40000);
      final ids = List.generate(40000, (i) => i + 1);

      await expectLater(
        fetchItemsUnchunked(db, ids),
        throwsA(predicate((e) =>
            e.toString().toLowerCase().contains('too many sql variables'))),
      );

      await db.close();
    });

    test('boundary: exactly at, one under, and one over the chunk size',
        () async {
      final db = await seedDb(kSqlVarChunk + 1);

      for (final n in [kSqlVarChunk - 1, kSqlVarChunk, kSqlVarChunk + 1]) {
        final ids = List.generate(n, (i) => i + 1);
        final grouped = await fetchItemsChunked(db, ids);
        expect(grouped.length, n, reason: 'wrong order count for n=$n');
        expect(grouped.values.fold<int>(0, (s, v) => s + v.length),
            _expectedItemCount(n),
            reason: 'wrong item count for n=$n');
      }

      await db.close();
    });

    test('empty id list issues no query and returns nothing', () async {
      final db = await seedDb(10);
      expect(await fetchItemsChunked(db, []), isEmpty);
      await db.close();
    });
  });

  group('repointed callers return what the full scan did', () {
    late Database db;
    const seeded = 1500;

    setUp(() async {
      db = await seedDb(seeded);
    });

    tearDown(() async {
      await db.close();
    });

    test('getOrdersByIds matches filtering all orders by the same ids',
        () async {
      final wanted = {3, 17, 502, 999, 1000, 1499};

      // New path: chunked IN on orders.id.
      final viaIds = <int>[];
      final idList = wanted.toList();
      for (var i = 0; i < idList.length; i += kSqlVarChunk) {
        final end = i + kSqlVarChunk;
        final chunk =
            idList.sublist(i, end > idList.length ? idList.length : end);
        final rows = await db.query('orders',
            where: 'id IN (${chunk.map((_) => '?').join(',')})',
            whereArgs: chunk);
        viaIds.addAll(rows.map((r) => r['id'] as int));
      }

      // Old path: load everything, filter in Dart.
      final all = await db.query('orders');
      final viaScan = all
          .map((r) => r['id'] as int)
          .where(wanted.contains)
          .toList();

      expect(viaIds..sort(), equals(viaScan..sort()));
    });

    test('findByStaffOrder matches the old firstWhereOrNull scan', () async {
      const deviceId = 'device-2';
      const staffOrderNumber = 998; // 998 % 4 == 2

      final rows = await db.query('orders',
          where: 'staff_device_id = ? AND staff_order_number = ?',
          whereArgs: [deviceId, staffOrderNumber],
          limit: 1);

      final all = await db.query('orders');
      final expected = all.where((o) =>
          o['staff_device_id'] == deviceId &&
          o['staff_order_number'] == staffOrderNumber);

      expect(rows.length, 1);
      expect(expected.length, 1);
      expect(rows.first['id'], expected.first['id']);
    });

    test('findByStaffOrder returns nothing for an unknown pair', () async {
      final rows = await db.query('orders',
          where: 'staff_device_id = ? AND staff_order_number = ?',
          whereArgs: ['device-does-not-exist', 1],
          limit: 1);
      expect(rows, isEmpty);
    });

    test('getUnsyncedOrders matches the old where((o) => !o.isSynced) filter',
        () async {
      final viaSql = await db.query('orders',
          where: 'is_synced = ?', whereArgs: [0], orderBy: 'created_at DESC');

      final all = await db.query('orders');
      final viaScan = all.where((o) => o['is_synced'] == 0);

      expect(viaSql.length, viaScan.length);
      expect(viaSql.length, greaterThan(0), reason: 'seed should have unsynced');
      expect(
        viaSql.map((r) => r['id'] as int).toList()..sort(),
        equals(viaScan.map((r) => r['id'] as int).toList()..sort()),
      );
    });

    test(
        'widened date-range query is a superset of the exact range, so the '
        'Dart filter still decides the report', () async {
      // Report screen asks SQL for +/- 1 day, then filters precisely in Dart.
      final start = DateTime(2026, 7, 30);
      final end = DateTime(2026, 7, 31, 23, 59, 59);

      final widened = await db.query(
        'orders',
        where: 'created_at >= ? AND created_at <= ?',
        whereArgs: [
          start.subtract(const Duration(days: 1)).toIso8601String(),
          end.add(const Duration(days: 1)).toIso8601String(),
        ],
      );
      final widenedIds = widened.map((r) => r['id'] as int).toSet();

      // The exact set the old code would have produced from a full scan.
      final all = await db.query('orders');
      final exactIds = all
          .where((r) {
            final t = DateTime.parse(r['created_at'] as String);
            return !t.isBefore(start) && !t.isAfter(end);
          })
          .map((r) => r['id'] as int)
          .toSet();

      expect(exactIds, isNotEmpty, reason: 'seed should cover this window');
      expect(widenedIds.containsAll(exactIds), isTrue,
          reason: 'widened SQL range must not drop any in-range order');
    });
  });
}
