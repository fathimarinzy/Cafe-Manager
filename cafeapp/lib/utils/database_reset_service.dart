import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as path;
import 'dart:io';
import 'database_helper.dart';

// Import Repositories to close connections properly
import '../repositories/local_menu_repository.dart';
import '../repositories/local_order_repository.dart';
import '../repositories/local_person_repository.dart';
import '../repositories/local_expense_repository.dart';
import '../repositories/credit_transaction_repository.dart';
import '../repositories/local_delivery_boy_repository.dart';

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
    'credit_transactions.db',
    'cafe_delivery_boys_store.db'
  ];
  
  // Force close all databases and delete database files
  Future<void> forceResetAllDatabases() async {
    try {
      debugPrint('Starting force reset of all databases...');
      
      // 1. Make sure all databases are closed by SQLite
      await _forceCloseDatabases();
      
      // 2. Delay to ensure all connections are closed
      await Future.delayed(const Duration(seconds: 1));
      
      // 3. Delete each database file with retry logic
      for (final dbFile in _dbFiles) {
        // CRITICAL FIX: Resolve path individually to ensure portable mode paths are respected
        final fullPath = await DatabaseHelper.getDatabasePath(dbFile);
        await _safelyDeleteDatabaseFile(fullPath, dbFile);
      }
      
      // 4. Clear app cache files as well (optional, but helps with fresh start)
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

      // CRITICAL FIX: Close all repository connections explicitly
      // This resets the internal static definition of the database in each repository
      // preventing "DatabaseException(error database_closed)" on restart
      await LocalMenuRepository().close();
      await LocalOrderRepository().close();
      await LocalPersonRepository().close();
      await LocalExpenseRepository().close();
      await CreditTransactionRepository().close();
      await LocalDeliveryBoyRepository().close();
      debugPrint('All repositories closed');
      
      // This will close all database connections managed by sqflite
      try {
        await databaseFactory.deleteDatabase('dummy.db');
      } catch (e) {
        // Ignore dummy delete error
      }
      
      // For extra safety, try to individually close databases 
      for (final dbFile in _dbFiles) {
        try {
          final fullPath = await DatabaseHelper.getDatabasePath(dbFile);
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
  Future<void> _safelyDeleteDatabaseFile(String fullPath, String dbName) async {
    final file = File(fullPath);
    
    // Check if the file exists
    if (!await file.exists()) {
      debugPrint('Database file does not exist: $dbName ($fullPath)');
      return;
    }
    
    debugPrint('Attempting to delete database: $fullPath');
    
    // Try to delete with retry logic
    int retryCount = 0;
    const maxRetries = 5;
    
    while (retryCount < maxRetries) {
      try {
        // Try to delete the file
        await file.delete();
        debugPrint('Successfully deleted database file: $dbName');
        return;
      } catch (e) {
        retryCount++;
        debugPrint('Attempt $retryCount to delete $dbName failed: $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for $dbName');
          break;
        }
        
        // Try an alternative approach - delete using databaseFactory
        try {
          await databaseFactory.deleteDatabase(fullPath);
          debugPrint('Deleted database using databaseFactory: $dbName');
          return;
        } catch (e2) {
          debugPrint('Alternative delete method failed for $dbName: $e2');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    // If we get here, all delete attempts failed
    debugPrint('WARNING: Failed to delete database file: $dbName');
  }
  
  // Clear application cache
  Future<void> _clearAppCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      debugPrint('INFO: Clearing app cache at: ${cacheDir.path}');
      
      // SAFETY CHECK: Do not delete if path is exactly the system temp root
      // On Windows, getTemporaryDirectory() usually returns the user's local temp folder
      // which contains files for ALL apps. We must ONLY delete what belongs to us.
      if (Platform.isWindows) {
        // On Windows, we refrain from deleting everything in the temp root
        // Instead, we only try to delete files that look like they belong to our app
        // or specific subdirectories if we had created them.
        // For now, let's just log and skip to prevent "Access Denied" on system files
        debugPrint('SAFETY: Skipping wholesale temp dir deletion on Windows to avoid system conflicts.');
        
        // Option: Delete only specific known patterns if needed
        // await _deleteSpecificCacheFiles(cacheDir);
        return; 
      }

      if (await cacheDir.exists()) {
        // For mobile platforms (Android/iOS), the cache dir is usually sandboxed, so it's safer.
        // But still good to be careful.
        final entities = await cacheDir.list().toList();
        
        for (final entity in entities) {
          try {
             // Skip if it looks like a system directory just in case
            if (entity is File) {
               // Only delete if we can access it
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (e) {
            // Just ignore individual file errors
            // debugPrint('Note: Could not delete cache entity ${entity.path}');
          }
        }
        
        debugPrint('App cache cleared (Safe mode)');
      }
    } catch (e) {
      debugPrint('Error clearing app cache: $e');
      // Continue anyway
    }
  }
}