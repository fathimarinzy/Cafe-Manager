// lib/utils/demo_check_mixin.dart
import 'package:flutter/material.dart';
import '../services/demo_service.dart';

mixin DemoCheckMixin<T extends StatefulWidget> on State<T> {
  bool _isDemoMode = false;
  bool _isDemoExpired = false;
  int _remainingDays = 0;

  bool get isDemoMode => _isDemoMode;
  bool get isDemoExpired => _isDemoExpired;
  int get remainingDays => _remainingDays;

  @override
  void initState() {
    super.initState();
    _checkDemoStatus();
  }

  Future<void> _checkDemoStatus() async {
    final isDemoMode = await DemoService.isDemoMode();
    final isDemoExpired = await DemoService.isDemoExpired();
    final remainingDays = await DemoService.getRemainingDemoDays();

    if (mounted) {
      setState(() {
        _isDemoMode = isDemoMode;
        _isDemoExpired = isDemoExpired;
        _remainingDays = remainingDays;
      });

      // Call the demo status changed callback if it exists
      onDemoStatusChanged();
    }
  }

  // Override this method in widgets that need to respond to demo status changes
  void onDemoStatusChanged() {}

  // Helper method to show demo expired message
  void showDemoExpiredMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demo expired. Please contact support to continue using this feature.'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  // Helper method to check if a feature should be disabled
  bool isFeatureDisabled() {
    return _isDemoExpired;
  }

  // Refresh demo status
  Future<void> refreshDemoStatus() async {
    await _checkDemoStatus();
  }
}