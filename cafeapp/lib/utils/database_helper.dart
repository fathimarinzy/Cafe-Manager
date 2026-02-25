import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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
  static const String creditTransactionsDbName = 'credit_transactions.db';
  static const String deliveryBoysStoreDbName = 'cafe_delivery_boys_store.db';
  
  // Database references
  static Database? _menuDb;
  static Database? _ordersDb;
  static Database? _personsDb;
  static Database? _expensesDb;
  static Database? _creditTransactionsDb;
  static Database? _deliveryBoysStoreDb;
  
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
  
  /// Get the proper database path based on build mode and platform
  /// Uses a STABLE user-profile path so data persists across app updates/relocations.
  static Future<String> getDatabasePath(String dbName) async {
  // DESKTOP: Use stable user-profile path (AppData/Roaming on Windows)
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    try {
      // PRIMARY: Use getApplicationSupportDirectory() for a stable, 
      // user-profile-based path that doesn't change when the EXE moves.
      // Windows: C:\Users\<user>\AppData\Roaming\com.example.cafeapp\databases\
      // macOS:   ~/Library/Application Support/com.example.cafeapp/databases/
      // Linux:   ~/.local/share/com.example.cafeapp/databases/
      final appSupportDir = await getApplicationSupportDirectory();
      final stableDbDir = Directory('${appSupportDir.path}/databases');
      
      if (!await stableDbDir.exists()) {
        await stableDbDir.create(recursive: true);
      }
      
      final stableDbPath = '${stableDbDir.path}/$dbName';
      final stableFile = File(stableDbPath);
      
      // If the database already exists at the stable path, use it directly
      if (await stableFile.exists()) {
        debugPrint('📁 STABLE Database path: $stableDbPath');
        return stableDbPath;
      }
      
      // AUTO-MIGRATION: Check old locations and migrate if found
      // This ensures existing users don't lose their data after updating
      await _migrateFromOldPaths(dbName, stableDbDir.path);
      
      debugPrint('📁 STABLE Database path: $stableDbPath');
      return stableDbPath;
    } catch (e) {
      debugPrint('⚠️ Error creating stable database path: $e');
    }
  }
  
  // MOBILE / FALLBACK: Default path
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    final dbPath = await getDatabasesPath();
    final fullPath = join(dbPath, dbName);
    debugPrint('📁 Mobile database path: $fullPath');
    return fullPath;
  }
  
  // ULTIMATE FALLBACK
  final dbPath = await getDatabasesPath();
  final fullPath = join(dbPath, dbName);
  debugPrint('📁 Default database path: $fullPath');
  return fullPath;
}

  /// Migrate databases from old locations to the new stable path.
  /// Searches in order: portable mode path (next to EXE), Documents/SimsCafe path.
  static Future<void> _migrateFromOldPaths(String dbName, String stableDir) async {
    final List<String> oldPaths = [];
    
    // 1. Check old PORTABLE path (next to EXE)
    try {
      final executableDir = Directory(Platform.resolvedExecutable).parent;
      final portablePath = '${executableDir.path}/AppData/databases/$dbName';
      oldPaths.add(portablePath);
    } catch (e) {
      debugPrint('⚠️ Could not determine executable directory: $e');
    }
    
    // 2. Check old DOCUMENTS path (SimsCafe/databases)
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final docPath = '${appDocDir.path}/SimsCafe/databases/$dbName';
      oldPaths.add(docPath);
    } catch (e) {
      debugPrint('⚠️ Could not determine documents directory: $e');
    }
    
    // Try each old path and migrate the first one found
    for (final oldPath in oldPaths) {
      try {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          final newPath = '$stableDir/$dbName';
          debugPrint('🔄 MIGRATING database: $oldPath → $newPath');
          
          // Copy (not move) so the old location still works as backup
          await oldFile.copy(newPath);
          
          // Also copy WAL and SHM files if they exist (SQLite journal files)
          final walFile = File('$oldPath-wal');
          if (await walFile.exists()) {
            await walFile.copy('$newPath-wal');
          }
          final shmFile = File('$oldPath-shm');
          if (await shmFile.exists()) {
            await shmFile.copy('$newPath-shm');
          }
          
          debugPrint('✅ Successfully migrated $dbName from old location');
          return; // Stop after first successful migration
        }
      } catch (e) {
        debugPrint('⚠️ Error checking/migrating from $oldPath: $e');
      }
    }
    
    debugPrint('ℹ️ No old database found for $dbName - will create fresh');
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
  Future<Database> get creditTransactionsDb async {
    await _ensurePlatformInitialized();
    if (_creditTransactionsDb != null && _creditTransactionsDb!.isOpen) return _creditTransactionsDb!;
    _creditTransactionsDb = await _openDatabase(creditTransactionsDbName);
    return _creditTransactionsDb!;
  }
  
  Future<Database> get deliveryBoysStoreDb async {
    await _ensurePlatformInitialized();
    if (_deliveryBoysStoreDb != null && _deliveryBoysStoreDb!.isOpen) return _deliveryBoysStoreDb!;
    _deliveryBoysStoreDb = await _openDatabase(deliveryBoysStoreDbName);
    return _deliveryBoysStoreDb!;
  }
  
  // Ensure platform is initialized before any database operations
  Future<void> _ensurePlatformInitialized() async {
    if (!_platformInitialized) {
      await initializePlatform();
    }
  }
  
  // Generic function to open a database with proper path handling
  Future<Database> _openDatabase(String dbName) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        // Use the new path method that handles release vs debug mode
        final path = await getDatabasePath(dbName);
        
        debugPrint('Initializing $dbName at: $path (Attempt ${retryCount + 1})');
        
        // If database doesn't exist, this will create it
        final db = await openDatabase(path);
        
        debugPrint('✅ $dbName opened successfully');
        return db;
      } catch (e) {
        retryCount++;
        debugPrint('❌ Error opening database $dbName (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('❌ Maximum retries reached for opening $dbName');
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
      if (_creditTransactionsDb != null && _creditTransactionsDb!.isOpen) {
        await _creditTransactionsDb!.close();
        _creditTransactionsDb = null;
        debugPrint('Closed credit transactions database');
      }
      
      if (_deliveryBoysStoreDb != null && _deliveryBoysStoreDb!.isOpen) {
        await _deliveryBoysStoreDb!.close();
        _deliveryBoysStoreDb = null;
        debugPrint('Closed delivery boys store database');
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
      
      // List of database files to delete
      final dbFiles = [menuDbName, ordersDbName, personsDbName, expensesDbName, creditTransactionsDbName, deliveryBoysStoreDbName];
      
      // Delete each database file
      for (final dbFile in dbFiles) {
        try {
          final filePath = await getDatabasePath(dbFile);
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
  
  // Get database directory for user reference
  static Future<String> getDatabaseDirectory() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final appSupportDir = await getApplicationSupportDirectory();
      return '${appSupportDir.path}/databases';
    }
    return await getDatabasesPath();
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
  
  // Get database info for debugging
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      final dbDir = await getDatabaseDirectory();
      final menuPath = await getDatabasePath(menuDbName);
      final ordersPath = await getDatabasePath(ordersDbName);
      final personsPath = await getDatabasePath(personsDbName);
      final expensesPath = await getDatabasePath(expensesDbName);
      final creditTransactionsPath = await getDatabasePath(creditTransactionsDbName);
      final deliveryBoysStorePath = await getDatabasePath(deliveryBoysStoreDbName);
      
      return {
        'platform': platformName,
        'buildMode': kReleaseMode ? 'Release' : 'Debug',
        'databaseDirectory': dbDir,
        'databases': {
          'menu': {
            'path': menuPath,
            'exists': await File(menuPath).exists(),
            'isOpen': _menuDb != null && _menuDb!.isOpen,
          },
          'orders': {
            'path': ordersPath,
            'exists': await File(ordersPath).exists(),
            'isOpen': _ordersDb != null && _ordersDb!.isOpen,
          },
          'persons': {
            'path': personsPath,
            'exists': await File(personsPath).exists(),
            'isOpen': _personsDb != null && _personsDb!.isOpen,
          },
          'expenses': {
            'path': expensesPath,
            'exists': await File(expensesPath).exists(),
            'isOpen': _expensesDb != null && _expensesDb!.isOpen,
          },
          'creditTransactions': {
            'path': creditTransactionsPath,
            'exists': await File(creditTransactionsPath).exists(),
            'isOpen': _creditTransactionsDb != null && _creditTransactionsDb!.isOpen,
          },
          'deliveryBoysStore': {
            'path': deliveryBoysStorePath,
            'exists': await File(deliveryBoysStorePath).exists(),
            'isOpen': _deliveryBoysStoreDb != null && _deliveryBoysStoreDb!.isOpen,
          },
        },
      };
    } catch (e) {
      debugPrint('Error getting database info: $e');
      return {
        'error': e.toString(),
      };
    }
  }
}