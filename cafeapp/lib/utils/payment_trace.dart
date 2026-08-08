import 'logger.dart';

/// Stage timing for a single payment, written as one log line.
///
/// Why buffer instead of logging each stage: logErrorToFile opens, appends and
/// closes the file per call, which costs a few milliseconds. Calling it at
/// every stage would add latency to the exact path we are trying to measure.
/// So stages accumulate in memory and a single line is written at the end.
///
/// The output lands in Documents\cafeapp_crash_log.txt, which persists in
/// release builds (debugPrint does not - a windowed release build has no
/// console attached). A support engineer can read the culprit straight off it:
///
///   ⏱️ payment[bank] total=4231ms load=3 save=7 status=15 print=4180 pdf=0
///      table=11 cleanup=2 | printed=false
///
/// Here the print stage is obviously the problem, not the database work.
typedef TraceWriter = Future<void> Function(String line);

class PaymentTrace {
  /// Set false to silence payment timing without touching call sites.
  static bool enabled = true;

  final String _label;
  final TraceWriter _write;
  final Stopwatch _sw = Stopwatch()..start();
  final List<String> _stages = <String>[];
  int _lastMs = 0;
  bool _flushed = false;

  /// Prefix in the emitted line, so unrelated traces stay greppable apart.
  /// Defaults to 'payment'; the order list uses 'orders'.
  final String _category;

  /// [writer] defaults to the persistent crash-log appender; tests pass a
  /// capturing function so they never touch the user's real log file.
  PaymentTrace(this._label, {TraceWriter? writer, String category = 'payment'})
      : _write = writer ?? logErrorToFile,
        _category = category;

  /// Records the time since the previous mark (or since construction).
  void mark(String stage) {
    if (!enabled) return;
    final now = _sw.elapsedMilliseconds;
    _stages.add('$stage=${now - _lastMs}');
    _lastMs = now;
  }

  /// True once the summary line has been emitted.
  bool get flushed => _flushed;

  /// Elapsed so far. Lets a caller decide whether a line is worth writing at
  /// all - the order list uses it to skip logging fast, repeated refreshes.
  int get elapsedMs => _sw.elapsedMilliseconds;

  /// The line [flush] would write. Split out so it can be asserted on without
  /// writing to the real crash log.
  String buildLine({String? outcome}) {
    final buffer =
        StringBuffer('⏱️ $_category[$_label] total=${_sw.elapsedMilliseconds}ms');
    if (_stages.isNotEmpty) {
      buffer.write(' ${_stages.join(' ')}');
    }
    if (outcome != null && outcome.isNotEmpty) {
      buffer.write(' | $outcome');
    }
    return buffer.toString();
  }

  /// Writes the single summary line. Safe to call more than once - only the
  /// first call emits, so putting this in a `finally` alongside an earlier
  /// explicit call will not double-log.
  Future<void> flush({String? outcome}) async {
    if (!enabled || _flushed) return;
    _flushed = true;
    _sw.stop();
    await _write(buildLine(outcome: outcome));
  }
}
