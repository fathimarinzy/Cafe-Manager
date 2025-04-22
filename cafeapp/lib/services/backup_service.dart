import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class BackupService {
  static const String backupFileName = 'sims_resto_backup';
  static const String backupExtension = '.json';
  
  // Backup app data to a JSON file
  static Future<String?> backupData() async {
    try {
      // Check for storage permissions on Android
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            return null; // Permission denied
          }
        }
      }
      
      // Get shared preferences
      final prefs = await SharedPreferences.getInstance();
      final prefsMap = prefs.getKeys().fold<Map<String, dynamic>>(
        {},
        (map, key) {
          map[key] = prefs.get(key);
          return map;
        },
      );
      
      // Create backup data object
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0.0',
        'preferences': prefsMap,
      };
      
      // Convert to JSON
      final jsonData = jsonEncode(backupData);
      
      // Get documents directory
      final directory = await getApplicationDocumentsDirectory();
      
      // Create timestamp for filename
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/${backupFileName}_$timestamp$backupExtension';
      
      // Write file
      final file = File(filePath);
      await file.writeAsString(jsonData);
      
      return filePath;
    } catch (e) {
      debugPrint('Error creating backup: $e');
      return null;
    }
  }
  
  // Restore app data from a JSON file
  static Future<bool> restoreData(String filePath) async {
    try {
      // Read file
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }
      
      final jsonData = await file.readAsString();
      final backupData = jsonDecode(jsonData) as Map<String, dynamic>;
      
      // Check version for compatibility
      final version = backupData['version'];
      if (version != '1.0.0') {
        debugPrint('Unsupported backup version: $version');
        return false;
      }
      
      // Restore preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Clear existing preferences
      
      final prefsMap = backupData['preferences'] as Map<String, dynamic>;
      for (final key in prefsMap.keys) {
        final value = prefsMap[key];
        
        if (value is String) {
          await prefs.setString(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is List) {
          await prefs.setStringList(key, value.cast<String>());
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      return false;
    }
  }
  
  // Share backup file
  static Future<bool> shareBackup(String filePath) async {
    try {
      // This is a placeholder. In a real app, you would use a package like share_plus
      // to share the file with other apps
      debugPrint('Sharing backup file: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error sharing backup: $e');
      return false;
    }
  }
  
  // Get list of available backups
  static Future<List<Map<String, dynamic>>> getAvailableBackups() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory(directory.path);
      List<FileSystemEntity> files = await dir.list().toList();
      
      // Filter backup files
      files = files.where((file) {
        final name = file.path.split('/').last;
        return name.startsWith(backupFileName) && name.endsWith(backupExtension);
      }).toList();
      
      // Sort by date (newest first)
      files.sort((a, b) {
        return b.statSync().modified.compareTo(a.statSync().modified);
      });
      
      // Create info list
      List<Map<String, dynamic>> backups = [];
      
      for (final file in files) {
        try {
          final fileObj = File(file.path);
          final content = await fileObj.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          
          backups.add({
            'path': file.path,
            'name': file.path.split('/').last,
            'timestamp': data['timestamp'],
            'size': await fileObj.length(),  // Fixed: Using File object instead of FileSystemEntity
          });
        } catch (e) {
          // Skip invalid backup files
          debugPrint('Error reading backup file: $e');
        }
      }
      
      return backups;
    } catch (e) {
      debugPrint('Error getting available backups: $e');
      return [];
    }
  }
}