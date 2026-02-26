import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class KeyboardUtils {
  /// Opens the on-screen keyboard.
  /// 1. Uses Flutter's SystemChannels to request the soft keyboard.
  /// 2. On Windows, also tries to launch the touch keyboard (TabTip.exe)
  ///    or the legacy on-screen keyboard (osk.exe) as fallback.
  static Future<void> openKeyboard() async {
    // Step 1: Always request the Flutter soft keyboard first
    try {
      await SystemChannels.textInput.invokeMethod('TextInput.show');
      debugPrint('Requested Flutter soft keyboard');
    } catch (e) {
      debugPrint('Flutter TextInput.show failed: $e');
    }

    // Step 2: On Windows, also try to open the system touch keyboard
    if (Platform.isWindows) {
      await _openWindowsKeyboard();
    }
  }

  /// Tries multiple methods to open the Windows on-screen keyboard.
  static Future<void> _openWindowsKeyboard() async {
    // List of possible TabTip.exe paths
    final tabTipPaths = [
      'C:\\Program Files\\Common Files\\microsoft shared\\ink\\TabTip.exe',
      'C:\\Program Files (x86)\\Common Files\\microsoft shared\\ink\\TabTip.exe',
    ];

    // Try each TabTip path
    for (final path in tabTipPaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          debugPrint('Opening TabTip from: $path');
          await Process.start(path, [], runInShell: true);
          return; // Success, stop trying
        }
      } catch (e) {
        debugPrint('Failed to open TabTip at $path: $e');
      }
    }

    // Try launching tabtip via command (uses system PATH)
    try {
      debugPrint('Trying tabtip via explorer...');
      await Process.start(
        'explorer.exe',
        ['shell:::{054AAE20-4BEA-4347-8A35-64A533254A9D}'],
        runInShell: true,
      );
      return;
    } catch (e) {
      debugPrint('Failed to open via explorer shell: $e');
    }

    // Last resort: legacy osk.exe
    try {
      debugPrint('Attempting osk.exe...');
      await Process.start('osk.exe', [], runInShell: true);
    } catch (e) {
      debugPrint('Failed to open osk.exe: $e');
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
       // Wait a frame for focus to be established before requesting keyboard
       await Future.delayed(const Duration(milliseconds: 100));
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
