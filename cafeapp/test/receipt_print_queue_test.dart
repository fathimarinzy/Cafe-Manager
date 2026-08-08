// Tests for the receipt queue that took printing off the payment critical path.
//
// Measured before the change: a payment cost ~1340ms with a working printer,
// of which the database was 10ms. Printing was 99% of it.
//
// Every test drives the queue through its `runner`, `onFailure` and `logWriter`
// seams, so no CafePrinter.exe is ever launched, no widget tree is needed, and
// (like the other suites here) the user's real Documents\cafeapp_crash_log.txt
// is never appended to.
//
//   flutter test test/receipt_print_queue_test.dart --no-pub

import 'package:flutter_test/flutter_test.dart';
import 'package:cafeapp/models/order_history.dart';
import 'package:cafeapp/services/receipt_job.dart';
import 'package:cafeapp/services/receipt_print_queue.dart';
import 'package:cafeapp/services/thermal_printer_service.dart';

ReceiptJob _job(String orderNumber) => ReceiptJob(
      label: 'cash',
      printOrder: OrderHistory(
        id: 1,
        serviceType: 'Dining - Table 4',
        total: 10.0,
        status: 'completed',
        createdAt: DateTime(2026, 8, 4),
        items: const [],
      ),
      isEdited: false,
      taxRate: 5.0,
      discount: 0.0,
      pdfItems: const [],
      serviceType: 'Dining - Table 4',
      orderNumber: orderNumber,
      subtotal: 10.0,
      tax: 0.5,
      total: 10.5,
      depositAmount: null,
      deliveryCharge: null,
    );

