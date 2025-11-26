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
    'cafe_expenses.db',
    'credit_transactions.db'
  ];
  
  // Force close all databases and delete database files
  Future<void> forceResetAllDatabases() async {
    try {
      debugPrint('Starting force reset of all databases...');
      
      // 1. Get the database path
      final dbPath = await getDatabasesPath();
      debugPrint('Database path: $dbPath');
      
      // 2. Make sure all databases are closed by SQLite
      await _forceCloseDatabases();
      
      // 3. Delay to ensure all connections are closed
      await Future.delayed(const Duration(seconds: 1));
      
      // 4. Delete each database file with retry logic
      for (final dbFile in _dbFiles) {
        await _safelyDeleteDatabaseFile(dbPath, dbFile);
      }
      
      // 5. Clear app cache files as well (optional, but helps with fresh start)
      await _clearAppCache();
      
      debugPrint('All databases have been force reset');
    } catch (e) {
      debugPrint('Error in forceResetAllDatabases: $e');
      rethrow;
    }
  }
  
  // Force close all database connections by closing SQLite
  Future<void> _forceCloseDatabases() async {
    try {
      debugPrint('Force closing all database connections...');
      
      // This will close all database connections managed by sqflite
      await databaseFactory.deleteDatabase('dummy.db');
      
      // For extra safety, try to individually close databases 
      final dbPath = await getDatabasesPath();
      
      for (final dbFile in _dbFiles) {
        try {
          final fullPath = path.join(dbPath, dbFile);
          if (await File(fullPath).exists()) {
            // Try to close specific database connections
            final db = await openDatabase(fullPath, readOnly: true);
            await db.close();
            debugPrint('Closed database: $dbFile');
          }
        } catch (e) {
          // Ignore errors here, we're just trying to close everything
          debugPrint('Note: Could not close $dbFile: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in forceCloseDatabases: $e');
      // Continue anyway
    }
  }
  
  // Safely delete a database file with retry logic
  Future<void> _safelyDeleteDatabaseFile(String dbPath, String dbFile) async {
    final fullPath = path.join(dbPath, dbFile);
    final file = File(fullPath);
    
    // Check if the file exists
    if (!await file.exists()) {
      debugPrint('Database file does not exist: $dbFile');
      return;
    }
    
    // Try to delete with retry logic
    int retryCount = 0;
    const maxRetries = 5;
    
    while (retryCount < maxRetries) {
      try {
        // Try to delete the file
        await file.delete();
        debugPrint('Successfully deleted database file: $dbFile');
        return;
      } catch (e) {
        retryCount++;
        debugPrint('Attempt $retryCount to delete $dbFile failed: $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for $dbFile');
          break;
        }
        
        // Try an alternative approach - delete using databaseFactory
        try {
          await databaseFactory.deleteDatabase(fullPath);
          debugPrint('Deleted database using databaseFactory: $dbFile');
          return;
        } catch (e2) {
          debugPrint('Alternative delete method failed for $dbFile: $e2');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    // If we get here, all delete attempts failed
    debugPrint('WARNING: Failed to delete database file: $dbFile');
  }
  
  // Clear application cache
  Future<void> _clearAppCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      
      if (await cacheDir.exists()) {
        // Delete cache directory contents
        final entities = await cacheDir.list().toList();
        
        for (final entity in entities) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (e) {
            debugPrint('Error deleting cache entity ${entity.path}: $e');
          }
        }
        
        debugPrint('App cache cleared');
      }
    } catch (e) {
      debugPrint('Error clearing app cache: $e');
      // Continue anyway
    }
  }
}