// Performance benchmark harness.
//
// Replicates the exact query shapes used by LocalOrderRepository against
// synthetic datasets so we can see how each operation scales with order
// history. Run with:
//
//   flutter test test/perf_benchmark_test.dart --no-pub
//
// This is a measurement tool, not a regression test - it always passes.

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
  'CREATE INDEX idx_orders_main_number ON orders (main_order_number)',
  'CREATE INDEX idx_orders_deposit_amount ON orders (deposit_amount)',
  'CREATE INDEX idx_orders_event_date ON orders (event_date)',
  'CREATE INDEX idx_orders_created_at ON orders (created_at)',
  'CREATE INDEX idx_orders_updated_at ON orders (updated_at)',
];

/// Median of a list of microsecond timings.
double _median(List<int> xs) {
  final s = [...xs]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2].toDouble() : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2.0;
}

/// Runs [body] [reps] times after [warmup] discarded runs, returns median ms.
Future<double> _bench(Future<void> Function() body,
    {int reps = 7, int warmup = 2}) async {
  for (var i = 0; i < warmup; i++) {
    await body();
  }
  final times = <int>[];
  for (var i = 0; i < reps; i++) {
    final sw = Stopwatch()..start();
    await body();
    sw.stop();
    times.add(sw.elapsedMicroseconds);
  }
  return _median(times) / 1000.0;
}

Future<Database> _seed(int orderCount) async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('PRAGMA journal_mode=WAL;');
  await db.execute(_schemaOrders);
  await db.execute(_schemaItems);
  for (final ix in _indexes) {
    await db.execute(ix);
  }

  final rnd = Random(42);
  const services = ['Dining', 'Takeout', 'Delivery', 'Catering', 'Drive Through'];
  const statuses = ['pending', 'completed', 'completed', 'completed'];
  const names = [
    'Cappuccino', 'Espresso', 'Latte', 'Chicken Shawarma', 'Beef Burger',
    'Club Sandwich', 'French Fries', 'Caesar Salad', 'Mango Juice', 'Water',
  ];

  final now = DateTime.now();
  final batch = db.batch();
  var itemId = 1;
  for (var i = 1; i <= orderCount; i++) {
    // Spread orders backwards in time, ~100 orders/day.
    final created = now.subtract(Duration(minutes: (orderCount - i) * 14));
    batch.insert('orders', {
      'id': i,
      'staff_order_number': i,
      'main_order_number': i,
      'staff_device_id': 'device-${i % 4}',
      'service_type': services[i % services.length],
      'subtotal': 25.0 + rnd.nextInt(200),
      'tax': 2.5,
      'discount': 0.0,
      'total': 27.5 + rnd.nextInt(200),
      'status': statuses[i % statuses.length],
      'created_at': created.toIso8601String(),
      'payment_method': i.isEven ? 'cash' : 'bank',
      'customer_name': 'Customer $i',
      'token_number': 'T$i',
      'updated_at': created.toIso8601String(),
      'is_deleted': 0,
      'is_synced': i % 3 == 0 ? 0 : 1,
      'main_number_assigned': 1,
      'is_temp_receipt_printed': 0,
    });
    // Realistic basket: 1-6 line items, average ~3.
    final lines = 1 + rnd.nextInt(6);
    for (var j = 0; j < lines; j++) {
      batch.insert('order_items', {
        'id': itemId++,
        'order_id': i,
        'menu_item_id': rnd.nextInt(30) + 1,
        'name': names[rnd.nextInt(names.length)],
        'price': 5.0 + rnd.nextInt(40),
        'quantity': 1 + rnd.nextInt(3),
        'kitchen_note': j == 0 ? 'no onions' : '',
        'tax_exempt': 0,
        'purchase_price': 3.0,
      });
    }
  }
  await batch.commit(noResult: true);
  return db;
}

