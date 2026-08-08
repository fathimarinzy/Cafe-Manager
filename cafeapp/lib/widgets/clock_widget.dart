import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A self-contained clock.
///
/// Prefer this over giving a screen its own `Timer.periodic` + `setState`: this
/// widget is a leaf, so a tick only rebuilds the `Text` rather than the whole
/// screen, and it only calls `setState` when the rendered string actually
/// changes (an `hh:mm a` clock therefore rebuilds once a minute, not 60 times).
class ClockWidget extends StatefulWidget {
  final TextStyle? style;

  /// `DateFormat` pattern for the displayed time, e.g. `'hh:mm a'`,
  /// `'h:mm a'`, `'hh:mm:ss a'`.
  final String pattern;

  const ClockWidget({
    super.key,
    this.style,
    this.pattern = 'hh:mm a',
  });

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  late DateFormat _formatter;
  late String _currentTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _formatter = DateFormat(widget.pattern);
    _currentTime = _formatter.format(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  @override
  void didUpdateWidget(ClockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pattern != widget.pattern) {
      _formatter = DateFormat(widget.pattern);
      _updateTime();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    if (!mounted) return;

    final formatted = _formatter.format(DateTime.now());

    // Only rebuild when the displayed text differs - a minute-granularity
    // clock would otherwise rebuild 59 times for no visible change.
    if (_currentTime != formatted) {
      setState(() {
        _currentTime = formatted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _currentTime,
      style: widget.style ?? const TextStyle(color: Colors.black),
    );
  }
}
