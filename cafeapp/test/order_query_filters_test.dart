// Equivalence tests for moving the order-list filters from Dart into SQL.
//
// The danger in that change is not performance, it is silently dropping rows.
// A filter that quietly returns fewer orders than before is far worse than a
// slow screen, and it would be invisible until a cafe noticed missing history.
//
// So every filter combination is run twice against the same seeded dataset:
// once through the generated SQL, once through the Dart reference in
// OrderQueryFilters.matches (which mirrors the pre-change logic in
// OrderHistoryProvider's `orders` getter). The two id sets must be identical.
//
// Runs headless against sqflite_common_ffi - the same engine the Windows app
// uses - so it needs no path_provider:
//
//   flutter test test/order_query_filters_test.dart --no-pub

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cafeapp/repositories/order_query_filters.dart';

const _schemaOrders = '''
  CREATE TABLE orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    staff_device_id TEXT NOT NULL,
    service_type TEXT,
    subtotal REAL NOT NULL,
    tax REAL NOT NULL,
    discount REAL NOT NULL,
    total REAL NOT NULL,
    status TEXT NOT NULL,
    created_at TEXT NOT NULL,
    deposit_amount REAL
  )
''';

/// Deliberately awkward data: mixed case, a null service_type, an empty one,
/// deposits present and absent. The nulls are the point - see the COALESCE note
/// in OrderQueryFilters.
const _rows = <Map<String, Object?>>[
  {'id': 1, 'service_type': 'Dining - Table 1', 'status': 'pending', 'deposit_amount': null},
  {'id': 2, 'service_type': 'Catering', 'status': 'completed', 'deposit_amount': 50.0},
  {'id': 3, 'service_type': 'catering', 'status': 'pending', 'deposit_amount': 0.0},
  {'id': 4, 'service_type': 'Takeout', 'status': 'Completed', 'deposit_amount': null},
  {'id': 5, 'service_type': null, 'status': 'pending', 'deposit_amount': null},
  {'id': 6, 'service_type': '', 'status': 'completed', 'deposit_amount': 25.0},
  {'id': 7, 'service_type': 'Delivery', 'status': 'PENDING', 'deposit_amount': null},
  {'id': 8, 'service_type': 'Event Catering Hall', 'status': 'completed', 'deposit_amount': 100.0},
  {'id': 9, 'service_type': 'Drive Through', 'status': 'cancelled', 'deposit_amount': null},
  {'id': 10, 'service_type': 'Dining - Table 2', 'status': 'completed', 'deposit_amount': null},
];

Future<Database> _seed() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute(_schemaOrders);
  for (final row in _rows) {
    await db.insert('orders', {
      'id': row['id'],
      'staff_device_id': 'test',
      'service_type': row['service_type'],
      'subtotal': 10.0,
      'tax': 0.5,
      'discount': 0.0,
      'total': 10.5,
      'status': row['status'],
      'created_at': '2026-08-0${(row['id'] as int) % 9 + 1}T10:00:00.000',
      'deposit_amount': row['deposit_amount'],
    });
  }
  return db;
}

Set<int> _expected(OrderQueryFilters f) => _rows
    .where((r) => f.matches(
          status: r['status'] as String,
          // The getter reads OrderHistory.serviceType, a non-null String, so a
          // null column arrives as ''. Mirror that.
          serviceType: (r['service_type'] as String?) ?? '',
          depositAmount: r['deposit_amount'] as double?,
        ))
    .map((r) => r['id'] as int)
    .toSet();

