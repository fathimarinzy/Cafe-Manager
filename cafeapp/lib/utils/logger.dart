
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// 📝 Simple file logger for debugging crashes.
//
// This used to hardcode '%UserProfile%\Documents\cafeapp_crash_log.txt', which
// silently produced no log at all on a customer machine. Two things combined:
//
//   1. With OneDrive's Known Folder Move — the default on Windows 11 with a
//      Microsoft account — Documents is redirected to
//      %UserProfile%\OneDrive\Documents, and the plain %UserProfile%\Documents
//      frequently does not exist. writeAsString creates a missing *file* but
//      never a missing *parent directory*, so every write threw.
//   2. The catch below reports through debugPrint, and a windowed release build
//      has no console attached. So the failure was completely invisible.
//
// The fix is to resolve the directory the same way the rest of the app already
// does (path_provider → SHGetKnownFolderPath, which follows the redirection),
// create it if absent, and fall back through candidates until one accepts a
// write. A log in a second-choice location beats no log.

const String _logFileName = 'cafeapp_crash_log.txt';

/// Cached as a Future so concurrent early callers resolve once, not N times.
Future<String?>? _logPathFuture;

/// Absolute path of the active log file, or null if nothing was writable.
///
/// Exposed so the app can *show* support where the log is instead of everyone
/// guessing — which is what made this bug take so long to notice.
Future<String?> logFilePath() => _logPathFuture ??= _resolveLogFile();

Future<String?> _resolveLogFile() async {
  for (final dirPath in await _candidateDirectories()) {
    if (dirPath == null || dirPath.isEmpty) continue;
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('$dirPath${Platform.pathSeparator}$_logFileName');
      // An empty append proves the path is genuinely writable and creates the
      // file if missing, without disturbing existing content.
      await file.writeAsString('', mode: FileMode.append);
      // Seeded once here so no later write has to stat the file.
      _currentLogBytes = await file.length();
      return file.path;
    } catch (_) {
      // Try the next candidate.
    }
  }
  return null;
}

/// Redirects logging into [path] and forgets any resolved location.
///
/// Exists so tests can exercise rotation without appending to the developer's
/// real Documents\cafeapp_crash_log.txt, which every suite here is careful not
/// to touch. Pass null to restore normal resolution.
@visibleForTesting
Future<void> setLogFileForTesting(String? path) async {
  await _logTail; // let any in-flight write finish against the old path
  _logPathFuture = path == null ? null : Future<String?>.value(path);
  _currentLogBytes = 0;
  if (path != null) {
    final file = File(path);
    if (await file.exists()) _currentLogBytes = await file.length();
  }
}

/// Bytes the live log may reach before rotating. Lowered by tests so rotation
/// can be exercised without writing 5 MB.
@visibleForTesting
set maxLogBytesForTesting(int value) => _maxLogBytes = value;

@visibleForTesting
int get maxLogBytes => _maxLogBytes;

/// Ordered best-first. The real Documents folder comes first so existing
/// installs keep appending to the file they already have.
Future<List<String?>> _candidateDirectories() async {
  final candidates = <String?>[];

  // 1. The real Documents folder. On Windows path_provider goes through
  //    SHGetKnownFolderPath, so this follows OneDrive Known Folder Move.
  try {
    candidates.add((await getApplicationDocumentsDirectory()).path);
  } catch (_) {}

  // 2. Per-user app data. Never redirected, always writable, and it exists even
  //    when the binding is too early for anything else to be reliable.
  try {
    candidates.add((await getApplicationSupportDirectory()).path);
  } catch (_) {}

  // 3. The original hardcoded guess, so a machine where it *did* work keeps
  //    using the same file even if path_provider is unavailable.
  if (Platform.isWindows) {
    final userProfile = Platform.environment['UserProfile'];
    if (userProfile != null && userProfile.isNotEmpty) {
      candidates.add('$userProfile\\Documents');
    }
  }

  // 4. Last resort. Somewhere is better than nowhere when diagnosing a crash.
  try {
    candidates.add(Directory.systemTemp.path);
  } catch (_) {}

  return candidates;
}

// ── size cap ─────────────────────────────────────────────────────────────────
// Until the OneDrive fix above, this log silently wrote nothing on many customer
// machines, so it never grew. Now that it works everywhere it grows on every
// till: a cafe taking 300 orders a day writes ~600 payment lines a day, roughly
// 20-30 MB a year, unbounded.
//
// Rotation keeps the newest [_maxLogBytes] plus one previous file, so support
// always has recent history and disk use is bounded at ~2x the cap.

/// 5 MB per file, two files. At ~100 bytes a line that is ~50,000 lines each -
/// months of history for a busy cafe, and small enough to attach to an email.
int _maxLogBytes = 5 * 1024 * 1024;

/// Running size of the live log, tracked in memory so the steady-state write
/// path costs no extra stat call. Seeded once from disk when the path resolves.
int _currentLogBytes = 0;

/// Serialises writes. Two concurrent calls could otherwise interleave around a
/// rotation - one renaming the file while the other holds a handle to it -
/// leaving lines in the wrong file or lost entirely.
Future<void> _logTail = Future<void>.value();

Future<void> logErrorToFile(String message) {
  if (!Platform.isWindows) {
    debugPrint(message);
    return Future<void>.value();
  }

  final line = '[${DateTime.now().toIso8601String()}] $message\n';
  // Timestamped before queueing so the log reflects when something happened,
  // not when the writer got round to it.
  _logTail = _logTail.then((_) => _append(line)).catchError((Object _) {});
  return _logTail;
}

Future<void> _append(String line) async {
  try {
    final path = await logFilePath();
    if (path == null) {
      // Nothing was writable. Still surface it in debug builds rather than
      // dropping the message entirely.
      debugPrint(line.trimRight());
      return;
    }

    final file = File(path);
    final bytes = utf8.encode(line).length;

    if (_currentLogBytes + bytes > _maxLogBytes) {
      await _rotate(file);
    }

    await file.writeAsString(line, mode: FileMode.append);
    _currentLogBytes += bytes;
  } catch (e) {
    debugPrint('Failed to write log: $e');
  }
}

/// Moves the live log aside so a fresh one starts. Best-effort: if any of this
/// fails we keep appending to the existing file rather than losing the message,
/// which is why [_currentLogBytes] is only reset on success.
Future<void> _rotate(File file) async {
  try {
    final backup = File('${file.path}.1');
    if (await backup.exists()) {
      await backup.delete();
    }
    if (await file.exists()) {
      await file.rename(backup.path);
    }
    _currentLogBytes = 0;
  } catch (e) {
    debugPrint('Log rotation failed, continuing in place: $e');
    // Reset anyway so a permanently un-rotatable file does not attempt a
    // rename on every single write from here on.
    _currentLogBytes = 0;
  }
}
