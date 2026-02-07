
import 'dart:io';
import 'package:flutter/foundation.dart';

// 📝 Simple file logger for debugging crashes
Future<void> logErrorToFile(String message) async {
  try {
    if (Platform.isWindows) {
      // 📂 Save to Documents folder (Guaranteed writable & easy to find)
      final userProfile = Platform.environment['UserProfile'];
      if (userProfile != null) {
        final logFile = File('$userProfile\\Documents\\cafeapp_crash_log.txt');
        final timestamp = DateTime.now().toIso8601String();
        // Use sync write for critical logs if possible, but async is standard
        await logFile.writeAsString('[$timestamp] $message\n', mode: FileMode.append);
        // debugPrint('📝 Written to log: ${logFile.path}');
      }
    } else {
      debugPrint(message);
    }
  } catch (e) {
    debugPrint('Failed to write log: $e');
  }
}
