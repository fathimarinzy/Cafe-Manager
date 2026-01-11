import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ClockWidget extends StatefulWidget {
  final TextStyle? style;
  
  const ClockWidget({
    super.key,
    this.style,
  });

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  String _currentTime = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateFormat('hh:mm a').format(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateTime();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    final formatter = DateFormat('hh:mm a');
    final formatted = formatter.format(now);
    
    if (_currentTime != formatted) {
      setState(() {
        _currentTime = formatted;
      });
    }
  }

  // Initialize with current time to avoid late initialization error
  // Although initState calls _updateTime, it's safer to have a default or call it synchronously
  // Changed logic to initialize in variable declaration or constructor would be cleaner but 
  // initState serves fine here if we ensure _currentTime is assigned.
  // Actually, _currentTime must be initialized. 
  // Let's initialize it in initState before the timer.

  @override
  Widget build(BuildContext context) {
    return Text(
      _currentTime,
      style: widget.style ?? const TextStyle(color: Colors.black),
    );
  }
}