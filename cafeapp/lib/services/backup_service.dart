import 'dart:convert';
import 'dart:io';
import 'package:cafeapp/repositories/local_menu_repository.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'desktop_google_drive_service.dart'; // Import the desktop service
import 'package:device_info_plus/device_info_plus.dart';

class BackupService {
  static const String backupFileName = 'backup';
  static const String backupExtension = '.json';
  
  static const List<String> _databaseFiles = [
    'cafe_menu.db',
    'cafe_orders.db',
    'cafe_persons.db',
    'cafe_expenses.db'
  ];

  // NOW SUPPORTS ALL PLATFORMS!
  static bool get isGoogleDriveSupported {
    return true; // Works on all platforms now
  }

  static bool get isDesktopPlatform {
    try {
      return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (e) {
      return false;
    }
  }

  static bool get isMobilePlatform {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> backupData() async {
    try {
      if (Platform.isAndroid) {
        bool permissionGranted = await _requestStoragePermission();
        if (!permissionGranted) {
          debugPrint('Storage permission denied - using app-specific directories only');
        }
      }
      
      final Map<String, dynamic> prefsData = await _getPreferencesData();
      final Map<String, dynamic> databasesData = await _getDatabasesData();
      
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0.1',
        'app_version': '1.0.1',
        'platform': Platform.operatingSystem,
        'preferences': prefsData,
        'databases': databasesData,
      };
      
      final jsonData = jsonEncode(backupData);
      final String backupPath = await _createBackupDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '$backupPath/${backupFileName}_$timestamp$backupExtension';
      
      final file = File(filePath);
      await file.writeAsString(jsonData);
      
      debugPrint('✅ Full backup created at: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('❌ Error creating backup: $e');
      return null;
    }
  }
  
  static Future<bool> restoreData(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ Backup file does not exist: $filePath');
        return false;
      }
      
      debugPrint('Reading backup file: $filePath');
      final jsonData = await file.readAsString();
      final backupData = jsonDecode(jsonData) as Map<String, dynamic>;
      
      final version = backupData['version'];
      debugPrint('Backup version: $version');
      
      await _closeAllDatabases();
      
      final success1 = await _restorePreferences(backupData['preferences'] as Map<String, dynamic>);
      if (!success1) {
        debugPrint('❌ Failed to restore preferences');
        return false;
      }
      
      bool success2 = true;
      if (backupData.containsKey('databases')) {
        success2 = await _restoreDatabases(backupData['databases'] as Map<String, dynamic>);
        if (!success2) {
          debugPrint('❌ Failed to restore databases');
        }
      }
      
      return success1 && success2;
    } catch (e) {
      debugPrint('❌ Error restoring backup: $e');
      return false;
    }
  }
  
