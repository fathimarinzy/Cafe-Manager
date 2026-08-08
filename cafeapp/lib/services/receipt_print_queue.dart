import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_messenger.dart';
import '../utils/app_localization.dart';
import '../utils/logger.dart';
import '../utils/payment_trace.dart';
import 'cross_platform_pdf_service.dart';
import 'receipt_job.dart';
import 'thermal_printer_service.dart';

/// Runs receipt printing off the payment critical path.
///
/// Measured before this existed: a payment cost ~1340ms with a working printer
/// and up to ~3080ms with a dead one, of which the database was 10ms. Printing
/// was 99% of it. A receipt is not part of the financial transaction, so the
/// cashier should never wait on one.
///
/// Failures surface as a persistent [MaterialBanner] carrying a "Save PDF"
/// action. That replaces a modal AlertDialog which used to block the payment
/// and cost ~1.2-1.5s of the cashier's time on every failed print.
class ReceiptPrintQueue {
  ReceiptPrintQueue._();

  /// Jobs run one at a time, in submission order.
  ///
  /// Two payments seconds apart would otherwise launch two CafePrinter.exe
  /// processes concurrently, doubling cold-start cost and racing the spooler
  /// for job ordering. Chaining keeps receipts in the order they were paid.
  static Future<void> _tail = Future<void>.value();

  /// Set false to restore the pre-change behaviour: printing is awaited inline
  /// on the payment path, spinner and all. Backed by the `receipt_print_async`
  /// preference; this is the revert path if a site needs the cashier to watch
  /// the paper emerge.
  static bool asyncEnabled = true;

  /// Test seam. Lets the queue be exercised without launching a process.
  static Future<bool> Function(ReceiptJob job) runner = (job) => job.print();

  /// Test seam. Avoids depending on a live widget tree in unit tests.
  static void Function(ReceiptJob job) onFailure = showFailureBanner;

  /// Test seam. On Windows the default appends to the user's real
  /// Documents\cafeapp_crash_log.txt, which a test run must never do.
  static TraceWriter logWriter = defaultLogWriter;

  /// The production defaults, exposed so tests can restore them in tearDown.
  static Future<void> defaultLogWriter(String line) => logErrorToFile(line);

  static const String prefKey = 'receipt_print_async';

