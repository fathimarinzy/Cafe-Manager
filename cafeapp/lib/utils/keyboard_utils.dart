import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class KeyboardUtils {
  static File? _logFile;

  /// Gets or creates the log file in the user's local AppData directory.
  /// Path: %LOCALAPPDATA%\CafeApp\keyboard_log.txt
  static File _getLogFile() {
    if (_logFile != null) return _logFile!;
    try {
      final appData = Platform.environment['LOCALAPPDATA'] ?? Platform.environment['APPDATA'] ?? '';
      if (appData.isNotEmpty) {
        final logDir = Directory('$appData${Platform.pathSeparator}CafeApp');
        if (!logDir.existsSync()) {
          logDir.createSync(recursive: true);
        }
        _logFile = File('${logDir.path}${Platform.pathSeparator}keyboard_log.txt');
      } else {
        _logFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}keyboard_log.txt');
      }
    } catch (e) {
      _logFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}keyboard_log.txt');
    }
    return _logFile!;
  }

  /// Logs a message to both debug console and the log file.
  static Future<void> _log(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final line = '[$timestamp] $message';
    debugPrint(line);
    try {
      final file = _getLogFile();
      await file.writeAsString('$line\n', mode: FileMode.append);
    } catch (_) {}
  }

  /// Clears old log entries (keeps last 200 lines).
  static Future<void> _trimLog() async {
    try {
      final file = _getLogFile();
      if (await file.exists()) {
        final lines = await file.readAsLines();
        if (lines.length > 200) {
          final trimmed = lines.sublist(lines.length - 200);
          await file.writeAsString('${trimmed.join('\n')}\n');
        }
      }
    } catch (_) {}
  }

  /// Opens the on-screen keyboard using multiple fallback methods.
  static Future<void> openKeyboard() async {
    await _trimLog();
    await _log('=== openKeyboard() called ===');

    // Step 1: Always request the Flutter soft keyboard first
    try {
      await SystemChannels.textInput.invokeMethod('TextInput.show');
      await _log('✅ Requested Flutter soft keyboard');
    } catch (e) {
      await _log('❌ Flutter TextInput.show failed: $e');
    }

    // Step 2: On Windows, also try to open the system touch keyboard
    if (Platform.isWindows) {
      await _log('Platform: Windows - trying system keyboard methods');
      await _openWindowsKeyboard();
    } else {
      await _log('Platform: ${Platform.operatingSystem} - no extra methods needed');
    }

    await _log('=== openKeyboard() finished ===');
  }

  /// Tries multiple methods to open the Windows on-screen keyboard.
  static Future<void> _openWindowsKeyboard() async {
    // Method 1: PowerShell COM toggle via temp script file (most reliable for Win10/11)
    if (await _tryPowerShellToggle()) {
      await _log('✅ SUCCESS: Keyboard opened via PowerShell COM toggle');
      return;
    }

    // Method 2: Kill and restart TabTip.exe (forces keyboard to show)
    if (await _tryKillAndRestartTabTip()) {
      await _log('✅ SUCCESS: Keyboard opened via TabTip kill-restart');
      return;
    }

    // Method 3: Ensure Touch Keyboard service is running + TabTip.exe
    await _ensureTouchKeyboardService();
    if (await _tryTabTip()) {
      await _log('✅ SUCCESS: Keyboard opened via TabTip.exe');
      return;
    }

    // Method 4: Explorer shell GUID
    if (await _tryExplorerShell()) {
      await _log('✅ SUCCESS: Keyboard opened via Explorer shell');
      return;
    }

    // Method 5: Legacy osk.exe with proper paths
    if (await _tryOsk()) {
      await _log('✅ SUCCESS: Keyboard opened via osk.exe');
      return;
    }

    await _log('⚠️ FAILED: All keyboard opening methods failed!');
  }

  /// Uses PowerShell to invoke the Windows Touch Keyboard via COM interface.
  /// Writes the script to a temp file to avoid here-string parsing issues.
  static Future<bool> _tryPowerShellToggle() async {
    try {
      await _log('Method 1: Writing PowerShell COM script to temp file...');
      
      // Write the PowerShell script to a temp file to avoid
      // here-string terminator issues with inline strings
      final tempDir = Directory.systemTemp;
      final scriptFile = File('${tempDir.path}${Platform.pathSeparator}toggle_keyboard.ps1');
      
      await scriptFile.writeAsString(
r'''$source = @"
using System;
using System.Runtime.InteropServices;
public class TouchKeyboardToggler {
    [ComImport, Guid("4CE576FA-83DC-4F88-951C-9D0782B4E376")]
    class UIHostNoLaunch { }
    [ComImport, Guid("37c994e7-432b-4834-a2f7-dce1f13b834b")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface ITipInvocation {
        void Toggle(IntPtr desktopWindow);
    }
    [DllImport("user32.dll", SetLastError = false)]
    static extern IntPtr GetDesktopWindow();
    public static void Toggle() {
        var uiHost = new UIHostNoLaunch();
        var invocation = (ITipInvocation)uiHost;
        invocation.Toggle(GetDesktopWindow());
        Marshal.ReleaseComObject(invocation);
    }
}
"@
Add-Type -TypeDefinition $source
[TouchKeyboardToggler]::Toggle()
''');

      await _log('Method 1: Script written to ${scriptFile.path}');
      
      final result = await Process.run('powershell', [
        '-WindowStyle', 'Hidden',
        '-ExecutionPolicy', 'Bypass',
        '-File', scriptFile.path,
      ], runInShell: true);

      await _log('Method 1: PowerShell exit code ${result.exitCode}');
      if (result.stderr.toString().trim().isNotEmpty) {
        await _log('Method 1: stderr: ${result.stderr}');
      }
      if (result.stdout.toString().trim().isNotEmpty) {
        await _log('Method 1: stdout: ${result.stdout}');
      }

      // Clean up temp file
      try { await scriptFile.delete(); } catch (_) {}

      if (result.exitCode == 0) {
        return true;
      }
      return false;
    } catch (e) {
      await _log('Method 1: Exception: $e');
      return false;
    }
  }

  /// Kills any existing TabTip process and restarts it.
  /// This forces the keyboard to appear fresh on screen.
  static Future<bool> _tryKillAndRestartTabTip() async {
    try {
      await _log('Method 2: Kill and restart TabTip...');
      
      final tabTipPath = await _findTabTipPath();
      if (tabTipPath == null) {
        await _log('Method 2: TabTip.exe not found on this system');
        return false;
      }
      
      // Kill existing TabTip process
      final killResult = await Process.run(
        'taskkill', ['/F', '/IM', 'TabTip.exe'],
        runInShell: true,
      );
      await _log('Method 2: taskkill result: exit=${killResult.exitCode}');
      
      // Wait for process to fully terminate
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Restart TabTip fresh
      await Process.start(tabTipPath, [], runInShell: true);
      await _log('Method 2: TabTip restarted from $tabTipPath');
      
      // Give it a moment to show
      await Future.delayed(const Duration(milliseconds: 300));
      
      return true;
    } catch (e) {
      await _log('Method 2: Exception: $e');
      return false;
    }
  }

  /// Finds TabTip.exe on the system.
  static Future<String?> _findTabTipPath() async {
    final paths = [
      r'C:\Program Files\Common Files\microsoft shared\ink\TabTip.exe',
      r'C:\Program Files (x86)\Common Files\microsoft shared\ink\TabTip.exe',
    ];
    for (final path in paths) {
      if (await File(path).exists()) return path;
    }
    return null;
  }

  /// Ensures the Windows Touch Keyboard service is running.
  /// Tries both service names (Win10 and Win11 use different names).
  static Future<void> _ensureTouchKeyboardService() async {
    // Try Windows 10 service name
    try {
      await _log('Starting TabletInputService (Win10)...');
      final result1 = await Process.run(
        'net', ['start', 'TabletInputService'],
        runInShell: true,
      );
      await _log('TabletInputService result: exit=${result1.exitCode}');
      if (result1.exitCode == 0) {
        await Future.delayed(const Duration(milliseconds: 500));
        return;
      }
    } catch (e) {
      await _log('TabletInputService error: $e');
    }

    // Try Windows 11 service name
    try {
      await _log('Starting TextInputManagementService (Win11)...');
      final result2 = await Process.run(
        'net', ['start', 'TextInputManagementService'],
        runInShell: true,
      );
      await _log('TextInputManagementService result: exit=${result2.exitCode}');
      if (result2.exitCode == 0) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      await _log('TextInputManagementService error: $e');
    }
  }

  /// Tries to launch TabTip.exe from known installation paths.
  static Future<bool> _tryTabTip() async {
    final tabTipPath = await _findTabTipPath();
    if (tabTipPath != null) {
      try {
        await _log('Method 3: Launching TabTip: $tabTipPath');
        await Process.start(tabTipPath, [], runInShell: true);
        await _log('Method 3: TabTip launched');
        return true;
      } catch (e) {
        await _log('Method 3: TabTip failed: $e');
      }
    } else {
      await _log('Method 3: TabTip.exe not found');
    }
    return false;
  }

  /// Tries to open the touch keyboard via Windows Explorer shell GUID.
  static Future<bool> _tryExplorerShell() async {
    try {
      await _log('Method 4: Trying explorer shell GUID...');
      await Process.start(
        'explorer.exe',
        ['shell:::{054AAE20-4BEA-4347-8A35-64A533254A9D}'],
        runInShell: true,
      );
      await _log('Method 4: Explorer shell command sent');
      return true;
    } catch (e) {
      await _log('Method 4: Explorer shell failed: $e');
      return false;
    }
  }

  /// Tries to open the legacy On-Screen Keyboard (osk.exe).
  static Future<bool> _tryOsk() async {
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final paths = [
      '$systemRoot\\System32\\osk.exe',
      '$systemRoot\\Sysnative\\osk.exe',
      'osk.exe',
    ];

    for (final path in paths) {
      try {
        await _log('Method 5: Trying osk.exe at $path');
        await Process.start(path, [], runInShell: true);
        await _log('Method 5: osk.exe launched from $path');
        return true;
      } catch (e) {
        await _log('Method 5: osk.exe failed at $path: $e');
      }
    }
    return false;
  }
}

/// A widget that listens for double-tap gestures to open the on-screen keyboard.
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
  static const int _doubleTapThreshold = 500; // milliseconds

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

    await KeyboardUtils._log('Double tap detected - Opening Keyboard');
    
    // Request focus if a FocusNode is provided
    if (widget.focusNode != null && !widget.focusNode!.hasFocus) {
       widget.focusNode!.requestFocus();
       await Future.delayed(const Duration(milliseconds: 100));
    }
    
    await KeyboardUtils.openKeyboard();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kPrimaryButton || event.kind == PointerDeviceKind.touch) { 
           _handleTap();
        }
      },
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
