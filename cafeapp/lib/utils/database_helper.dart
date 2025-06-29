import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
  
  // Database names
  static const String menuDbName = 'cafe_menu.db';
  static const String ordersDbName = 'cafe_orders.db';
  static const String personsDbName = 'cafe_persons.db';
  static const String expensesDbName = 'cafe_expenses.db';
  
  // Database references
  static Database? _menuDb;
  static Database? _ordersDb;
  static Database? _personsDb;
  static Database? _expensesDb;
  
  // Database getters with proper checks
  Future<Database> get menuDb async {
    if (_menuDb != null && _menuDb!.isOpen) return _menuDb!;
    _menuDb = await _openDatabase(menuDbName);
    return _menuDb!;
  }
  
  Future<Database> get ordersDb async {
    if (_ordersDb != null && _ordersDb!.isOpen) return _ordersDb!;
    _ordersDb = await _openDatabase(ordersDbName);
    return _ordersDb!;
  }
  
  Future<Database> get personsDb async {
    if (_personsDb != null && _personsDb!.isOpen) return _personsDb!;
    _personsDb = await _openDatabase(personsDbName);
    return _personsDb!;
  }
  
  Future<Database> get expensesDb async {
    if (_expensesDb != null && _expensesDb!.isOpen) return _expensesDb!;
    _expensesDb = await _openDatabase(expensesDbName);
    return _expensesDb!;
  }
  
  // Generic function to open a database
  Future<Database> _openDatabase(String dbName) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, dbName);
        
        debugPrint('Opening database: $dbName (Attempt ${retryCount + 1})');
        
        // If database doesn't exist, this will create it
        return await openDatabase(path);
      } catch (e) {
        retryCount++;
        debugPrint('Error opening database $dbName (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for opening $dbName');
          rethrow;
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    throw Exception('Failed to open database $dbName after $maxRetries attempts');
  }
  
  // Close all database connections
  Future<void> closeAllDatabases() async {
    try {
      if (_menuDb != null && _menuDb!.isOpen) {
        await _menuDb!.close();
        _menuDb = null;
        debugPrint('Closed menu database');
      }
      
      if (_ordersDb != null && _ordersDb!.isOpen) {
        await _ordersDb!.close();
        _ordersDb = null;
        debugPrint('Closed orders database');
      }
      
      if (_personsDb != null && _personsDb!.isOpen) {
        await _personsDb!.close();
        _personsDb = null;
        debugPrint('Closed persons database');
      }
      
      if (_expensesDb != null && _expensesDb!.isOpen) {
        await _expensesDb!.close();
        _expensesDb = null;
        debugPrint('Closed expenses database');
      }
      
      debugPrint('All database connections closed');
    } catch (e) {
      debugPrint('Error closing databases: $e');
    }
  }
  
  // Reset all databases by deleting the files
  Future<void> resetAllDatabases() async {
    try {
      // First close all connections
      await closeAllDatabases();
      
      // Wait to ensure connections are fully closed
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Get database path
      final dbPath = await getDatabasesPath();
      
      // List of database files to delete
      final dbFiles = [menuDbName, ordersDbName, personsDbName, expensesDbName];
      
      // Delete each database file
      for (final dbFile in dbFiles) {
        try {
          final filePath = join(dbPath, dbFile);
          final file = File(filePath);
          
          if (await file.exists()) {
            await file.delete();
            debugPrint('Deleted database file: $dbFile');
          }
        } catch (e) {
          debugPrint('Error deleting database file $dbFile: $e');
        }
      }
      
      debugPrint('All database files have been reset');
    } catch (e) {
      debugPrint('Error resetting databases: $e');
      rethrow;
    }
  }
  
  // Execute query with retry mechanism
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    String operationName = 'database operation',
    int maxRetries = 3,
  }) async {
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        retryCount++;
        debugPrint('Error executing $operationName (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for $operationName');
          rethrow;
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    throw Exception('Failed to execute $operationName after $maxRetries attempts');
  }
}