  static Future<bool> shareBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ File does not exist: $filePath');
        return false;
      }
      
      final xFile = XFile(filePath);
      await Share.shareXFiles([xFile], text: 'SIMS CAFE Backup');
      
      debugPrint('✅ Shared backup file: $filePath');
      return true;
    } catch (e) {
      debugPrint('❌ Error sharing backup: $e');
      return false;
    }
  }
  
  static Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ Deleted backup: $filePath');
        return true;
      } else {
        debugPrint('⚠️ Backup file not found: $filePath');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deleting backup: $e');
      return false;
    }
  }
  
  static Future<int> deleteOldBackups({int olderThanDays = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
      final backups = await getAvailableBackups();
      int deletedCount = 0;
      
      for (final backup in backups) {
        try {
          final backupDate = DateTime.parse(backup['timestamp']);
          if (backupDate.isBefore(cutoffDate)) {
            if (await deleteBackup(backup['path'])) {
              deletedCount++;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error processing backup date: $e');
        }
      }
      
      debugPrint('✅ Deleted $deletedCount old backups');
      return deletedCount;
    } catch (e) {
      debugPrint('❌ Error deleting old backups: $e');
      return 0;
    }
  }
  
  static Future<int> keepRecentBackups(int keepCount) async {
    try {
      final backups = await getAvailableBackups();
      
      if (backups.length <= keepCount) {
        return 0;
      }
      
      backups.sort((a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));
      
      final backupsToDelete = backups.sublist(keepCount);
      int deletedCount = 0;
      
      for (final backup in backupsToDelete) {
        if (await deleteBackup(backup['path'])) {
          deletedCount++;
        }
      }
      
      debugPrint('✅ Kept $keepCount recent backups, deleted $deletedCount');
      return deletedCount;
    } catch (e) {
      debugPrint('❌ Error managing recent backups: $e');
      return 0;
    }
  }
  
  static Future<String?> exportBackupToDownloads(String backupPath) async {
  try {
    if (Platform.isAndroid) {
      // Request storage permission
      final status = await Permission.storage.request();
      
      // For Android 13+ (API 33+), we need different permissions
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          // Android 13+ doesn't need storage permission for app-specific directories
          // But we'll use MediaStore or SAF instead
          debugPrint('Android 13+ detected, using alternative storage method');
        }
      }
      
      if (!status.isGranted && !status.isLimited) {
        debugPrint('⚠️ Storage permission denied');
        // Continue anyway - we'll try to use available directories
      }
    }
    
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      debugPrint('❌ Backup file not found: $backupPath');
      return null;
    }
    
    Directory? targetDir;
    
    if (Platform.isAndroid) {
      try {
        // Try multiple approaches for Android
        
        // Approach 1: Try the standard Download directory
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          try {
            // Test if we can write to this directory
            final testFile = File('${downloadDir.path}/.test_write');
            await testFile.writeAsString('test');
            await testFile.delete();
            targetDir = downloadDir;
            debugPrint('✅ Using standard Download directory');
          } catch (e) {
            debugPrint('⚠️ Cannot write to Download directory: $e');
          }
        }
        
        // Approach 2: Use getExternalStorageDirectory (app-specific, doesn't need permission)
        if (targetDir == null) {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // Create a "Downloads" folder in app-specific directory
            targetDir = Directory('${externalDir.path}/Downloads');
            if (!await targetDir.exists()) {
              await targetDir.create(recursive: true);
            }
            debugPrint('✅ Using app-specific Downloads directory: ${targetDir.path}');
          }
        }
        
        // Approach 3: Use Documents directory as fallback
        if (targetDir == null) {
          final docsDir = await getApplicationDocumentsDirectory();
          targetDir = Directory('${docsDir.path}/Exports');
          if (!await targetDir.exists()) {
            await targetDir.create(recursive: true);
          }
          debugPrint('✅ Using app Documents/Exports directory: ${targetDir.path}');
        }
      } catch (e) {
        debugPrint('❌ Error finding Android directory: $e');
        // Fallback to app directory
        final appDir = await getApplicationDocumentsDirectory();
        targetDir = Directory('${appDir.path}/Exports');
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      }
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Desktop platforms
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null) {
        targetDir = Directory(join(home, 'Downloads'));
        
        if (!await targetDir.exists()) {
          targetDir = Directory(join(home, 'Documents', 'SIMS_CAFE_Backups'));
          
          if (!await targetDir.exists()) {
            await targetDir.create(recursive: true);
          }
        }
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        targetDir = Directory(join(docsDir.path, 'Exports'));
        
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      }
    } else {
      // iOS or other platforms
      final docsDir = await getApplicationDocumentsDirectory();
      targetDir = Directory(join(docsDir.path, 'Downloads'));
      
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
    }
    
    // Get just the filename
    final fileName = basename(backupPath);
    
    // Use path.join for proper path construction
    final destPath = join(targetDir.path, fileName);
    
    debugPrint('📁 Copying from: $backupPath');
    debugPrint('📁 Copying to: $destPath');
    
    // Copy the file
    await backupFile.copy(destPath);
    
    debugPrint('✅ Exported backup to: $destPath');
    return destPath;
  } catch (e) {
    debugPrint('❌ Error exporting backup to Downloads: $e');
    return null;
  }
}
  
  // UPDATED: Works on ALL platforms now!
  static Future<Map<String, dynamic>> exportBackupToGoogleDrive(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        debugPrint('❌ Backup file not found: $backupPath');
        return {'success': false, 'error': 'Backup file not found'};
      }

      // Desktop platforms use REST API
      if (isDesktopPlatform) {
        debugPrint('🖥️ Using desktop Google Drive service...');
        
        if (!await DesktopGoogleDriveService.isAuthenticated()) {
          debugPrint('Not authenticated, starting authentication...');
          final authSuccess = await DesktopGoogleDriveService.authenticate();
          if (!authSuccess) {
            return {
              'success': false,
              'error': 'Authentication failed or canceled',
            };
          }
        }

        final fileName = backupPath.split('/').last;
        final fileId = await DesktopGoogleDriveService.uploadFile(backupPath, fileName);

        if (fileId != null) {
          debugPrint('✅ Uploaded to Google Drive via desktop service');
          return {'success': true, 'fileId': fileId};
        } else {
          return {'success': false, 'error': 'Upload failed'};
        }
      }

      // Mobile platforms use google_sign_in plugin
      if (isMobilePlatform) {
        debugPrint('📱 Using mobile Google Sign-In...');
        
        final GoogleSignIn googleSignIn = GoogleSignIn.standard(
          scopes: [drive.DriveApi.driveFileScope],
        );
        
        await googleSignIn.signOut();
        
        GoogleSignInAccount? account;
        try {
          account = await googleSignIn.signInSilently();
        } catch (e) {
          debugPrint('Silent sign-in failed: $e');
        }
        
        if (account == null) {
          try {
            account = await googleSignIn.signIn();
          } catch (e) {
            debugPrint('Interactive sign-in failed: $e');
            return {'success': false, 'error': 'Google Sign-In failed: $e'};
          }
        }
        
        if (account == null) {
          debugPrint('❌ Google Sign-In failed: user canceled');
          return {'success': false, 'error': 'User canceled sign-in'};
        }
        
        final authHeaders = await account.authHeaders;
        final authenticateClient = GoogleAuthClient(authHeaders);
        
        final driveApi = drive.DriveApi(authenticateClient);
        
        final fileName = backupPath.split('/').last;
        final fileMetadata = drive.File()
          ..name = fileName
          ..mimeType = 'application/json';
        
        final Stream<List<int>> mediaStream = backupFile.openRead();
        final media = drive.Media(mediaStream, await backupFile.length());
        
        final result = await driveApi.files.create(
          fileMetadata,
          uploadMedia: media,
        );
        
        debugPrint('✅ Uploaded to Google Drive via mobile: ${result.id}');
        return {'success': true, 'fileId': result.id};
      }

      return {'success': false, 'error': 'Unsupported platform'};
    } catch (e) {
      debugPrint('❌ Error exporting to Google Drive: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  static Future<int> _getAndroidSDKVersion() async {
    try {
      if (!Platform.isAndroid) return 0;
      return 29;
    } catch (e) {
      debugPrint('⚠️ Error getting Android SDK version: $e');
      return 29;
    }
  }
  
  static Future<bool> _requestStoragePermission() async {
    try {
      final sdkInt = await _getAndroidSDKVersion();
      
      if (sdkInt >= 30) {
        return true;
      } else if (sdkInt >= 29) {
        final status = await Permission.storage.request();
        return status.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } catch (e) {
      debugPrint('⚠️ Error requesting storage permission: $e');
      return false;
    }
  }
  
  static Future<List<Map<String, dynamic>>> getAvailableBackups() async {
    try {
      List<Directory> directories = [];
      List<Map<String, dynamic>> backups = [];
      
      final appDir = await getApplicationDocumentsDirectory();
      directories.add(appDir);
      
      final backupDir = Directory('${appDir.path}/backups');
      if (await backupDir.exists()) {
        directories.add(backupDir);
      }
      
      for (final dir in directories) {
        if (!await dir.exists()) continue;
        
        final fileEntities = await dir.list().toList();
        
        final files = fileEntities
            .whereType<File>()
            .where((file) {
              final name = file.path.split('/').last;
              return name.startsWith(backupFileName) && name.endsWith(backupExtension);
            })
            .toList();
        
        files.sort((a, b) {
          return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        });
        
        for (final file in files) {
          try {
            final content = await File(file.path).readAsString();
            final data = jsonDecode(content) as Map<String, dynamic>;
            
            backups.add({
              'path': file.path,
              'name': file.path.split('/').last,
              'timestamp': data['timestamp'],
              'version': data.containsKey('version') ? data['version'] : '1.0.0',
              'app_version': data.containsKey('app_version') ? data['app_version'] : 'Unknown',
              'platform': data.containsKey('platform') ? data['platform'] : 'Unknown',
              'has_databases': data.containsKey('databases'),
              'size': await File(file.path).length(),
            });
          } catch (e) {
            debugPrint('⚠️ Error reading backup file: $e');
          }
        }
      }
      
      backups.sort((a, b) {
        return (b['timestamp'] as String).compareTo(a['timestamp'] as String);
      });
      
      return backups;
    } catch (e) {
      debugPrint('❌ Error getting available backups: $e');
      return [];
    }
  }
  
  static Future<Map<String, dynamic>> _getPreferencesData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getKeys().fold<Map<String, dynamic>>(
        {},
        (map, key) {
          dynamic value = prefs.get(key);
          
          if (value is Set) {
            value = value.toList();
          }
          
          map[key] = value;
          return map;
        },
      );
    } catch (e) {
      debugPrint('❌ Error getting preferences data: $e');
      return {};
    }
  }
  
  static Future<Map<String, dynamic>> _getDatabasesData() async {
    final Map<String, dynamic> databasesData = {};
    
    try {
      final databasesPath = await getDatabasesPath();
      
      for (final dbName in _databaseFiles) {
        final dbPath = join(databasesPath, dbName);
        final dbFile = File(dbPath);
        
        if (await dbFile.exists()) {
          debugPrint('Reading database: $dbName');
          
          try {
            final tempDir = await getTemporaryDirectory();
            final tempPath = join(tempDir.path, 'temp_$dbName');
            await dbFile.copy(tempPath);
            
            final bytes = await File(tempPath).readAsBytes();
            final base64Data = base64Encode(bytes);
            databasesData[dbName] = base64Data;
            
            await File(tempPath).delete();
          } catch (e) {
            debugPrint('❌ Error reading database $dbName: $e');
          }
        } else {
          debugPrint('⚠️ Database file does not exist: $dbName');
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting databases data: $e');
    }
    
    return databasesData;
  }
  
  static Future<String> _createBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    
    final backupDir = Directory('${appDir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    
    return backupDir.path;
  }
  
  static Future<bool> _restorePreferences(Map<String, dynamic> prefsData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      for (final key in prefsData.keys) {
        final value = prefsData[key];
        
        if (value is String) {
          await prefs.setString(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is List) {
          try {
            await prefs.setStringList(key, value.cast<String>());
          } catch (e) {
            debugPrint('⚠️ Error restoring preference $key: $e');
          }
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Error restoring preferences: $e');
      return false;
    }
  }
  
  static Future<void> _closeAllDatabases() async {
    try {
      for (final dbName in _databaseFiles) {
        try {
          final databasesPath = await getDatabasesPath();
          final dbPath = join(databasesPath, dbName);
          
          if (await databaseFactory.databaseExists(dbPath)) {
            final db = await databaseFactory.openDatabase(dbPath);
            await db.close();
          }
        } catch (e) {
          debugPrint('⚠️ Error closing database $dbName: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error closing databases: $e');
    }
  }
  
  static Future<bool> _restoreDatabases(Map<String, dynamic> databasesData) async {
    try {
      final databasesPath = await getDatabasesPath();
      
      for (final dbName in databasesData.keys) {
        if (!_databaseFiles.contains(dbName)) {
          debugPrint('⚠️ Skipping unknown database: $dbName');
          continue;
        }
        
        final dbPath = join(databasesPath, dbName);
        final base64Data = databasesData[dbName] as String;
        
        try {
          final bytes = base64Decode(base64Data);
          
          final dbFile = File(dbPath);
          if (await dbFile.exists()) {
            await dbFile.delete();
          }
          
          await dbFile.writeAsBytes(bytes);
          debugPrint('✅ Restored database: $dbName');
        } catch (e) {
          debugPrint('❌ Error restoring database $dbName: $e');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Error restoring databases: $e');
      return false;
    }
  }

  // UPDATED: Works on ALL platforms now!
  static Future<Map<String, dynamic>> getGoogleDriveBackups() async {
    try {
      // Desktop platforms use REST API
      if (isDesktopPlatform) {
        debugPrint('🖥️ Getting Drive backups via desktop service...');
        
        if (!await DesktopGoogleDriveService.isAuthenticated()) {
          return {
            'success': false,
            'error': 'Not authenticated',
            'backups': <Map<String, dynamic>>[],
          };
        }

        final query = "name contains '$backupFileName' and name contains '$backupExtension'";
        final files = await DesktopGoogleDriveService.listFiles(query: query);

        final backups = files.map((file) {
          return {
            'id': file['id'],
            'path': file['id'],
            'name': file['name'],
            'timestamp': file['modifiedTime'],
            'version': 'Google Drive',
            'app_version': 'Unknown',
            'has_databases': true,
            'size': int.parse(file['size'] ?? '0'),
            'is_drive': true,
          };
        }).toList();

        return {
          'success': true,
          'backups': backups,
        };
      }

      // Mobile platforms use google_sign_in plugin
      if (isMobilePlatform) {
        debugPrint('📱 Getting Drive backups via mobile...');
        
        final GoogleSignIn googleSignIn = GoogleSignIn.standard(
          scopes: [
            drive.DriveApi.driveFileScope,
            'email',
            'profile',
          ],
        );
        
        GoogleSignInAccount? account;
        try {
          account = await googleSignIn.signInSilently();
        } catch (e) {
          debugPrint('Silent sign-in failed: $e');
        }
        
        if (account == null) {
          try {
            account = await googleSignIn.signIn();
          } catch (e) {
            debugPrint('Interactive sign-in failed: $e');
            return {
              'success': false,
              'error': 'Sign-in failed: $e',
              'backups': <Map<String, dynamic>>[],
            };
          }
        }
        
        if (account == null) {
          debugPrint('❌ Google Sign-In failed: user canceled');
          return {
            'success': false,
            'error': 'User canceled',
            'backups': <Map<String, dynamic>>[],
          };
        }
        
        final authHeaders = await account.authHeaders;
        final authenticateClient = GoogleAuthClient(authHeaders);
        
        final driveApi = drive.DriveApi(authenticateClient);
        
        final fileList = await driveApi.files.list(
          q: "name contains '$backupFileName' and name contains '$backupExtension' and trashed = false",
          $fields: "files(id, name, createdTime, modifiedTime, size)",
        );
        
        final files = fileList.files ?? [];
        
        List<Map<String, dynamic>> backups = [];
        
        for (final file in files) {
          try {
            final name = file.name ?? 'Unknown';
            final id = file.id ?? '';
            final modifiedTime = file.modifiedTime ?? DateTime.now();
            final size = file.size ?? '0';
            
            String timestamp = '';
            final regex = RegExp(r'(\d{8}_\d{6})');
            final match = regex.firstMatch(name);
            
            if (match != null) {
              final dateString = match.group(1);
              if (dateString != null) {
                try {
                  final year = int.parse(dateString.substring(0, 4));
                  final month = int.parse(dateString.substring(4, 6));
                  final day = int.parse(dateString.substring(6, 8));
                  final hour = int.parse(dateString.substring(9, 11));
                  final minute = int.parse(dateString.substring(11, 13));
                  final second = int.parse(dateString.substring(13, 15));
                  
                  final datetime = DateTime(year, month, day, hour, minute, second);
                  timestamp = datetime.toIso8601String();
                } catch (e) {
                  timestamp = modifiedTime.toIso8601String();
                }
              }
            } else {
              timestamp = modifiedTime.toIso8601String();
            }
            
            backups.add({
              'id': id,
              'path': id,
              'name': name,
              'timestamp': timestamp,
              'version': 'Google Drive',
              'app_version': 'Unknown',
              'has_databases': true,
              'size': int.parse(size),
              'is_drive': true,
            });
          } catch (e) {
            debugPrint('⚠️ Error processing Drive file: $e');
          }
        }
        
        backups.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
        
        return {
          'success': true,
          'backups': backups,
        };
      }

      return {
        'success': false,
        'error': 'Unsupported platform',
        'backups': <Map<String, dynamic>>[],
      };
    } catch (e) {
      debugPrint('❌ Error getting Google Drive backups: $e');
      return {
        'success': false,
        'error': e.toString(),
        'backups': <Map<String, dynamic>>[],
      };
    }
  }

  // UPDATED: Works on ALL platforms now!
  static Future<Map<String, dynamic>> deleteBackupFromDrive(String fileId) async {
  try {
    // Desktop platforms use REST API
    if (isDesktopPlatform) {
      if (!await DesktopGoogleDriveService.isAuthenticated()) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final success = await DesktopGoogleDriveService.deleteFile(fileId);
      return {
        'success': success,
        'error': success ? null : 'Delete failed',
      };
    }

    // Mobile platforms use google_sign_in plugin
    if (isMobilePlatform) {
      final GoogleSignIn googleSignIn = GoogleSignIn.standard(
        scopes: [drive.DriveApi.driveFileScope],
      );
      
      GoogleSignInAccount? account;
      try {
        account = await googleSignIn.signInSilently();
      } catch (e) {
        debugPrint('Silent sign-in failed: $e');
      }
      
      if (account == null) {
        try {
          account = await googleSignIn.signIn();
        } catch (e) {
          debugPrint('Interactive sign-in failed: $e');
          return {'success': false, 'error': 'Sign-in failed'};
        }
      }
      
      if (account == null) {
        debugPrint('❌ Google Sign-In failed: user canceled');
        return {'success': false, 'error': 'User canceled'};
      }
      
      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      
      final driveApi = drive.DriveApi(authenticateClient);
      
      // DELETE the file from Google Drive
      await driveApi.files.delete(fileId);
      
      debugPrint('✅ Deleted backup from Google Drive: $fileId');
      return {'success': true};
    }

    return {'success': false, 'error': 'Unsupported platform'};
  } catch (e) {
    debugPrint('❌ Error deleting backup from Drive: $e');
    return {'success': false, 'error': e.toString()};
  }
}

  // UPDATED: Works on ALL platforms now!
  static Future<Map<String, dynamic>> downloadBackupFromDrive(String fileId) async {
  try {
    // Desktop platforms use REST API
    if (isDesktopPlatform) {
      if (!await DesktopGoogleDriveService.isAuthenticated()) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final backupPath = await _createBackupDirectory();
      final localPath = '$backupPath/drive_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      final downloadedPath = await DesktopGoogleDriveService.downloadFile(fileId, localPath);

      if (downloadedPath != null) {
        return {'success': true, 'path': downloadedPath};
      } else {
        return {'success': false, 'error': 'Download failed'};
      }
    }

    // Mobile platforms use google_sign_in plugin
    if (isMobilePlatform) {
      final GoogleSignIn googleSignIn = GoogleSignIn.standard(
        scopes: [drive.DriveApi.driveFileScope],
      );
      
      GoogleSignInAccount? account;
      try {
        account = await googleSignIn.signInSilently();
      } catch (e) {
        debugPrint('Silent sign-in failed: $e');
      }
      
      if (account == null) {
        try {
          account = await googleSignIn.signIn();
        } catch (e) {
          debugPrint('Interactive sign-in failed: $e');
          return {'success': false, 'error': 'Sign-in failed'};
        }
      }
      
      if (account == null) {
        debugPrint('❌ Google Sign-In failed: user canceled');
        return {'success': false, 'error': 'User canceled'};
      }
      
      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      
      final driveApi = drive.DriveApi(authenticateClient);
      
      // Get file metadata to get the filename
      final fileMetadata = await driveApi.files.get(fileId) as drive.File;
      final fileName = fileMetadata.name ?? 'downloaded_backup.json';
      
      // Download the file content
      final fileContent = await driveApi.files.get(
        fileId, 
        downloadOptions: drive.DownloadOptions.fullMedia
      ) as drive.Media;
      
      // Save to local directory
      final backupPath = await _createBackupDirectory();
      final localFilePath = '$backupPath/$fileName';
      
      final file = File(localFilePath);
      final fileStream = file.openWrite();
      
      // Use a completer to handle the async stream
      final completer = Completer<void>();
      
      fileContent.stream.listen(
        (data) {
          fileStream.add(data);
        },
        onDone: () async {
          await fileStream.flush();
          await fileStream.close();
          completer.complete();
        },
        onError: (error) {
          completer.completeError(error);
        },
        cancelOnError: true,
      );
      
      // Wait for download to complete
      await completer.future;
      
      debugPrint('✅ Downloaded backup from Drive to: $localFilePath');
      return {'success': true, 'path': localFilePath};
    }

    return {'success': false, 'error': 'Unsupported platform'};
  } catch (e) {
    debugPrint('❌ Error downloading backup from Drive: $e');
    return {'success': false, 'error': e.toString()};
  }
}
  // UPDATED: Works on ALL platforms now!
  static Future<Map<String, dynamic>> restoreFromGoogleDrive(String fileId) async {
    try {
      debugPrint('🔄 Starting restore from Google Drive...');
      
      final downloadResult = await downloadBackupFromDrive(fileId);
      
      if (downloadResult['success'] != true) {
        debugPrint('❌ Download failed: ${downloadResult['error']}');
        return downloadResult;
      }
      
      final localFilePath = downloadResult['path'];
      
      if (localFilePath == null || localFilePath.isEmpty) {
        debugPrint('❌ No file path returned from download');
        return {
          'success': false,
          'error': 'Failed to download backup file',
        };
      }
      
      debugPrint('📥 Downloaded backup to: $localFilePath');
      
      // Verify file exists
      final file = File(localFilePath);
      if (!await file.exists()) {
        debugPrint('❌ Downloaded file does not exist: $localFilePath');
        return {
          'success': false,
          'error': 'Downloaded file not found',
        };
      }
      
      // Verify file has content
      final fileSize = await file.length();
      debugPrint('📊 Downloaded file size: $fileSize bytes');
      
      if (fileSize == 0) {
        debugPrint('❌ Downloaded file is empty');
        return {
          'success': false,
          'error': 'Downloaded file is empty',
        };
      }
      
      // Read and verify the backup data
      try {
        final jsonData = await file.readAsString();
        final backupData = jsonDecode(jsonData) as Map<String, dynamic>;
        
        debugPrint('📋 Backup verification:');
        debugPrint('  - Version: ${backupData['version']}');
        debugPrint('  - Platform: ${backupData['platform']}');
        debugPrint('  - Has databases: ${backupData.containsKey('databases')}');
        
        if (backupData.containsKey('databases')) {
          final databases = backupData['databases'] as Map<String, dynamic>;
          debugPrint('  - Database count: ${databases.length}');
          
          // Check for menu database
          if (databases.containsKey('cafe_menu.db')) {
            debugPrint('  ✅ Menu database found');
          } else {
            debugPrint('  ⚠️ Menu database not found');
          }
        }
      } catch (e) {
        debugPrint('❌ Error verifying backup: $e');
        return {
          'success': false,
          'error': 'Invalid backup file format: $e',
        };
      }
      
      // Restore the backup
      debugPrint('🔄 Starting restore process...');
      final restoreSuccess = await restoreData(localFilePath);
      
      if (restoreSuccess) {
        debugPrint('✅ Restore completed successfully');
        
        // Verify menu items were restored
        try {
          final menuRepo = LocalMenuRepository();
          final items = await menuRepo.getMenuItems();
          final itemsWithImages = items.where((item) => item.imageUrl.isNotEmpty).length;
          debugPrint('📊 Restored ${items.length} menu items, $itemsWithImages with images');
        } catch (e) {
          debugPrint('⚠️ Could not verify restored items: $e');
        }
      } else {
        debugPrint('❌ Restore failed');
      }
      
      return {
        'success': restoreSuccess,
        'error': restoreSuccess ? null : 'Failed to restore data',
      };
    } catch (e) {
      debugPrint('❌ Error restoring from Google Drive: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
    // Helper class for Google Drive authentication
  class GoogleAuthClient extends http.BaseClient {
    final Map<String, String> _headers;
    final http.Client _client = http.Client();
    
    GoogleAuthClient(this._headers);
    
    @override
    Future<http.StreamedResponse> send(http.BaseRequest request) {
      request.headers.addAll(_headers);
      return _client.send(request);
    }
  }