/// Mirrors LocalOrderRepository._mapOrdersWithItems: one batched IN query for
/// items, then in-memory grouping and object construction.
/// NOTE: the shipped version passes every order id as a bound variable in a
/// single IN (...) clause, which throws "too many SQL variables" past the
/// SQLite limit (32,766 on Windows/ffi, 999 on Android's system SQLite).
/// Here we chunk it so the benchmark can complete - this measures what a
/// fixed implementation would cost.
const _varChunk = 900;

Future<int> _mapOrdersWithItems(
    Database db, List<Map<String, Object?>> orders) async {
  if (orders.isEmpty) return 0;
  final orderIds = orders.map((o) => o['id'] as int).toList();
  final allItems = <Map<String, Object?>>[];
  for (var i = 0; i < orderIds.length; i += _varChunk) {
    final chunk = orderIds.sublist(
        i, i + _varChunk > orderIds.length ? orderIds.length : i + _varChunk);
    allItems.addAll(await db.query(
      'order_items',
      where: 'order_id IN (${chunk.map((_) => '?').join(',')})',
      whereArgs: chunk,
    ));
  }
  final itemsByOrderId = <int, List<Map<String, Object?>>>{};
  for (final item in allItems) {
    itemsByOrderId.putIfAbsent(item['order_id'] as int, () => []).add(item);
  }
  var built = 0;
  for (final orderMap in orders) {
    final items = itemsByOrderId[orderMap['id'] as int] ?? [];
    // Stand-in for OrderItem construction - same per-row field extraction cost.
    for (final item in items) {
      item['name'] as String;
      (item['price'] as num).toDouble();
      item['quantity'] as int;
      built++;
    }
    orderMap['service_type'] as String? ?? '';
    (orderMap['subtotal'] as num? ?? 0).toDouble();
  }
  return built;
}

