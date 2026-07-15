import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';
import '../widgets/custom_update_dialog.dart';
import '../utils/app_localization.dart';

class UpdateService {
  static const String appcastUrl = 'https://raw.githubusercontent.com/simsai-git/SIMS-CAFE/main/appcast.xml';

  static Future<void> initializeWindowsUpdater() async {
    // We no longer initialize WinSparkle (auto_updater) on Windows
    // because we are using a custom Flutter UI.
    // Future enhancements can set up a timer to call checkWindowsUpdateCustomUI periodically.
  }

  static Future<void> checkUpdateCustomUI(BuildContext context, {required String os, bool showNoUpdateMessage = false}) async {
    if (kIsWeb) return;

    try {
      if (showNoUpdateMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Checking for updates...'.tr())),
        );
      }

      final response = await http.get(Uri.parse(appcastUrl));
      if (response.statusCode != 200) throw Exception('Failed to fetch appcast');

      final xmlString = response.body;
      
      // Simple string parsing to avoid heavy XML dependencies
      // Look for the correct OS item block
      final osBlock = xmlString.split('<item>').firstWhere((b) => b.contains('sparkle:os="$os"'), orElse: () => '');
      
      if (osBlock.isEmpty) return;

      // Extract version
      final versionMatch = RegExp(r'sparkle:version="([^"]+)"').firstMatch(osBlock);
      // Extract download URL
      final urlMatch = RegExp(r'url="([^"]+)"').firstMatch(osBlock);
      // Extract release notes
      final notesMatch = RegExp(r'<description>.*?<!\[CDATA\[(.*?)\]\]>.*?</description>', dotAll: true).firstMatch(osBlock);

      if (versionMatch != null && urlMatch != null) {
        final latestVersionStr = versionMatch.group(1)!;
        final downloadUrl = urlMatch.group(1)!;
        final releaseNotes = notesMatch != null ? notesMatch.group(1)! : '';

        // Get current version
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersionStr = packageInfo.version;

        // Compare versions (simple logic)
        final latestParts = latestVersionStr.split('.').map((e) => int.tryParse(e) ?? 0).toList();
        final currentParts = currentVersionStr.split('.').map((e) => int.tryParse(e) ?? 0).toList();

        bool hasUpdate = false;
        for (int i = 0; i < 3; i++) {
          final l = i < latestParts.length ? latestParts[i] : 0;
          final c = i < currentParts.length ? currentParts[i] : 0;
          if (l > c) {
            hasUpdate = true;
            break;
          } else if (l < c) {
            break;
          }
        }

        if (hasUpdate && context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => CustomUpdateDialog(
              version: latestVersionStr,
              releaseNotes: releaseNotes,
              downloadUrl: downloadUrl,
            ),
          );
        } else if (showNoUpdateMessage && context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Up to Date'.tr()),
              content: Text('No update is available. You are on the latest version.'.tr()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('OK'.tr()),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      if (showNoUpdateMessage && context.mounted) {
        String errorMessage = 'Failed to check for updates.'.tr();
        if (e is SocketException || e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
          errorMessage = 'Please check your internet connection and try again.'.tr();
        }
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  static Future<void> checkForUpdatesManually(BuildContext context) async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await checkUpdateCustomUI(context, os: 'windows', showNoUpdateMessage: true);
    } else if (Platform.isAndroid) {
      await checkUpdateCustomUI(context, os: 'android', showNoUpdateMessage: true);
    }
  }

  static Future<void> checkForUpdatesAutomatically(BuildContext context) async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await checkUpdateCustomUI(context, os: 'windows', showNoUpdateMessage: false);
    } else if (Platform.isAndroid) {
      await checkUpdateCustomUI(context, os: 'android', showNoUpdateMessage: false);
    }
  }

  static Upgrader getAndroidUpgrader() {
    return Upgrader(
      storeController: UpgraderStoreController(
        onAndroid: () => UpgraderAppcastStore(appcastURL: appcastUrl),
      ),
      debugLogging: true,
      durationUntilAlertAgain: const Duration(hours: 1),
    );
  }
}