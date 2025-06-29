import 'dart:convert';
import 'dart:io';
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
// import 'package:cross_file/cross_file.dart';
import 'dart:async';

class BackupService {
  static const String backupFileName = 'backup';
  static const String backupExtension = '.json';
  
  // List of database files to backup
  static const List<String> _databaseFiles = [
    'cafe_menu.db',
    'cafe_orders.db',
    'cafe_persons.db',
    'cafe_expenses.db'
  ];
  
  // Create a comprehensive backup including SharedPreferences and SQLite databases
  static Future<String?> backupData() async {
    try {
      // Request storage permissions on Android if needed
      if (Platform.isAndroid) {
        bool permissionGranted = await _requestStoragePermission();
        if (!permissionGranted) {
          debugPrint('Storage permission denied - using app-specific directories only');
          // Continue anyway - we'll use app-specific directories
        }
      }
      
      // 1. Get all SharedPreferences data
      final Map<String, dynamic> prefsData = await _getPreferencesData();
      
      // 2. Get all SQLite database data
      final Map<String, dynamic> databasesData = await _getDatabasesData();
      
      // 3. Create backup data object
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0.1', // Updated version for full backup
        'app_version': '1.0.1', // App version
        'preferences': prefsData,
        'databases': databasesData,
      };
      
      // 4. Convert to JSON
      final jsonData = jsonEncode(backupData);
      
      // 5. Create backup directory
      final String backupPath = await _createBackupDirectory();
      
      // 6. Create timestamp for filename
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '$backupPath/${backupFileName}_$timestamp$backupExtension';
      
      // 7. Write file
      final file = File(filePath);
      await file.writeAsString(jsonData);
      
      debugPrint('Full backup created at: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Error creating backup: $e');
      return null;
    }
  }
  
  // Restore data from a backup file
  static Future<bool> restoreData(String filePath) async {
    try {
      // 1. Read backup file
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('Backup file does not exist: $filePath');
        return false;
      }
      
      debugPrint('Reading backup file: $filePath');
      final jsonData = await file.readAsString();
      final backupData = jsonDecode(jsonData) as Map<String, dynamic>;
      
      // 2. Check version compatibility
      final version = backupData['version'];
      debugPrint('Backup version: $version');
      
      // 3. Close any open database connections
      await _closeAllDatabases();
      
      // 4. Restore SharedPreferences
      final success1 = await _restorePreferences(backupData['preferences'] as Map<String, dynamic>);
      if (!success1) {
        debugPrint('Failed to restore preferences');
        return false;
      }
      
      // 5. Restore SQLite databases
      bool success2 = true;
      if (backupData.containsKey('databases')) {
        success2 = await _restoreDatabases(backupData['databases'] as Map<String, dynamic>);
        if (!success2) {
          debugPrint('Failed to restore databases');
        }
      }
      
      return success1 && success2;
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      return false;
    }
  }
  
  // Share backup file
  static Future<bool> shareBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('File does not exist: $filePath');
        return false;
      }
      
      // Use share_plus to share the file with the updated API
      final xFile = XFile(filePath);
      await Share.shareXFiles([xFile], text: 'SIMS CAFE Backup');
      
      debugPrint('Shared backup file: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error sharing backup: $e');
      return false;
    }
  }
  
  // Delete a specific backup file
  static Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Deleted backup: $filePath');
        return true;
      } else {
        debugPrint('Backup file not found: $filePath');
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }
  
  // Delete backups older than a specified number of days
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
          debugPrint('Error processing backup date: $e');
        }
      }
      
      debugPrint('Deleted $deletedCount old backups');
      return deletedCount;
    } catch (e) {
      debugPrint('Error deleting old backups: $e');
      return 0;
    }
  }
  
  // Keep only a specified number of most recent backups
  static Future<int> keepRecentBackups(int keepCount) async {
    try {
      final backups = await getAvailableBackups();
      
      // If we have fewer backups than the keep count, no need to delete any
      if (backups.length <= keepCount) {
        return 0;
      }
      
      // Sort backups by date (newest first) - they should already be sorted, but let's be sure
      backups.sort((a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));
      
      // Delete all backups beyond the keep count
      final backupsToDelete = backups.sublist(keepCount);
      int deletedCount = 0;
      
      for (final backup in backupsToDelete) {
        if (await deleteBackup(backup['path'])) {
          deletedCount++;
        }
      }
      
      debugPrint('Kept $keepCount recent backups, deleted $deletedCount');
      return deletedCount;
    } catch (e) {
      debugPrint('Error managing recent backups: $e');
      return 0;
    }
  }
  
  // Export backup to Downloads folder (external storage)
  static Future<String?> exportBackupToDownloads(String backupPath) async {
    try {
      // Request storage permissions
      await _requestStoragePermission();
      
      // Get the backup file
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        debugPrint('Backup file not found: $backupPath');
        return null;
      }
      
      // Get the Downloads directory
      Directory? downloadsDir;
      
      if (Platform.isAndroid) {
        // On Android, we need to use the standard Downloads directory
        downloadsDir = Directory('/storage/emulated/0/Download');
        
        // Check if the directory exists
        if (!await downloadsDir.exists()) {
          debugPrint('Downloads directory not found, trying alternate path');
          
          // Try to get external storage directory
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // Try to navigate to a standard location
            downloadsDir = Directory('${externalDir.path}/../../Download');
            
            if (!await downloadsDir.exists()) {
              debugPrint('Could not find Downloads directory');
              return null;
            }
          } else {
            debugPrint('External storage not available');
            return null;
          }
        }
      } else {
        // On iOS, we need to use the Documents directory
        final docsDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory('${docsDir.path}/Downloads');
        
        // Create the Downloads directory if it doesn't exist
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
      }
      
      // Create the destination file path
      final fileName = backupPath.split('/').last;
      final destPath = '${downloadsDir.path}/$fileName';
      
      // Copy the file
      await backupFile.copy(destPath);
      
      debugPrint('Exported backup to: $destPath');
      return destPath;
    } catch (e) {
      debugPrint('Error exporting backup to Downloads: $e');
      return null;
    }
  }
  
  // Export backup to Google Drive
  static Future<bool> exportBackupToGoogleDrive(String backupPath) async {
    try {
      // 1. Get the backup file
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        debugPrint('Backup file not found: $backupPath');
        return false;
      }
      
      // 2. Sign in with Google
      final GoogleSignIn googleSignIn = GoogleSignIn.standard(
        scopes: [drive.DriveApi.driveFileScope],
      );
      
      // Force sign out first to avoid caching issues
      await googleSignIn.signOut();
      
      // Try to sign in silently first
      GoogleSignInAccount? account;
      try {
        account = await googleSignIn.signInSilently();
      } catch (e) {
        debugPrint('Silent sign-in failed: $e');
        // Silent sign-in failed, try interactive sign-in
      }
      
      // If silent sign-in failed, try interactive sign-in
      if (account == null) {
        try {
          account = await googleSignIn.signIn();
        } catch (e) {
          debugPrint('Interactive sign-in failed: $e');
          return false;
        }
      }
      
      if (account == null) {
        debugPrint('Google Sign-In failed: user canceled');
        return false;
      }
      
      // 3. Get authentication client
      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      
      // 4. Initialize Drive API
      final driveApi = drive.DriveApi(authenticateClient);
      
      // 5. Prepare file metadata
      final fileName = backupPath.split('/').last;
      final fileMetadata = drive.File()
        ..name = fileName
        ..mimeType = 'application/json';
      
      // 6. Read file content
      final Stream<List<int>> mediaStream = backupFile.openRead();
      final media = drive.Media(mediaStream, await backupFile.length());
      
      // 7. Upload file to Drive
      final result = await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
      );
      
      debugPrint('Uploaded to Google Drive with ID: ${result.id}');
      return true;
    } catch (e) {
      debugPrint('Error exporting to Google Drive: $e');
      return false;
    }
  }
  
  // Helper to get server client ID from resources
  // static String _getServerClientId() {
  //   try {
  //     // This would require native code integration to access string resources
  //     // For now, hardcode your Web Client ID here for testing
  //     return "YOUR_WEB_CLIENT_ID_HERE"; // Replace with your actual Web Client ID
  //   } catch (e) {
  //     debugPrint('Error getting server client ID: $e');
  //     return "";
  //   }
  // }
  
  // Helper method to get Android SDK version
  static Future<int> _getAndroidSDKVersion() async {
    try {
      if (!Platform.isAndroid) return 0;
      
      // Default to a reasonable version if we can't detect
      return 29; // Android 10
    } catch (e) {
      debugPrint('Error getting Android SDK version: $e');
      return 29; // Default to Android 10
    }
  }
  
  // Helper method to request storage permissions
  static Future<bool> _requestStoragePermission() async {
    try {
      // Check Android version
      final sdkInt = await _getAndroidSDKVersion();
      
      if (sdkInt >= 30) {
        // Android 11+: We need MANAGE_EXTERNAL_STORAGE for broader access
        // But for app-specific directories we don't need special permissions
        return true; // Assume we can write to app directories
      } else if (sdkInt >= 29) {
        // Android 10: Request legacy storage permission
        final status = await Permission.storage.request();
        return status.isGranted;
      } else {
        // Android 9 and below: Request regular storage permission
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } catch (e) {
      debugPrint('Error requesting storage permission: $e');
      return false;
    }
  }
  
  // Get list of available backups
  static Future<List<Map<String, dynamic>>> getAvailableBackups() async {
    try {
      List<Directory> directories = [];
      List<Map<String, dynamic>> backups = [];
      
      // First check app documents directory (most reliable)
      final appDir = await getApplicationDocumentsDirectory();
      
      // Add the main app directory
      directories.add(appDir);
      
      // Add the backups subdirectory if it exists
      final backupDir = Directory('${appDir.path}/backups');
      if (await backupDir.exists()) {
        directories.add(backupDir);
      }
      
      // Look for backup files in all directories
      for (final dir in directories) {
        if (!await dir.exists()) continue;
        
        final fileEntities = await dir.list().toList();
        
        // Filter backup files
        final files = fileEntities
            .whereType<File>()
            .where((file) {
              final name = file.path.split('/').last;
              return name.startsWith(backupFileName) && name.endsWith(backupExtension);
            })
            .toList();
        
        // Sort by date (newest first)
        files.sort((a, b) {
          return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        });
        
        // Create info list
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
              'has_databases': data.containsKey('databases'),
              'size': await File(file.path).length(),
            });
          } catch (e) {
            // Skip invalid backup files
            debugPrint('Error reading backup file: $e');
          }
        }
      }
      
      // Sort all backups by timestamp (newest first)
      backups.sort((a, b) {
        return (b['timestamp'] as String).compareTo(a['timestamp'] as String);
      });
      
      return backups;
    } catch (e) {
      debugPrint('Error getting available backups: $e');
      return [];
    }
  }
  
  // Helper method to get all SharedPreferences data
  static Future<Map<String, dynamic>> _getPreferencesData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getKeys().fold<Map<String, dynamic>>(
        {},
        (map, key) {
          // Handle different types of preferences
          dynamic value = prefs.get(key);
          
          // Convert non-JSON serializable types
          if (value is Set) {
            value = value.toList();
          }
          
          map[key] = value;
          return map;
        },
      );
    } catch (e) {
      debugPrint('Error getting preferences data: $e');
      return {};
    }
  }
  
  // Helper method to get all SQLite database data
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
            // Create a copy of the database file to read while the original is in use
            final tempDir = await getTemporaryDirectory();
            final tempPath = join(tempDir.path, 'temp_$dbName');
            await dbFile.copy(tempPath);
            
            // Read the database file as bytes
            final bytes = await File(tempPath).readAsBytes();
            
            // Convert to base64 for JSON storage
            final base64Data = base64Encode(bytes);
            databasesData[dbName] = base64Data;
            
            // Clean up temp file
            await File(tempPath).delete();
          } catch (e) {
            debugPrint('Error reading database $dbName: $e');
          }
        } else {
          debugPrint('Database file does not exist: $dbName');
        }
      }
    } catch (e) {
      debugPrint('Error getting databases data: $e');
    }
    
    return databasesData;
  }
  
  // Helper method to create backup directory
  static Future<String> _createBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    
    // Create backup directory if it doesn't exist
    final backupDir = Directory('${appDir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    
    return backupDir.path;
  }
  
  // Helper method to restore SharedPreferences
  static Future<bool> _restorePreferences(Map<String, dynamic> prefsData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Clear existing preferences
      
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
          // Try to convert to List<String> if possible
          try {
            await prefs.setStringList(key, value.cast<String>());
          } catch (e) {
            debugPrint('Error restoring preference $key: $e');
          }
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Error restoring preferences: $e');
      return false;
    }
  }
  
  // Helper method to close all database connections
  static Future<void> _closeAllDatabases() async {
    try {
      // Close any open database connections
      for (final dbName in _databaseFiles) {
        try {
          final databasesPath = await getDatabasesPath();
          final dbPath = join(databasesPath, dbName);
          
          if (await databaseFactory.databaseExists(dbPath)) {
            final db = await databaseFactory.openDatabase(dbPath);
            await db.close();
          }
        } catch (e) {
          // Ignore errors, just try to close all possible open connections
          debugPrint('Error closing database $dbName: $e');
        }
      }
    } catch (e) {
      debugPrint('Error closing databases: $e');
    }
  }
  
  // Helper method to restore SQLite databases
  static Future<bool> _restoreDatabases(Map<String, dynamic> databasesData) async {
    try {
      final databasesPath = await getDatabasesPath();
      
      for (final dbName in databasesData.keys) {
        // Skip unknown databases
        if (!_databaseFiles.contains(dbName)) {
          debugPrint('Skipping unknown database: $dbName');
          continue;
        }
        
        final dbPath = join(databasesPath, dbName);
        final base64Data = databasesData[dbName] as String;
        
        try {
          // Decode base64 data
          final bytes = base64Decode(base64Data);
          
          // Delete existing database if it exists
          final dbFile = File(dbPath);
          if (await dbFile.exists()) {
            await dbFile.delete();
          }
          
          // Write the new database file
          await dbFile.writeAsBytes(bytes);
          debugPrint('Restored database: $dbName');
        } catch (e) {
          debugPrint('Error restoring database $dbName: $e');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Error restoring databases: $e');
      return false;
    }
  }
// Get list of available backups from Google Drive
static Future<List<Map<String, dynamic>>> getGoogleDriveBackups() async {
  try {
    // 1. Sign in with Google
    final GoogleSignIn googleSignIn = GoogleSignIn.standard(
      scopes: [
        drive.DriveApi.driveFileScope,
        'email',
        'profile',
      ],
    );
    
    // Try to sign in silently first
    GoogleSignInAccount? account;
    try {
      account = await googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Silent sign-in failed: $e');
    }
    
    // If silent sign-in failed, try interactive sign-in
    if (account == null) {
      try {
        account = await googleSignIn.signIn();
      } catch (e) {
        debugPrint('Interactive sign-in failed: $e');
        return [];
      }
    }
    
    if (account == null) {
      debugPrint('Google Sign-In failed: user canceled');
      return [];
    }
    
    // 2. Get authentication client
    final authHeaders = await account.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    
    // 3. Initialize Drive API
    final driveApi = drive.DriveApi(authenticateClient);
    
    // 4. Search for backup files
    final fileList = await driveApi.files.list(
      q: "name contains '$backupFileName' and name contains '$backupExtension' and trashed = false",
      $fields: "files(id, name, createdTime, modifiedTime, size)",
    );
    
    final files = fileList.files ?? [];
    
    // 5. Create list of backup info
    List<Map<String, dynamic>> backups = [];
    
    for (final file in files) {
      try {
        final name = file.name ?? 'Unknown';
        final id = file.id ?? '';
        final modifiedTime = file.modifiedTime ?? DateTime.now();
        final size = file.size ?? '0';
        
        // Extract timestamp from filename
        String timestamp = '';
        final regex = RegExp(r'(\d{8}_\d{6})');
        final match = regex.firstMatch(name);
        
        if (match != null) {
          final dateString = match.group(1);
          if (dateString != null) {
            // Convert yyyyMMdd_HHmmss to ISO format
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
              // If parsing fails, use the modified time
              timestamp = modifiedTime.toIso8601String();
            }
          }
        } else {
          // If regex fails, use the modified time
          timestamp = modifiedTime.toIso8601String();
        }
        
        backups.add({
          'id': id,
          'path': id, // Use Drive file ID as path
          'name': name,
          'timestamp': timestamp,
          'version': 'Google Drive',
          'app_version': 'Unknown',
          'has_databases': true, // Assume Drive backups are full backups
          'size': int.parse(size),
          'is_drive': true,
        });
      } catch (e) {
        debugPrint('Error processing Drive file: $e');
      }
    }
    
    // Sort by timestamp (newest first)
    backups.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    
    return backups;
  } catch (e) {
    debugPrint('Error getting Google Drive backups: $e');
    return [];
  }
}
// Delete backup from Google Drive
static Future<bool> deleteBackupFromDrive(String fileId) async {
  try {
    // 1. Sign in with Google
    final GoogleSignIn googleSignIn = GoogleSignIn.standard(
      scopes: [drive.DriveApi.driveFileScope],
    );
    
    // Try to sign in silently first
    GoogleSignInAccount? account;
    try {
      account = await googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Silent sign-in failed: $e');
    }
    
    // If silent sign-in failed, try interactive sign-in
    if (account == null) {
      try {
        account = await googleSignIn.signIn();
      } catch (e) {
        debugPrint('Interactive sign-in failed: $e');
        return false;
      }
    }
    
    if (account == null) {
      debugPrint('Google Sign-In failed: user canceled');
      return false;
    }
    
    // 2. Get authentication client
    final authHeaders = await account.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    
    // 3. Initialize Drive API
    final driveApi = drive.DriveApi(authenticateClient);
    
    // 4. Delete the file
    await driveApi.files.delete(fileId);
    
    debugPrint('Deleted backup from Google Drive: $fileId');
    return true;
  } catch (e) {
    debugPrint('Error deleting backup from Drive: $e');
    return false;
  }
}

// Download backup from Google Drive
static Future<String?> downloadBackupFromDrive(String fileId) async {
  try {
    // 1. Sign in with Google
    final GoogleSignIn googleSignIn = GoogleSignIn.standard(
      scopes: [drive.DriveApi.driveFileScope],
    );
    
    // Try to sign in silently first
    GoogleSignInAccount? account;
    try {
      account = await googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Silent sign-in failed: $e');
    }
    
    // If silent sign-in failed, try interactive sign-in
    if (account == null) {
      try {
        account = await googleSignIn.signIn();
      } catch (e) {
        debugPrint('Interactive sign-in failed: $e');
        return null;
      }
    }
    
    if (account == null) {
      debugPrint('Google Sign-In failed: user canceled');
      return null;
    }
    
    // 2. Get authentication client
    final authHeaders = await account.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    
    // 3. Initialize Drive API
    final driveApi = drive.DriveApi(authenticateClient);
    
    // 4. Get file metadata to get the name
    final fileMetadata = await driveApi.files.get(fileId) as drive.File;
    final fileName = fileMetadata.name ?? 'downloaded_backup.json';
    
    // 5. Download file content
    final fileContent = await driveApi.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    
    // 6. Create backup directory
    final backupPath = await _createBackupDirectory();
    final localFilePath = '$backupPath/$fileName';
    
    // 7. Save file to local storage
    final file = File(localFilePath);
    final fileStream = file.openWrite();
    
    // Use completer to wait for download to finish
    final completer = Completer<void>();
    
    // Listen to the download stream
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
    
    debugPrint('Downloaded backup from Drive to: $localFilePath');
    return localFilePath;
  } catch (e) {
    debugPrint('Error downloading backup from Drive: $e');
    return null;
  }
}


// Restore from Google Drive backup
static Future<bool> restoreFromGoogleDrive(String fileId) async {
  try {
    // 1. Download the backup file
    final localFilePath = await downloadBackupFromDrive(fileId);
    
    if (localFilePath == null) {
      debugPrint('Failed to download backup from Google Drive');
      return false;
    }
    
    // 2. Restore from the downloaded file
    return await restoreData(localFilePath);
  } catch (e) {
    debugPrint('Error restoring from Google Drive: $e');
    return false;
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