  /// Reads the kill switch. Called once at startup; failure to read leaves the
  /// default (async) in place rather than blocking payments on a prefs error.
  static Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      asyncEnabled = prefs.getBool(prefKey) ?? true;
      if (!asyncEnabled) {
        await logErrorToFile(
            '🖨️ receipt_print_async=false - printing runs inline');
      }
    } catch (_) {
      asyncEnabled = true;
    }
  }

  static Future<void> setAsyncEnabled(bool value) async {
    asyncEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
  }

  /// Queues [job] and returns immediately. Never throws.
  ///
  /// The synchronous return is the entire point: the caller's `await` chain is
  /// not extended, so payment completes as soon as the order is saved.
  static void enqueue(ReceiptJob job) {
    // Constructed here, not in _run, so the trace's stopwatch starts ticking at
    // submission. That is what makes queue_wait measurable at all: it is the
    // gap between this line and the job reaching the head of the chain.
    final trace = PaymentTrace('print:${job.label}', writer: logWriter);
    _tail = _tail.then((_) => _run(job, trace)).catchError((Object _) {});
  }

  /// Awaits the job inline. Used only when [asyncEnabled] is false.
  static Future<void> runInline(ReceiptJob job) =>
      _run(job, PaymentTrace('print:${job.label}', writer: logWriter));

  /// Completes when everything queued so far has finished. For tests; nothing
  /// on the payment path may await this.
  static Future<void> get idle => _tail;

  /// Runs one job and emits its own trace line, so the background cost stays
  /// measurable without being counted against the payment. Grep
  /// `payment[print:` to isolate it.
  ///
  /// The line answers "where did the time go" in one read:
  ///
  ///   ⏱️ payment[print:cash] total=1330ms queue_wait=2 print=1328
  ///      | printed=true order=0042 start=13:19:20.114
  ///        exe(boot=310 json=4 gate=3 render=205 submit=28 verify=705 exe=945)
  ///
  /// queue_wait = waiting behind another receipt; boot = launching
  /// CafePrinter.exe; render/submit = actually printing; verify = us waiting to
  /// confirm a print that has already reached the paper.
  static Future<void> _run(ReceiptJob job, PaymentTrace trace) async {
    trace.mark('queue_wait');

    // Wall clock, because the line's own timestamp is written at flush - i.e.
    // when printing *finished*. This is what lets a receipt be lined up against
    // the payment that queued it.
    final startedAt = DateTime.now();

    // The queue owns this measurement window; clear it so a print that never
    // reaches the .NET path cannot report a previous receipt's numbers.
    ThermalPrinterService.lastPrintTiming = null;
    ThermalPrinterService.lastPrintError = null;

    var printed = false;
    String? error;
    final sw = Stopwatch()..start();

    try {
      printed = await runner(job);
      // printThermalBill reports failure as `false`, not as a throw, so the
      // reason has to be read back off the service.
      if (!printed) error = ThermalPrinterService.lastPrintError;
    } catch (e) {
      error = '$e';
    } finally {
      sw.stop();
      trace.mark('print');
      final timing = ThermalPrinterService.lastPrintTiming;
      final spawn = _spawnMs(sw.elapsedMilliseconds, timing);
      await trace.flush(
        outcome: 'printed=$printed order=${job.orderNumber}'
            ' start=${DateFormat('HH:mm:ss.SSS').format(startedAt)}'
            '${timing != null ? ' exe($timing)' : ''}'
            '${spawn != null ? ' spawn=$spawn' : ''}'
            '${error != null ? ' error=$error' : ''}',
      );
    }

    if (!printed) {
      await logWriter(
        '🖨️ Receipt not printed for order ${job.orderNumber}'
        '${error != null ? ': $error' : ''}',
      );
      onFailure(job);
    }
  }

  /// Everything in the measured print that CafePrinter did not account for:
  /// process spawn, .NET shutdown, and any delay before this isolate gets to
  /// resolve the await.
  ///
  /// Normally 50-100ms. One customer print showed ~1.5s here against only 387ms
  /// of reported exe work, with no way to tell from the log whether the cause
  /// was outside the process or inside this isolate. Naming it makes the next
  /// occurrence diagnosable instead of mysterious.
  ///
  /// Returns null when the exe reported nothing parseable, and never returns a
  /// negative - stopwatch granularity can make the parts exceed the whole.
  static int? _spawnMs(int printMs, String? timing) {
    if (timing == null) return null;
    final boot = _field(timing, 'boot');
    final exe = _field(timing, 'exe');
    if (boot == null || exe == null) return null;
    final spawn = printMs - boot - exe;
    return spawn < 0 ? 0 : spawn;
  }

  static int? _field(String timing, String name) {
    final match = RegExp('(?:^| )$name=(-?\\d+)').firstMatch(timing);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static void showFailureBanner(ReceiptJob job) {
    showGlobalBanner(
      MaterialBanner(
        backgroundColor: Colors.orange.shade50,
        leading: Icon(Icons.print_disabled, color: Colors.orange.shade800),
        content: Text(
          '${'Receipt not printed'.tr()} (${job.orderNumber})',
          style: TextStyle(color: Colors.orange.shade900),
        ),
        actions: [
          TextButton(
            onPressed: () {
              hideGlobalBanner();
              // Deliberately does NOT retry printing - only builds the PDF.
              // Re-entering print() here could double-print a receipt that
              // actually succeeded but was misreported.
              _savePdf(job);
            },
            child: Text('Save PDF'.tr()),
          ),
          TextButton(
            onPressed: hideGlobalBanner,
            child: Text('Dismiss'.tr()),
          ),
        ],
      ),
    );
  }

  static Future<void> _savePdf(ReceiptJob job) async {
    try {
      final pdf = await job.buildPdf();
      // savePdf uses FilePicker's native dialog and needs no BuildContext,
      // which is what lets this work after the tender screen is disposed.
      await CrossPlatformPdfService.savePdf(
        pdf,
        suggestedFileName: job.suggestedFileName(),
      );
    } catch (e) {
      await logErrorToFile('📄 PDF save failed for ${job.orderNumber}: $e');
    }
  }
}