void main() {
  sqfliteFfiInit();

  test('performance benchmark', () async {
    const scales = [75, 1000, 10000, 50000];
    final results = <String, Map<int, double>>{};
    // Rows returned per operation, so a timing can be read against the amount
    // of work it represents rather than guessed at.
    final rowCounts = <String, Map<int, int>>{};

    void record(String op, int scale, double ms) {
      results.putIfAbsent(op, () => {})[scale] = ms;
    }

    for (final scale in scales) {
      final db = await _seed(scale);

      // ---- getAllOrders(): unbounded, no LIMIT ----
      record('getAllOrders (unbounded)', scale, await _bench(() async {
        final orders = await db.query('orders', orderBy: 'created_at DESC');
        await _mapOrdersWithItems(db, orders);
      }, reps: scale >= 10000 ? 3 : 7));

      // ---- getOrdersPage(limit: 200) ----
      record('getOrdersPage (200)', scale, await _bench(() async {
        final orders = await db.query('orders',
            orderBy: 'created_at DESC', limit: 200, offset: 0);
        await _mapOrdersWithItems(db, orders);
      }));

      // ---- dashboard recent list (limit: 7) ----
      record('getOrdersPage (7, dashboard)', scale, await _bench(() async {
        final orders = await db.query('orders',
            orderBy: 'created_at DESC', limit: 7, offset: 0);
        await _mapOrdersWithItems(db, orders);
      }));

      // ---- getDashboardCounts(): SQL aggregates ----
      final todayPrefix =
          DateTime.now().toIso8601String().substring(0, 10);
      final like = '$todayPrefix%';
      record('getDashboardCounts', scale, await _bench(() async {
        await db.rawQuery(
          'SELECT '
          "  (SELECT COUNT(*) FROM orders WHERE status = 'pending') AS pending, "
          '  (SELECT COUNT(*) FROM orders WHERE created_at LIKE ?) AS today, '
          "  (SELECT COUNT(*) FROM orders WHERE created_at LIKE ? AND status = 'pending') AS pending_today",
          [like, like],
        );
      }));

      // ---- searchOrders(): 5-column LIKE scan ----
      record('searchOrders (LIKE x5)', scale, await _bench(() async {
        const q = '%123%';
        final orders = await db.query(
          'orders',
          where: 'CAST(id AS TEXT) LIKE ? '
              'OR CAST(main_order_number AS TEXT) LIKE ? '
              'OR token_number LIKE ? '
              'OR customer_name LIKE ? '
              'OR service_type LIKE ?',
          whereArgs: [q, q, q, q, q],
          orderBy: 'created_at DESC',
          limit: 200,
        );
        await _mapOrdersWithItems(db, orders);
      }));

      // ---- getOrdersByDateRange(): the Today/Week/Month/Yearly filters ----
      //
      // These take the dateRange branch of _resolveFetchMode, which loads the
      // WHOLE period with no LIMIT and sets _hasMore = false. Unlike the paged
      // "All Orders" path, nothing bounds them. Row counts are recorded next to
      // the timings because the cost is driven by rows-in-period, which depends
      // on the cafe's daily volume rather than on total history.
      final rangeNow = DateTime.now();
      final periods = <String, DateTime>{
        'today': DateTime(rangeNow.year, rangeNow.month, rangeNow.day),
        'week': DateTime(rangeNow.year, rangeNow.month, rangeNow.day)
            .subtract(Duration(days: rangeNow.weekday - 1)),
        'month': DateTime(rangeNow.year, rangeNow.month, 1),
        'year': DateTime(rangeNow.year, 1, 1),
      };

      for (final period in periods.entries) {
        // Mirrors the provider: the bounds are widened by 24h on each side and
        // narrowed again in Dart, because created_at is a mixed-format column.
        final start = period.value
            .subtract(const Duration(hours: 24))
            .toIso8601String();
        final end = DateTime(rangeNow.year, rangeNow.month, rangeNow.day)
            .add(const Duration(days: 1, hours: 24))
            .toIso8601String();

        final rows = (await db.query('orders',
                where: 'created_at >= ? AND created_at <= ?',
                whereArgs: [start, end]))
            .length;
        rowCounts.putIfAbsent('dateRange (${period.key})', () => {})[scale] =
            rows;

        // Before: the whole period in one query, which is what the provider
        // used to issue.
        record('dateRange (${period.key})', scale, await _bench(() async {
          final orders = await db.query(
            'orders',
            where: 'created_at >= ? AND created_at <= ?',
            whereArgs: [start, end],
            orderBy: 'created_at DESC',
          );
          await _mapOrdersWithItems(db, orders);
        }, reps: rows >= 10000 ? 3 : 7));

        // After: one page, which is what it issues now. The gap between these
        // two rows for 'year' is the whole point of the change.
        record('dateRange (${period.key}, paged)', scale, await _bench(() async {
          final orders = await db.query(
            'orders',
            where: 'created_at >= ? AND created_at <= ?',
            whereArgs: [start, end],
            orderBy: 'created_at DESC',
            limit: 200,
          );
          await _mapOrdersWithItems(db, orders);
        }));
      }

      // ---- Deep-offset paging: does LIMIT/OFFSET degrade with depth? ----
      //
      // The flat "getOrdersPage (200)" figure above is measured at offset 0.
      // SQLite still walks and discards `offset` rows, so this decides whether
      // keyset pagination is ever needed.
      for (final offset in [1000, 10000]) {
        if (offset >= scale) continue;
        record('getOrdersPage (200 @ $offset)', scale, await _bench(() async {
          final orders = await db.query('orders',
              orderBy: 'created_at DESC', limit: 200, offset: offset);
          await _mapOrdersWithItems(db, orders);
        }));
      }

      // ---- getOrderById(): indexed single-row lookup ----
      record('getOrderById', scale, await _bench(() async {
        final id = scale ~/ 2;
        await db.query('orders', where: 'id = ?', whereArgs: [id]);
        await db.query('order_items', where: 'order_id = ?', whereArgs: [id]);
      }, reps: 21));

      // ---- Save order: insert order + 3 items in a transaction ----
      var nextId = scale + 1;
      record('saveOrder (1 order + 3 items)', scale, await _bench(() async {
        final id = nextId++;
        await db.transaction((txn) async {
          await txn.insert('orders', {
            'id': id,
            'staff_order_number': id,
            'main_order_number': id,
            'staff_device_id': 'device-1',
            'service_type': 'Dining',
            'subtotal': 100.0,
            'tax': 5.0,
            'discount': 0.0,
            'total': 105.0,
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'is_deleted': 0,
            'is_synced': 0,
            'main_number_assigned': 1,
            'is_temp_receipt_printed': 0,
          });
          for (var j = 0; j < 3; j++) {
            await txn.insert('order_items', {
              'order_id': id,
              'menu_item_id': j + 1,
              'name': 'Item $j',
              'price': 20.0,
              'quantity': 1,
              'kitchen_note': '',
              'tax_exempt': 0,
              'purchase_price': 10.0,
            });
          }
        });
      }, reps: 15));

      await db.close();
    }

    // ---- Menu search: in-memory Dart filter, as menu_screen.dart does ----
    final menuResults = <int, double>{};
    for (final menuSize in [27, 200, 1000, 5000]) {
      final items = List.generate(
          menuSize,
          (i) => {
                'name': 'Menu Item $i Cappuccino Shawarma',
                'barcode': i.isEven ? '890${i}00112' : '',
              });
      const query = 'shawarma';
      menuResults[menuSize] = await _bench(() async {
        items.where((item) {
          final nameMatches =
              (item['name'] as String).toLowerCase().contains(query);
          final barcode = item['barcode'] as String;
          final barcodeMatches =
              barcode.isNotEmpty && barcode.toLowerCase().contains(query);
          return nameMatches || barcodeMatches;
        }).toList();
      }, reps: 51, warmup: 10);
    }

    // ---------- Report ----------
    final buf = StringBuffer();
    buf.writeln('');
    buf.writeln('=' * 78);
    buf.writeln('DATABASE OPERATIONS - median ms by order count');
    buf.writeln('=' * 78);
    buf.writeln('${'operation'.padRight(32)}'
        '${'75'.padLeft(10)}${'1,000'.padLeft(10)}'
        '${'10,000'.padLeft(11)}${'50,000'.padLeft(11)}');
    buf.writeln('-' * 78);
    for (final entry in results.entries) {
      final row = StringBuffer(entry.key.padRight(32));
      for (final s in scales) {
        final v = entry.value[s];
        row.write((v == null ? '-' : v.toStringAsFixed(2)).padLeft(s == 75 ? 10 : (s == 1000 ? 10 : 11)));
      }
      buf.writeln(row);
    }
    buf.writeln('');
    buf.writeln('=' * 78);
    buf.writeln('ROWS RETURNED - date-range filters (seeded at ~103 orders/day)');
    buf.writeln('=' * 78);
    buf.writeln('${'operation'.padRight(32)}'
        '${'75'.padLeft(10)}${'1,000'.padLeft(10)}'
        '${'10,000'.padLeft(11)}${'50,000'.padLeft(11)}');
    buf.writeln('-' * 78);
    for (final entry in rowCounts.entries) {
      final row = StringBuffer(entry.key.padRight(32));
      for (final s in scales) {
        final v = entry.value[s];
        row.write((v == null ? '-' : '$v')
            .padLeft(s == 75 ? 10 : (s == 1000 ? 10 : 11)));
      }
      buf.writeln(row);
    }
    buf.writeln('');
    buf.writeln('=' * 78);
    buf.writeln('MENU SEARCH - median ms per keystroke (in-memory filter)');
    buf.writeln('=' * 78);
    for (final e in menuResults.entries) {
      buf.writeln('${'${e.key} menu items'.padRight(32)}'
          '${e.value.toStringAsFixed(4).padLeft(10)} ms');
    }
    buf.writeln('=' * 78);
    // ignore: avoid_print
    print(buf.toString());
  }, timeout: const Timeout(Duration(minutes: 15)));
}
