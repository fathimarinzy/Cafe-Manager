// Tests for the payment-method fixes in tender_screen and the v18 repair.
//
// The bug: _selectedPaymentMethod holds a *translated* UI label. tender_screen
// wrote it straight to the database and compared it against the literals
// 'cash'/'bank'. English passes by accident ('Cash'.tr() -> "Cash" -> "cash"),
// Arabic does not - so on an Arabic till a Bank payment stored 'بنك' as the
// method and never added the amount to bank_amount.
//
//   flutter test test/payment_repair_test.dart --no-pub

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cafeapp/utils/app_localization.dart';
import 'package:cafeapp/repositories/local_order_repository.dart';

/// Mirrors _canonicalPaymentMethod() in tender_screen.dart. That method is
/// private to a StatefulWidget's State, so the logic is restated here against
/// the same translation source to prove the mapping holds in both languages.
String canonicalise(String? selected) {
  if (selected == null) return '';
  if (selected == 'Cash'.tr()) return 'cash';
  if (selected == 'Bank'.tr()) return 'bank';
  if (selected == 'Bank + Cash'.tr()) return 'bank+cash';
  if (selected == 'Customer Credit'.tr()) return 'customer_credit';
  return selected.toLowerCase();
}

const _ordersSchema = '''
  CREATE TABLE orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    staff_device_id TEXT NOT NULL DEFAULT '',
    service_type TEXT NOT NULL DEFAULT 'Dining',
    subtotal REAL NOT NULL DEFAULT 0,
    tax REAL NOT NULL DEFAULT 0,
    discount REAL NOT NULL DEFAULT 0,
    total REAL NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL DEFAULT '',
    payment_method TEXT,
    cash_amount REAL,
    bank_amount REAL,
    deposit_amount REAL
  )
''';

Future<Database> seedOrders(List<Map<String, Object?>> rows) async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute(_ordersSchema);
  final batch = db.batch();
  for (final r in rows) {
    batch.insert('orders', r);
  }
  await batch.commit(noResult: true);
  return db;
}

Future<Map<String, Object?>> row(Database db, int id) async =>
    (await db.query('orders', where: 'id = ?', whereArgs: [id])).first;

/// Captures the migration's audit output instead of appending to the real
/// Documents\cafeapp_crash_log.txt.
late List<String> logLines;
Future<void> captureLog(String message) async => logLines.add(message);

