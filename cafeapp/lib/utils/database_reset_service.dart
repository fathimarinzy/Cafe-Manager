import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

class DatabaseResetService {
  // Singleton pattern
  static final DatabaseResetService _instance = DatabaseResetService._internal();
  factory DatabaseResetService() => _instance;
  DatabaseResetService._internal();
  
  // Database file names
  final List<String> _dbFiles = [
    'cafe_menu.db',
    'cafe_orders.db',
    'cafe_persons.db',
    'cafe_expenses.db'
  ];
  
  // Keep track of opened databases to ensure proper closing
  final Map<String, Database?> _openDatabases = {};
  
  // Force close all databases and delete database files
  Future<void> forceResetAllDatabases() async {
    try {
      debugPrint('🔄 Starting force reset of all databases...');
      
      // 1. Get the database path
      final dbPath = await getDatabasesPath();
      debugPrint('📁 Database path: $dbPath');
      
      // 2. Force close all database connections
      await _forceCloseDatabases();
      
      // 3. Wait to ensure all file handles are released
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 4. Delete each database file with retry logic
      int successCount = 0;
      int failCount = 0;
      
      for (final dbFile in _dbFiles) {
        final success = await _safelyDeleteDatabaseFile(dbPath, dbFile);
        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      }
      
      debugPrint('✅ Database reset complete: $successCount deleted, $failCount failed');
      
      // 5. Clear app cache files (optional, but helps with fresh start)
      await _clearAppCache();
      
      // 6. Clear any WAL (Write-Ahead Logging) and SHM files
      await _clearDatabaseAuxiliaryFiles(dbPath);
      
      debugPrint('✅ All databases have been force reset');
    } catch (e) {
      debugPrint('❌ Error in forceResetAllDatabases: $e');
      rethrow;
    }
  }
  
  // Force close all database connections
  Future<void> _forceCloseDatabases() async {
    try {
      debugPrint('🔒 Force closing all database connections...');
      
      final dbPath = await getDatabasesPath();
      
      // Close any databases we're tracking
      for (final dbName in _openDatabases.keys.toList()) {
        try {
          final db = _openDatabases[dbName];
          if (db != null && db.isOpen) {
            await db.close();
            debugPrint('  ✓ Closed tracked database: $dbName');
          }
          _openDatabases.remove(dbName);
        } catch (e) {
          debugPrint('  ⚠️ Error closing tracked database $dbName: $e');
        }
      }
      
      // Try to close any databases that might be open
      for (final dbFile in _dbFiles) {
        try {
          final fullPath = path.join(dbPath, dbFile);
          
          if (await File(fullPath).exists()) {
            // Try to open and immediately close the database
            // This ensures any lingering connections are closed
            try {
              final db = await databaseFactory.openDatabase(
                fullPath,
                options: OpenDatabaseOptions(
                  readOnly: true,
                  singleInstance: false,
                ),
              );
              await db.close();
              debugPrint('  ✓ Closed database: $dbFile');
            } catch (e) {
              debugPrint('  ⚠️ Could not close $dbFile: $e');
            }
          }
        } catch (e) {
          debugPrint('  ⚠️ Error processing $dbFile: $e');
        }
      }
      
      // Extra safety: wait a bit for file system to release handles
      await Future.delayed(const Duration(milliseconds: 200));
      
      debugPrint('✅ Database closing complete');
    } catch (e) {
      debugPrint('❌ Error in forceCloseDatabases: $e');
      // Continue anyway - we'll try to delete files regardless
    }
  }
  