void main() {
  late List<String> logged;

  setUp(() {
    logged = <String>[];
    ReceiptPrintQueue.logWriter = (line) async => logged.add(line);
    ReceiptPrintQueue.onFailure = (_) {};
    ReceiptPrintQueue.asyncEnabled = true;
    ThermalPrinterService.lastPrintTiming = null;
    ThermalPrinterService.lastPrintError = null;
  });

  tearDown(() async {
    // Let any queued work finish before the next test rebinds the seams.
    await ReceiptPrintQueue.idle;
    ReceiptPrintQueue.runner = (job) => job.print();
    ReceiptPrintQueue.onFailure = ReceiptPrintQueue.showFailureBanner;
    ReceiptPrintQueue.logWriter = ReceiptPrintQueue.defaultLogWriter;
  });

  test('enqueue returns before the job runs - the property this all rests on',
      () async {
    var started = false;
    ReceiptPrintQueue.runner = (job) async {
      started = true;
      return true;
    };

    ReceiptPrintQueue.enqueue(_job('0001'));

    // Synchronously after enqueue, nothing has run. If this ever fails, the
    // payment path is awaiting the printer again and the ~1340ms is back.
    expect(started, isFalse);

    await ReceiptPrintQueue.idle;
    expect(started, isTrue);
  });

  test('jobs run one at a time, in submission order', () async {
    final order = <String>[];
    ReceiptPrintQueue.runner = (job) async {
      order.add('start:${job.orderNumber}');
      // Staggered so a concurrent implementation would interleave: 0001 sleeps
      // longest and would finish last.
      await Future<void>.delayed(
          Duration(milliseconds: 30 - 10 * int.parse(job.orderNumber)));
      order.add('end:${job.orderNumber}');
      return true;
    };

    ReceiptPrintQueue.enqueue(_job('1'));
    ReceiptPrintQueue.enqueue(_job('2'));
    ReceiptPrintQueue.enqueue(_job('3'));
    await ReceiptPrintQueue.idle;

    expect(order, [
      'start:1', 'end:1',
      'start:2', 'end:2',
      'start:3', 'end:3',
    ]);
  });

  test('a throwing job does not wedge the chain', () async {
    // The one that matters most: a wedged chain would silently stop every
    // later receipt with no visible symptom at all.
    final ran = <String>[];
    ReceiptPrintQueue.runner = (job) async {
      ran.add(job.orderNumber);
      if (job.orderNumber == '1') throw StateError('printer exploded');
      return true;
    };

    ReceiptPrintQueue.enqueue(_job('1'));
    ReceiptPrintQueue.enqueue(_job('2'));
    await ReceiptPrintQueue.idle;

    expect(ran, ['1', '2']);
    expect(logged.join('\n'), contains('printer exploded'));
  });

  test('a job returning false is reported once, with the order number',
      () async {
    final failures = <String>[];
    ReceiptPrintQueue.onFailure = (job) => failures.add(job.orderNumber);
    ReceiptPrintQueue.runner = (_) async => false;

    ReceiptPrintQueue.enqueue(_job('0042'));
    await ReceiptPrintQueue.idle;

    expect(failures, ['0042']);
    expect(logged.where((l) => l.contains('Receipt not printed')).length, 1);
  });

  test('a successful job reports no failure', () async {
    var notified = false;
    ReceiptPrintQueue.onFailure = (_) => notified = true;
    ReceiptPrintQueue.runner = (_) async => true;

    ReceiptPrintQueue.enqueue(_job('0001'));
    await ReceiptPrintQueue.idle;

    expect(notified, isFalse);
    expect(logged.where((l) => l.contains('Receipt not printed')), isEmpty);
  });

  test('each job logs its own trace line, off the payment line', () async {
    ReceiptPrintQueue.runner = (_) async => true;

    ReceiptPrintQueue.enqueue(_job('0007'));
    await ReceiptPrintQueue.idle;

    final trace = logged.singleWhere((l) => l.startsWith('⏱️'));
    // Pins the grep the verification depends on.
    expect(trace, startsWith('⏱️ payment[print:cash]'));
    expect(trace, contains('queue_wait='));
    expect(trace, contains('print='));
    expect(trace, contains('printed=true order=0007'));
    // Wall clock of when printing began. The line's own timestamp is written
    // when it *finished*, so without this a receipt cannot be lined up against
    // the payment that queued it.
    expect(trace, matches(RegExp(r'start=\d{2}:\d{2}:\d{2}\.\d{3}')));
  });

  test('queue_wait separates time spent waiting from time spent printing',
      () async {
    // Two jobs, the first slow. The second cannot start until the first ends,
    // so its wait must show up as queue_wait rather than inflating print=.
    ReceiptPrintQueue.runner = (job) async {
      if (job.orderNumber == '1') {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      return true;
    };

    ReceiptPrintQueue.enqueue(_job('1'));
    ReceiptPrintQueue.enqueue(_job('2'));
    await ReceiptPrintQueue.idle;

    final traces = logged.where((l) => l.startsWith('⏱️')).toList();
    expect(traces.length, 2);

    int stage(String line, String name) =>
        int.parse(RegExp('$name=(\\d+)').firstMatch(line)!.group(1)!);

    // The head of the chain waits on nobody.
    expect(stage(traces[0], 'queue_wait'), lessThan(50));
    expect(stage(traces[0], 'print'), greaterThanOrEqualTo(100));

    // The one behind it waited, but printed instantly. If these two ever swap,
    // the log would blame the printer for a queueing problem.
    expect(stage(traces[1], 'queue_wait'), greaterThanOrEqualTo(100));
    expect(stage(traces[1], 'print'), lessThan(50));
  });

  test('an exe breakdown is folded in when CafePrinter reports one', () async {
    ReceiptPrintQueue.runner = (_) async {
      ThermalPrinterService.lastPrintTiming =
          'boot=310 json=4 gate=3 render=205 submit=28 verify=705 exe=945';
      return true;
    };

    ReceiptPrintQueue.enqueue(_job('0007'));
    await ReceiptPrintQueue.idle;

    final trace = logged.singleWhere((l) => l.startsWith('⏱️'));
    // boot= is launch cost, verify= is us waiting on an already-printed
    // receipt. Separating them is the whole point of the exe reporting.
    expect(trace, contains('exe(boot=310'));
    expect(trace, contains('verify=705'));
  });

  test('spawn= names the time CafePrinter did not account for', () async {
    // The exe claims 70+300=370ms of its own; the runner takes ~500ms. The
    // remainder is process spawn, .NET shutdown and isolate scheduling.
    ReceiptPrintQueue.runner = (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      ThermalPrinterService.lastPrintTiming = 'boot=70 json=40 exe=300';
      return true;
    };

    ReceiptPrintQueue.enqueue(_job('0007'));
    await ReceiptPrintQueue.idle;

    final trace = logged.singleWhere((l) => l.startsWith('⏱️'));
    final spawn =
        int.parse(RegExp(r'spawn=(\d+)').firstMatch(trace)!.group(1)!);
    // 500 - 370 = 130, with scheduling slack either side.
    expect(spawn, greaterThan(50));
    expect(spawn, lessThan(400));
  });

  test('spawn= is omitted when the exe reported nothing usable', () async {
    ReceiptPrintQueue.runner = (_) async => true;

    // No timing at all (e.g. a non-Windows path, or an older exe).
    ReceiptPrintQueue.enqueue(_job('0007'));
    await ReceiptPrintQueue.idle;
    expect(logged.singleWhere((l) => l.startsWith('⏱️')),
        isNot(contains('spawn=')));

    // Present but missing the fields the arithmetic needs.
    logged.clear();
    ReceiptPrintQueue.runner = (_) async {
      ThermalPrinterService.lastPrintTiming = 'render=12 submit=8';
      return true;
    };
    ReceiptPrintQueue.enqueue(_job('0008'));
    await ReceiptPrintQueue.idle;
    expect(logged.singleWhere((l) => l.startsWith('⏱️')),
        isNot(contains('spawn=')));
  });

  test('spawn= never renders negative', () async {
    // The exe claims more time than the whole print took. Clock granularity
    // makes this reachable on a fast print; a negative would look like a bug in
    // the instrumentation rather than in what it measures.
    ReceiptPrintQueue.runner = (_) async {
      ThermalPrinterService.lastPrintTiming = 'boot=5000 exe=5000';
      return true;
    };

    ReceiptPrintQueue.enqueue(_job('0007'));
    await ReceiptPrintQueue.idle;

    expect(logged.singleWhere((l) => l.startsWith('⏱️')), contains('spawn=0'));
  });

  test('a stale exe breakdown cannot be attributed to the next receipt',
      () async {
    ThermalPrinterService.lastPrintTiming = 'boot=999 exe=999';
    // A print that never reaches the .NET path leaves the static untouched.
    ReceiptPrintQueue.runner = (_) async => true;

    ReceiptPrintQueue.enqueue(_job('0008'));
    await ReceiptPrintQueue.idle;

    final trace = logged.singleWhere((l) => l.startsWith('⏱️'));
    expect(trace, isNot(contains('boot=999')));
  });

  test('runInline awaits the job, restoring the pre-change behaviour', () async {
    var done = false;
    ReceiptPrintQueue.runner = (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      done = true;
      return true;
    };

    await ReceiptPrintQueue.runInline(_job('0001'));

    // The kill switch is only a real revert path if the caller actually waits.
    expect(done, isTrue);
  });
}