Future<Set<int>> _actual(Database db, OrderQueryFilters f) async {
  final (conditions, args) = f.toConditions();
  final rows = await db.query(
    'orders',
    where: conditions.isEmpty ? null : conditions.join(' AND '),
    whereArgs: args.isEmpty ? null : args,
  );
  return rows.map((r) => r['id'] as int).toSet();
}

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async => db = await _seed());
  tearDown(() async => db.close());

  /// Every combination the provider can produce. cateringOnly and
  /// excludeCatering are mutually exclusive in the provider's setters, and the
  /// getter's if/else-if makes cateringOnly win, so both orderings are covered.
  Iterable<OrderQueryFilters> allCombinations() sync* {
    const statuses = [null, 'all', 'pending', 'completed', 'PENDING'];
    const serviceTypes = [null, '', 'Dining - Table 1', 'catering', 'Takeout'];
    for (final status in statuses) {
      for (final serviceType in serviceTypes) {
        for (final catering in [
          (false, false),
          (true, false),
          (false, true),
          (true, true),
        ]) {
          for (final advanced in [false, true]) {
            yield OrderQueryFilters(
              status: status,
              cateringOnly: catering.$1,
              excludeCatering: catering.$2,
              advancedOnly: advanced,
              serviceType: serviceType,
            );
          }
        }
      }
    }
  }

  test('SQL and Dart filtering agree on every filter combination', () async {
    var checked = 0;
    for (final f in allCombinations()) {
      final expected = _expected(f);
      final actual = await _actual(db, f);
      expect(actual, expected,
          reason: 'mismatch for status=${f.status} '
              'cateringOnly=${f.cateringOnly} '
              'excludeCatering=${f.excludeCatering} '
              'advancedOnly=${f.advancedOnly} '
              'serviceType=${f.serviceType}');
      checked++;
    }
    // Guards against the generator silently producing nothing.
    expect(checked, 200);
  });

  test('a null service_type survives an exclude-catering listing', () async {
    // The regression this whole translation risks: SQL evaluates
    // `NULL NOT LIKE '%catering%'` to NULL, not true, so without COALESCE
    // order 5 would vanish from every dining listing.
    const f = OrderQueryFilters(excludeCatering: true);
    final actual = await _actual(db, f);

    expect(actual, contains(5), reason: 'null service_type must not be dropped');
    expect(actual, contains(6), reason: 'empty service_type must not be dropped');
    expect(actual, isNot(contains(2)));
    expect(actual, isNot(contains(3)));
    expect(actual, isNot(contains(8)));
  });

  test('catering matching is case-insensitive and substring-based', () async {
    const f = OrderQueryFilters(cateringOnly: true);
    // 'Catering', 'catering' and 'Event Catering Hall' all qualify, matching
    // the Dart `.toLowerCase().contains('catering')`.
    expect(await _actual(db, f), {2, 3, 8});
  });

  test('status matching is case-insensitive', () async {
    expect(await _actual(db, const OrderQueryFilters(status: 'pending')),
        {1, 3, 5, 7});
    expect(await _actual(db, const OrderQueryFilters(status: 'PENDING')),
        {1, 3, 5, 7});
  });

  test("status 'all' and null mean no restriction", () async {
    final everything = _rows.map((r) => r['id'] as int).toSet();
    expect(await _actual(db, const OrderQueryFilters(status: 'all')), everything);
    expect(await _actual(db, const OrderQueryFilters()), everything);
    expect(const OrderQueryFilters(status: 'all').isEmpty, isTrue);
  });

  test('advancedOnly keeps only positive deposits', () async {
    // Order 3 has deposit 0.0 and must not qualify - `> 0`, not `!= null`.
    expect(await _actual(db, const OrderQueryFilters(advancedOnly: true)),
        {2, 6, 8});
  });

  test('cateringOnly wins over excludeCatering, as the getter does', () async {
    const f = OrderQueryFilters(cateringOnly: true, excludeCatering: true);
    expect(await _actual(db, f), {2, 3, 8});
  });

  test('conditions compose with a caller-supplied clause', () async {
    // The repository ANDs these with a date range; prove that works rather
    // than assuming it.
    final (conditions, args) = const OrderQueryFilters(status: 'pending')
        .toConditions();
    final rows = await db.query(
      'orders',
      where: [...conditions, 'created_at >= ?'].join(' AND '),
      whereArgs: [...args, '2026-08-04T00:00:00.000'],
    );
    expect(rows.map((r) => r['id']).toSet(), {3, 5, 7});
  });
}