void main() {
  sqfliteFfiInit();

  setUp(() => logLines = <String>[]);

  group('payment method canonicalisation', () {
    tearDown(() => AppLocalization().setLanguage('en'));

    test('English labels map to canonical codes', () {
      AppLocalization().setLanguage('en');
      expect(canonicalise('Cash'.tr()), 'cash');
      expect(canonicalise('Bank'.tr()), 'bank');
      expect(canonicalise('Bank + Cash'.tr()), 'bank+cash');
      expect(canonicalise('Customer Credit'.tr()), 'customer_credit');
    });

    test('Arabic labels map to the SAME canonical codes - the shipped bug', () {
      AppLocalization().setLanguage('ar');

      // Guard the premise: these really are different strings, otherwise the
      // test proves nothing.
      expect('Bank'.tr(), isNot('Bank'));
      expect('Bank'.tr(), 'بنك');

      expect(canonicalise('Cash'.tr()), 'cash');
      expect(canonicalise('Bank'.tr()), 'bank');
      expect(canonicalise('Bank + Cash'.tr()), 'bank+cash');
      expect(canonicalise('Customer Credit'.tr()), 'customer_credit');
    });

    test('the old logic really did fail in Arabic', () {
      AppLocalization().setLanguage('ar');
      // What tender_screen used to do.
      final old = 'Bank'.tr().toLowerCase();
      expect(old, isNot('bank'),
          reason: 'if this ever equals "bank" the bug could not have happened');

      // And therefore neither branch fired, leaving both amounts at zero.
      var cash = 0.0, bank = 0.0;
      if (old == 'cash') {
        cash += 100;
      } else if (old == 'bank') {
        bank += 100;
      }
      expect(cash, 0);
      expect(bank, 0);
    });

    test('already-canonical values pass through unchanged', () {
      AppLocalization().setLanguage('ar');
      expect(canonicalise('cash'), 'cash');
      expect(canonicalise('bank'), 'bank');
      expect(canonicalise('customer_credit'), 'customer_credit');
    });
  });

  group('v18 repair migration', () {
    test('normalises Arabic methods and backfills unambiguous amounts',
        () async {
      final db = await seedOrders([
        // Arabic bank sale, fully paid, no deposit -> repair + backfill.
        {'id': 1, 'payment_method': 'بنك', 'total': 50.0, 'status': 'completed'},
        // Arabic cash sale -> repair + backfill.
        {'id': 2, 'payment_method': 'نقدي', 'total': 30.0, 'status': 'completed'},
      ]);

      await repairTranslatedPaymentMethods(db, log: captureLog);

      final r1 = await row(db, 1);
      expect(r1['payment_method'], 'bank');
      expect(r1['bank_amount'], 50.0);
      expect(r1['cash_amount'], isNull, reason: 'cash side must stay untouched');

      final r2 = await row(db, 2);
      expect(r2['payment_method'], 'cash');
      expect(r2['cash_amount'], 30.0);

      // The audit trail must state what was actually changed - it is the only
      // record a support engineer has after the fact.
      expect(logLines.single, contains('normalised 2 payment_method values'));
      expect(logLines.single, contains('cash_amount on 1'));
      expect(logLines.single, contains('bank_amount on 1'));

      await db.close();
    });

    test('never guesses a split: bank+cash amounts are left alone', () async {
      final db = await seedOrders([
        {
          'id': 1,
          'payment_method': 'بنك + نقد',
          'total': 80.0,
          'status': 'completed'
        },
      ]);

      await repairTranslatedPaymentMethods(db, log: captureLog);

      final r = await row(db, 1);
      expect(r['payment_method'], 'bank+cash', reason: 'method is still fixed');
      expect(r['cash_amount'], isNull, reason: 'split cannot be reconstructed');
      expect(r['bank_amount'], isNull);

      await db.close();
    });

    test('skips deposit-bearing orders, where total != amount taken', () async {
      final db = await seedOrders([
        {
          'id': 1,
          'payment_method': 'بنك',
          'total': 100.0,
          'deposit_amount': 40.0,
          'status': 'completed'
        },
      ]);

      await repairTranslatedPaymentMethods(db, log: captureLog);

      final r = await row(db, 1);
      expect(r['payment_method'], 'bank');
      expect(r['bank_amount'], isNull,
          reason: 'total overstates what was taken at the till');

      await db.close();
    });

    test('skips unpaid orders and does not disturb correct rows', () async {
      final db = await seedOrders([
        {'id': 1, 'payment_method': 'بنك', 'total': 20.0, 'status': 'pending'},
        {
          'id': 2,
          'payment_method': 'bank',
          'total': 60.0,
          'bank_amount': 60.0,
          'status': 'completed'
        },
      ]);

      await repairTranslatedPaymentMethods(db, log: captureLog);

      final pending = await row(db, 1);
      expect(pending['payment_method'], 'bank');
      expect(pending['bank_amount'], isNull, reason: 'not paid yet');

      final good = await row(db, 2);
      expect(good['payment_method'], 'bank');
      expect(good['bank_amount'], 60.0, reason: 'already correct, untouched');

      await db.close();
    });

    test('is idempotent - running twice changes nothing further', () async {
      final db = await seedOrders([
        {'id': 1, 'payment_method': 'بنك', 'total': 50.0, 'status': 'completed'},
      ]);

      await repairTranslatedPaymentMethods(db, log: captureLog);
      final afterFirst = await row(db, 1);
      await repairTranslatedPaymentMethods(db, log: captureLog);
      final afterSecond = await row(db, 1);

      expect(afterSecond['payment_method'], afterFirst['payment_method']);
      expect(afterSecond['bank_amount'], afterFirst['bank_amount']);
      expect(afterSecond['bank_amount'], 50.0,
          reason: 'must not double up on a second run');

      await db.close();
    });
  });
}
