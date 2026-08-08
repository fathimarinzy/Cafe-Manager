import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

// Sends raw ESC/POS bytes to a Windows printer by delegating to CafePrinter.exe
// (a self-contained .NET 8 console app that uses PInvoke to winspool.drv).
// The exe must sit in the same directory as cafeapp.exe at runtime.
class WindowsRawPrinter {

  static String exePath() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return p.join(exeDir, 'CafePrinter.exe');
  }

  static Future<bool> isPrinterOnline(String printerName) async {
    try {
      final result = await Process.run(
        exePath(),
        ['check', printerName],
        runInShell: false,
      );
      debugPrint('[WRP] check "$printerName" → exit ${result.exitCode}  ${result.stderr}');
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('[WRP] isPrinterOnline exception: $e');
      return false;
    }
  }

  /// Clears the `%TEMP%\CafePrinter\<name>.unavailable` marker.
  ///
  /// The marker makes repeat orders during an outage fail instantly, but it also
  /// refuses a Test Print taken within the cooldown of a failure — exactly when
  /// the user has just reconnected the printer and wants to check. Called from
  /// testConnection so "Test Print" always means *actually test it*.
  static Future<void> clearCooldown(String printerName) async {
    try {
      await Process.run(
        exePath(),
        ['clear-cooldown', printerName],
        runInShell: false,
      );
    } catch (e) {
      // Best-effort: an old exe without this verb just exits non-zero, and the
      // test print proceeds as it does today.
      debugPrint('[WRP] clearCooldown exception: $e');
    }
  }

  static Future<bool> printBytes({
    required String printerName,
    required List<int> bytes,
    String jobName = 'Raw Print Job',
  }) async {
    if (!await isPrinterOnline(printerName)) {
      debugPrint('[WRP] Printer "$printerName" is offline, aborting');
      return false;
    }

    final tempFile = File(p.join(
      Directory.systemTemp.path,
      'cafe_print_${DateTime.now().millisecondsSinceEpoch}.bin',
    ));

    try {
      await tempFile.writeAsBytes(Uint8List.fromList(bytes), flush: true);
      final result = await Process.run(
        exePath(),
        ['print', printerName, tempFile.path],
        runInShell: false,
      );
      debugPrint(
        '[WRP] print "$printerName" (${bytes.length}B) → exit ${result.exitCode}  ${result.stderr}',
      );
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('[WRP] printBytes exception: $e');
      return false;
    } finally {
      try { await tempFile.delete(); } catch (_) {}
    }
  }
}
