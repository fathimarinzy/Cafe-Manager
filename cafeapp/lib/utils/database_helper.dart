import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Add this import
import 'package:path/path.dart';
import 'dart:io';

class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
  
  // Platform initialization flag
  static bool _platformInitialized = false;
  
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
  
  /// Initialize SQLite for the current platform - MUST be called first
  static Future<void> initializePlatform() async {
    if (_platformInitialized) return;

    if (kIsWeb) {
      // Web doesn't support SQLite directly
      throw UnsupportedError('SQLite is not supported on web platform');
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop platforms need sqflite_ffi
      debugPrint('Initializing SQLite for desktop platform: ${Platform.operatingSystem}');
      
      try {
        // Initialize ffi loader if needed
        sqfliteFfiInit();
        
        // Set the database factory to use ffi
        databaseFactory = databaseFactoryFfi;
        
        debugPrint('SQLite initialized successfully for desktop');
      } catch (e) {
        debugPrint('Error initializing SQLite for desktop: $e');
        rethrow;
      }
    } else {
      // Mobile platforms (Android/iOS) use regular sqflite
      debugPrint('Using default SQLite for mobile platform: ${Platform.operatingSystem}');
      // No additional setup needed for mobile
    }

    _platformInitialized = true;
  }

  /// Check if the current platform supports SQLite
  static bool get isSupported {
    return !kIsWeb;
  }

  /// Get a descriptive name for the current platform
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }
  
  // Database getters with proper checks and platform initialization
  Future<Database> get menuDb async {
    await _ensurePlatformInitialized();
    if (_menuDb != null && _menuDb!.isOpen) return _menuDb!;
    _menuDb = await _openDatabase(menuDbName);
    return _menuDb!;
  }
  
  Future<Database> get ordersDb async {
    await _ensurePlatformInitialized();
    if (_ordersDb != null && _ordersDb!.isOpen) return _ordersDb!;
    _ordersDb = await _openDatabase(ordersDbName);
    return _ordersDb!;
  }
  
  Future<Database> get personsDb async {
    await _ensurePlatformInitialized();
    if (_personsDb != null && _personsDb!.isOpen) return _personsDb!;
    _personsDb = await _openDatabase(personsDbName);
    return _personsDb!;
  }
  
  Future<Database> get expensesDb async {
    await _ensurePlatformInitialized();
    if (_expensesDb != null && _expensesDb!.isOpen) return _expensesDb!;
    _expensesDb = await _openDatabase(expensesDbName);
    return _expensesDb!;
  }
  
  // Ensure platform is initialized before any database operations
  Future<void> _ensurePlatformInitialized() async {
    if (!_platformInitialized) {
      await initializePlatform();
    }
  }
  
  // Generic function to open a database
  Future<Database> _openDatabase(String dbName) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, dbName);
        
        debugPrint('Opening database: $dbName at $path (Attempt ${retryCount + 1})');
        
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
  
  // Test database connection
  Future<bool> testConnection() async {
    try {
      await _ensurePlatformInitialized();
      final db = await menuDb;
      final result = await db.rawQuery('SELECT 1 as test');
      debugPrint('Database connection test successful: $result');
      return true;
    } catch (e) {
      debugPrint('Database connection test failed: $e');
      return false;
    }
  }
}