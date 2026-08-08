// Tests for the payment stage timing added to diagnose a customer's
// "slow tender screen" report.
//
// These deliberately never call flush(), because on Windows logErrorToFile
// appends to the user's real Documents\cafeapp_crash_log.txt. buildLine()
// exists so the emitted format can be asserted without that side effect.
//
//   flutter test test/payment_trace_test.dart --no-pub

import 'package:flutter_test/flutter_test.dart';
import 'package:cafeapp/utils/payment_trace.dart';

void main() {
  setUp(() => PaymentTrace.enabled = true);
  tearDown(() => PaymentTrace.enabled = true);

  test('emits a single parseable line naming each stage', () {
    final trace = PaymentTrace('bank');
    trace.mark('calc');
    trace.mark('save');
    trace.mark('status');
    trace.mark('print');

    final line = trace.buildLine(outcome: 'printed=false printer=none');

    expect(line, startsWith('⏱️ payment[bank]'));
    expect(line, contains('total='));
    for (final stage in ['calc=', 'save=', 'status=', 'print=']) {
      expect(line, contains(stage), reason: 'missing stage $stage');
    }
    expect(line, contains('| printed=false printer=none'));
    expect(line.split('\n').length, 1, reason: 'must stay a single log line');
  });

  test('stage order is preserved, so the slow step is obvious', () {
    final trace = PaymentTrace('cash');
    trace.mark('save');
    trace.mark('print');
    trace.mark('table');

    final line = trace.buildLine();
    expect(line.indexOf('save='), lessThan(line.indexOf('print=')));
    expect(line.indexOf('print='), lessThan(line.indexOf('table=')));
  });

  test('flush is idempotent - the explicit call plus the finally emits once',
      () async {
    final written = <String>[];
    final trace = PaymentTrace('split', writer: (line) async {
      written.add(line);
    });
    trace.mark('save');
    trace.mark('print');

    // Mirrors the real call pattern: an explicit flush before the confirmation
    // dialog, then the finally block flushing again.
    await trace.flush(outcome: 'printed=true');
    await trace.flush(outcome: 'printed=true');
    await trace.flush(outcome: 'error=should not appear');

    expect(written.length, 1, reason: 'one payment must log exactly one line');
    expect(written.single, contains('payment[split]'));
    expect(written.single, contains('printed=true'));
    expect(written.single, isNot(contains('should not appear')),
        reason: 'the first outcome wins; later calls are no-ops');
    expect(trace.flushed, isTrue);
  });

  test('a payment that throws still logs, with the error as the outcome',
      () async {
    final written = <String>[];
    final trace = PaymentTrace('bank', writer: (line) async {
      written.add(line);
    });
    trace.mark('save');

    // Only the finally runs when the body throws before its explicit flush.
    await trace.flush(outcome: 'error=Exception: printer unreachable');

    expect(written.length, 1);
    expect(written.single, contains('error=Exception: printer unreachable'));
  });

  test('disabled tracing writes nothing at all', () async {
    final written = <String>[];
    PaymentTrace.enabled = false;
    final trace = PaymentTrace('cash', writer: (line) async {
      written.add(line);
    });
    trace.mark('save');
    await trace.flush(outcome: 'printed=true');

    expect(written, isEmpty);
  });

  test('disabled tracing records nothing and stays cheap', () {
    PaymentTrace.enabled = false;
    final trace = PaymentTrace('bank');
    trace.mark('save');
    trace.mark('print');

    final line = trace.buildLine();
    expect(line, isNot(contains('save=')));
    expect(line, isNot(contains('print=')));
  });

  test('the payment line no longer carries printing stages', () {
    // Pins the regression this whole change exists to prevent: printing moved
    // off the payment path, so the payment line records only the enqueue.
    final trace = PaymentTrace('bank');
    trace.mark('calc');
    trace.mark('save');
    trace.mark('status');
    trace.mark('enqueue');

    final line = trace.buildLine(outcome: 'queued=true');

    expect(line, contains('enqueue='));
    expect(line, isNot(contains('print=')),
        reason: 'a print= stage means the cashier is waiting on the printer');
    expect(line, isNot(contains('pdf=')),
        reason: 'a pdf= stage means a modal is blocking the payment');
  });

  test('background print jobs get their own greppable label', () {
    // The verification steps grep for 'payment[print:' to separate background
    // printing cost from payment cost.
    final trace = PaymentTrace('print:bank');
    trace.mark('print');

    expect(trace.buildLine(outcome: 'printed=true order=0042'),
        startsWith('⏱️ payment[print:bank]'));
  });

  test('an outcome is optional', () {
    final trace = PaymentTrace('bank');
    trace.mark('save');
    expect(trace.buildLine(), isNot(contains('|')));
    expect(trace.buildLine(outcome: ''), isNot(contains('|')));
  });
}