  // Safely delete a database file with retry logic
  Future<bool> _safelyDeleteDatabaseFile(String dbPath, String dbFile) async {
    final fullPath = path.join(dbPath, dbFile);
    final file = File(fullPath);
    
    // Check if the file exists
    if (!await file.exists()) {
      debugPrint('  ℹ️ Database file does not exist: $dbFile');
      return true; // Not existing is considered success
    }
    
    // Try to delete with retry logic
    int retryCount = 0;
    const maxRetries = 5;
    
    while (retryCount < maxRetries) {
      try {
        // Method 1: Direct file deletion
        await file.delete();
        debugPrint('  ✅ Successfully deleted database file: $dbFile');
        return true;
      } catch (e) {
        retryCount++;
        debugPrint('  ⚠️ Attempt $retryCount to delete $dbFile failed: $e');
        
        // Method 2: Try using sqflite's deleteDatabase
        if (retryCount == 2) {
          try {
            await databaseFactory.deleteDatabase(fullPath);
            debugPrint('  ✅ Deleted database using databaseFactory: $dbFile');
            return true;
          } catch (e2) {
            debugPrint('  ⚠️ Alternative delete method failed for $dbFile: $e2');
          }
        }
        
        // Method 3: Try to rename first, then delete
        if (retryCount == 3) {
          try {
            final tempPath = '$fullPath.old';
            await file.rename(tempPath);
            await File(tempPath).delete();
            debugPrint('  ✅ Deleted via rename for $dbFile');
            return true;
          } catch (e3) {
            debugPrint('  ⚠️ Rename-delete method failed for $dbFile: $e3');
          }
        }
        
        if (retryCount >= maxRetries) {
          debugPrint('  ❌ Maximum retries reached for $dbFile');
          break;
        }
        
        // Wait progressively longer between retries
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    // If we get here, all delete attempts failed
    debugPrint('  ❌ FAILED to delete database file: $dbFile');
    return false;
  }
  
  // Clear WAL (Write-Ahead Logging) and SHM (Shared Memory) files
  Future<void> _clearDatabaseAuxiliaryFiles(String dbPath) async {
    try {
      debugPrint('🧹 Clearing database auxiliary files...');
      
      final dbDir = Directory(dbPath);
      if (!await dbDir.exists()) {
        return;
      }
      
      final entities = await dbDir.list().toList();
      int deletedCount = 0;
      
      for (final entity in entities) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          
          // Delete WAL, SHM, and journal files
          if (fileName.endsWith('-wal') || 
              fileName.endsWith('-shm') || 
              fileName.endsWith('-journal')) {
            try {
              await entity.delete();
              deletedCount++;
              debugPrint('  ✓ Deleted auxiliary file: $fileName');
            } catch (e) {
              debugPrint('  ⚠️ Could not delete auxiliary file $fileName: $e');
            }
          }
        }
      }
      
      if (deletedCount > 0) {
        debugPrint('✅ Deleted $deletedCount auxiliary files');
      } else {
        debugPrint('  ℹ️ No auxiliary files to delete');
      }
    } catch (e) {
      debugPrint('❌ Error clearing auxiliary files: $e');
      // Continue anyway
    }
  }
  
  // Clear application cache
  Future<void> _clearAppCache() async {
    try {
      debugPrint('🧹 Clearing app cache...');
      
      final cacheDir = await getTemporaryDirectory();
      
      if (!await cacheDir.exists()) {
        debugPrint('  ℹ️ Cache directory does not exist');
        return;
      }
      
      // Delete cache directory contents
      final entities = await cacheDir.list().toList();
      int deletedCount = 0;
      
      for (final entity in entities) {
        try {
          if (entity is File) {
            await entity.delete();
            deletedCount++;
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
            deletedCount++;
          }
        } catch (e) {
          debugPrint('  ⚠️ Error deleting cache entity ${path.basename(entity.path)}: $e');
        }
      }
      
      if (deletedCount > 0) {
        debugPrint('✅ App cache cleared: $deletedCount items deleted');
      } else {
        debugPrint('  ℹ️ Cache was already empty');
      }
    } catch (e) {
      debugPrint('❌ Error clearing app cache: $e');
      // Continue anyway
    }
  }
  
  // Optional: Method to reset only specific database
  Future<bool> resetSpecificDatabase(String dbName) async {
    try {
      debugPrint('🔄 Resetting specific database: $dbName');
      
      final dbPath = await getDatabasesPath();
      final fullPath = path.join(dbPath, dbName);
      
      // Close the database if it's open
      try {
        final db = await databaseFactory.openDatabase(
          fullPath,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
        );
        await db.close();
      } catch (e) {
        debugPrint('  ⚠️ Could not close $dbName: $e');
      }
      
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Delete the database
      final success = await _safelyDeleteDatabaseFile(dbPath, dbName);
      
      // Delete auxiliary files
      await _deleteAuxiliaryFilesForDatabase(dbPath, dbName);
      
      return success;
    } catch (e) {
      debugPrint('❌ Error resetting database $dbName: $e');
      return false;
    }
  }
  
  // Delete auxiliary files for a specific database
  Future<void> _deleteAuxiliaryFilesForDatabase(String dbPath, String dbName) async {
    final baseName = dbName.replaceAll('.db', '');
    final auxFiles = [
      '$baseName.db-wal',
      '$baseName.db-shm',
      '$baseName.db-journal',
    ];
    
    for (final auxFile in auxFiles) {
      try {
        final file = File(path.join(dbPath, auxFile));
        if (await file.exists()) {
          await file.delete();
          debugPrint('  ✓ Deleted auxiliary file: $auxFile');
        }
      } catch (e) {
        debugPrint('  ⚠️ Could not delete auxiliary file $auxFile: $e');
      }
    }
  }
  
  // Check database status (useful for debugging)
  Future<Map<String, dynamic>> getDatabaseStatus() async {
    try {
      final dbPath = await getDatabasesPath();
      final status = <String, dynamic>{};
      
      for (final dbFile in _dbFiles) {
        final fullPath = path.join(dbPath, dbFile);
        final file = File(fullPath);
        
        status[dbFile] = {
          'exists': await file.exists(),
          'size': await file.exists() ? await file.length() : 0,
        };
      }
      
      return status;
    } catch (e) {
      debugPrint('❌ Error getting database status: $e');
      return {};
    }
  }
}