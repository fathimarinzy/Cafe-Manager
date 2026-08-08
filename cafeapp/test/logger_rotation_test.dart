// Tests for the crash log's size cap.
//
// Until the OneDrive path fix, this log silently wrote nothing on many customer
// machines, so it never grew. Now that it works everywhere it grows on every
// till - hence rotation, and hence these tests.
//
// Every test redirects logging into a temp directory via setLogFileForTesting,
// so the developer's real Documents\cafeapp_crash_log.txt is never touched.
//
//   flutter test test/logger_rotation_test.dart --no-pub

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cafeapp/utils/logger.dart';

void main() {
  late Directory tempDir;
  late File logFile;
  late File backupFile;
  final originalMax = maxLogBytes;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cafeapp_log_test');
    logFile = File('${tempDir.path}${Platform.pathSeparator}test_log.txt');
    backupFile = File('${logFile.path}.1');
    await setLogFileForTesting(logFile.path);
  });

  tearDown(() async {
    maxLogBytesForTesting = originalMax;
    await setLogFileForTesting(null);
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('writes land in the redirected file, timestamped', () async {
    await logErrorToFile('hello');

    final content = await logFile.readAsString();
    expect(content, contains('hello'));
    expect(content, matches(RegExp(r'^\[\d{4}-\d{2}-\d{2}T')));
    expect(content, endsWith('\n'));
  }, onPlatform: const {'!windows': Skip('logErrorToFile only writes on Windows')});

  test('rotates once the cap is passed, keeping the newest lines', () async {
    maxLogBytesForTesting = 200;

    for (var i = 0; i < 40; i++) {
      await logErrorToFile('line $i padded out to force several rotations');
    }

    // The live file holds the newest entries - the ones support actually wants.
    final live = await logFile.readAsString();
    expect(live, contains('line 39'));
    expect(live.length, lessThanOrEqualTo(200 + 200),
        reason: 'live file must stay near the cap, not grow without bound');

    // Exactly one previous file is retained, so disk use is bounded at ~2x.
    expect(await backupFile.exists(), isTrue);
    final rotations = tempDir
        .listSync()
        .where((e) => e.path.contains('test_log.txt'))
        .length;
    expect(rotations, 2, reason: 'live + one backup, never a growing pile');
  }, onPlatform: const {'!windows': Skip('logErrorToFile only writes on Windows')});

  test('a rotation does not lose the line that triggered it', () async {
    maxLogBytesForTesting = 120;

    await logErrorToFile('first');
    await logErrorToFile('second');
    await logErrorToFile('third');

    final live = await logFile.readAsString();
    final backup =
        await backupFile.exists() ? await backupFile.readAsString() : '';
    final everything = '$backup$live';

    for (final expected in ['first', 'second', 'third']) {
      expect(everything, contains(expected),
          reason: 'rotation must move lines aside, never drop them');
    }
  }, onPlatform: const {'!windows': Skip('logErrorToFile only writes on Windows')});

  test('concurrent writes are serialised, in order, and never torn', () async {
    // Without the write queue, concurrent calls could interleave mid-append and
    // leave a half-written line, or lose one entirely around a rotation.
    // The cap is deliberately high here: rotation *is* meant to discard old
    // lines, so this test isolates the interleaving question from that.
    maxLogBytesForTesting = 10 * 1024 * 1024;

    await Future.wait([
      for (var i = 0; i < 30; i++) logErrorToFile('concurrent $i'),
    ]);

    final lines = (await logFile.readAsString())
        .split('\n')
        .where((l) => l.isNotEmpty)
        .toList();

    expect(lines.length, 30);
    // Every line is complete: a timestamp, then exactly one message.
    for (final line in lines) {
      expect(line, matches(RegExp(r'^\[[^\]]+\] concurrent \d+$')),
          reason: 'torn or interleaved line: $line');
    }
    // Submission order is preserved, which is what makes the log readable.
    expect(lines.map((l) => l.split('concurrent ').last).toList(),
        List.generate(30, (i) => '$i'));
  }, onPlatform: const {'!windows': Skip('logErrorToFile only writes on Windows')});

  test('rotation discards oldest history, keeping at most two files', () async {
    // The point of a cap: old lines go away. This pins that the discarding is
    // bounded and deliberate rather than unbounded growth.
    maxLogBytesForTesting = 300;

    await Future.wait([
      for (var i = 0; i < 30; i++) logErrorToFile('concurrent $i'),
    ]);

    final live = await logFile.readAsString();
    final backup =
        await backupFile.exists() ? await backupFile.readAsString() : '';

    expect(live, contains('concurrent 29'), reason: 'newest must survive');
    expect((live + backup).length, lessThan(300 * 3),
        reason: 'total retained stays bounded at roughly 2x the cap');
  }, onPlatform: const {'!windows': Skip('logErrorToFile only writes on Windows')});

  test('an existing oversized log is rotated rather than appended to forever',
      () async {
    // Simulates upgrading a till that already has a large log on disk.
    await logFile.writeAsString('x' * 5000);
    await setLogFileForTesting(logFile.path); // re-seed from disk
    maxLogBytesForTesting = 1000;

    await logErrorToFile('after upgrade');

    final live = await logFile.readAsString();
    expect(live, contains('after upgrade'));
    expect(live.length, lessThan(1000),
        reason: 'the pre-existing bulk must have been rotated away');
    expect(await backupFile.exists(), isTrue);
  }, onPlatform: const {'!windows': Skip('logErrorToFile only writes on Windows')});
}
