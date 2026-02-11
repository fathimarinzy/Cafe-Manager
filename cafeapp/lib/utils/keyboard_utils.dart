import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class KeyboardUtils {
  /// Launches the Windows On-Screen Keyboard.
  /// Tries to open TabTip.exe first (modern touch keyboard),
  /// then falls back to osk.exe (legacy keyboard).
  static Future<void> openKeyboard() async {
    if (!Platform.isWindows) return;

    try {
      debugPrint('Attempting to open TabTip.exe...');
      // TabTip is the modern touch keyboard
      await Process.start(
        'C:\\Program Files\\Common Files\\microsoft shared\\ink\\TabTip.exe',
        [],
        runInShell: true,
      );
    } catch (e) {
      debugPrint('Failed to open TabTip: $e');
      try {
        debugPrint('Attempting to open osk.exe...');
        // Fallback to legacy OSK
        await Process.start('osk.exe', [], runInShell: true);
      } catch (e2) {
        debugPrint('Failed to open osk.exe: $e2');
      }
    }
  }
}

/// A widget that listens for double-tap gestures to open the on-screen keyboard.
/// This is designed to wrap input fields.
/// It checks the [SettingsProvider] to see if the feature is enabled.
class DoubleTapKeyboardListener extends StatefulWidget {
  final Widget child;
  final FocusNode? focusNode;

  const DoubleTapKeyboardListener({
    super.key,
    required this.child,
    this.focusNode,
  });

  @override
  State<DoubleTapKeyboardListener> createState() => _DoubleTapKeyboardListenerState();
}

class _DoubleTapKeyboardListenerState extends State<DoubleTapKeyboardListener> {
  int _lastTapTime = 0;
  static const int _doubleTapThreshold = 300; // milliseconds

  void _handleTap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapTime < _doubleTapThreshold) {
      _onDoubleTap();
      _lastTapTime = 0; // Reset
    } else {
      _lastTapTime = now;
    }
  }

  Future<void> _onDoubleTap() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.doubleTapToOpenKeyboard) return;

    debugPrint('Double tap detected - Opening Keyboard');
    
    // Request focus if a FocusNode is provided
    if (widget.focusNode != null && !widget.focusNode!.hasFocus) {
       widget.focusNode!.requestFocus();
    }
    
    await KeyboardUtils.openKeyboard();
  }

  @override
  Widget build(BuildContext context) {
    // We use a Listener to capture pointer events before they hit the child
    // This allows us to detect taps even on widgets that handle gestures (like TextField)
    return Listener(
      onPointerDown: (event) {
        // Only react to primary button (left click) or touch
        if (event.buttons == kPrimaryButton || event.kind == PointerDeviceKind.touch) { 
           _handleTap();
        }
      },
      behavior: HitTestBehavior.translucent, // Allow events to pass through
      child: widget.child,
    );
  }
}
