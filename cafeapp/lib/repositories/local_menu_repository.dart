// lib/repositories/local_menu_repository.dart
import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
import '../models/menu_item.dart';
import 'package:flutter/foundation.dart';
import '../utils/database_helper.dart';

class LocalMenuRepository {
  static Database? _database;
  static final LocalMenuRepository _instance = LocalMenuRepository._internal();
  
  // Factory constructor
  factory LocalMenuRepository() {
    return _instance;
  }
  
  // Private constructor
  LocalMenuRepository._internal();
  
  static Future<Database>? _dbOpenFuture;
  
  static bool _isResetting = false; // 🛡️ Guard flag

  // Get database instance with retry logic and race condition prevention
  Future<Database> get database async {
    if (_isResetting) {
      throw StateError('Database is currently resetting - access denied');
    }

    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    
    if (_dbOpenFuture != null) return _dbOpenFuture!;
    
    _dbOpenFuture = _initDatabase();
    
    try {
      _database = await _dbOpenFuture;
      return _database!;
    } catch (e) {
      _dbOpenFuture = null;
      rethrow;
    }
  }

  // Initialize database with retry logic
  Future<Database> _initDatabase() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final path = await DatabaseHelper.getDatabasePath('cafe_menu.db');
        
        debugPrint('Initializing menu database at: $path (Attempt ${retryCount + 1})');
        
        // Open the database with explicit version and onCreate handler
        return await openDatabase(
          path,
          version: 3,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL;');
      },
      onCreate: (db, version) async {
            debugPrint('Creating menu_items table...');
            await db.execute('''
              CREATE TABLE menu_items (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                price REAL NOT NULL,
                imageUrl TEXT,
                category TEXT NOT NULL,
                isAvailable INTEGER NOT NULL,
                isDeleted INTEGER NOT NULL DEFAULT 0,
                lastUpdated TEXT NOT NULL,
                taxExempt INTEGER NOT NULL DEFAULT 0,
                isPerPlate INTEGER NOT NULL DEFAULT 0
              )
            ''');
            debugPrint('menu_items table created successfully');
          },
          onUpgrade: (db, oldVersion, newVersion) async {
          debugPrint('Upgrading menu database from version $oldVersion to $newVersion');
          
          if (oldVersion < 2) {
            // Add taxExempt column if upgrading from version 1
            try {
              await db.execute('''
                ALTER TABLE menu_items ADD COLUMN taxExempt INTEGER NOT NULL DEFAULT 0
              ''');
              debugPrint('Added taxExempt column to menu_items table');
            } catch (e) {
              debugPrint('Error adding taxExempt column (may already exist): $e');
            }
          }

          if (oldVersion < 3) {
            // Add isPerPlate column
            try {
              await db.execute('''
                ALTER TABLE menu_items ADD COLUMN isPerPlate INTEGER NOT NULL DEFAULT 0
              ''');
              debugPrint('Added isPerPlate column to menu_items table');
            } catch (e) {
              debugPrint('Error adding isPerPlate column: $e');
            }
          }
        },
          onOpen: (db) {
            debugPrint('Menu database opened successfully');
          },
        );
      } catch (e) {
        retryCount++;
        debugPrint('Error initializing menu database (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for menu database initialization');
          rethrow;
        }
        
        // Close any existing database connection
        try {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
        } catch (closeError) {
          debugPrint('Error closing existing database: $closeError');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    // This should never be reached due to the rethrow above,
    // but Dart requires a return statement
    throw Exception('Failed to initialize menu database after $maxRetries attempts');
  }

  // Save menu items to local database with improved error handling
  Future<void> saveMenuItems(List<MenuItem> items) async {
    try {
      final db = await database;
      final batch = db.batch();
      
      for (final item in items) {
        batch.insert(
          'menu_items',
          {
            'id': item.id,
            'name': item.name,
            'price': item.price,
            'imageUrl': item.imageUrl,
            'category': item.category,
            'isAvailable': item.isAvailable ? 1 : 0,
            'isDeleted': 0,
            'lastUpdated': DateTime.now().toIso8601String(),
            'taxExempt': item.taxExempt ? 1 : 0,
            'isPerPlate': item.isPerPlate ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit();
      debugPrint('Saved ${items.length} items to local database');
    } catch (e) {
      debugPrint('Error saving menu items: $e');
      
      // Reset database connection on error
      try {
        if (_database != null) {
          await _database!.close();
          _database = null;
        }
      } catch (closeError) {
        debugPrint('Error closing database after error: $closeError');
      }
      
      rethrow;
    }
  }

  // Get all menu items from local database with retry logic
Future<List<MenuItem>> getMenuItems() async {
  int retryCount = 0;
  const maxRetries = 3;
  
  while (retryCount < maxRetries) {
    try {
      final db = await database;
      final maps = await db.query(
        'menu_items',
        where: 'isDeleted = ?',
        whereArgs: [0],
      );
      
      debugPrint('📊 Loading ${maps.length} menu items from database');
      
      final items = List.generate(maps.length, (i) {
        final imageUrl = maps[i]['imageUrl'] as String;
        


        
        return MenuItem(
          id: maps[i]['id'] as String,
          name: maps[i]['name'] as String,
          price: maps[i]['price'] as double,
          imageUrl: imageUrl,
          category: maps[i]['category'] as String,
          isAvailable: maps[i]['isAvailable'] == 1,
          taxExempt: maps[i]['taxExempt'] == 1,
          isPerPlate: maps[i]['isPerPlate'] == 1,
        );
      });
      
      return items;
    } catch (e) {
      retryCount++;
      debugPrint('❌ Error getting menu items (Attempt $retryCount): $e');
      
      if (retryCount >= maxRetries) {
        debugPrint('Maximum retries reached for getting menu items');
        return [];
      }
      
      // Reset database connection
      try {
        if (_database != null) {
          await _database!.close();
          _database = null;
        }
      } catch (closeError) {
        debugPrint('Error closing database after error: $closeError');
      }
      
      await Future.delayed(Duration(milliseconds: 500 * retryCount));
    }
  }
  
  return [];
}
  
  // Add a new menu item locally with improved error handling
  Future<MenuItem> addMenuItem(MenuItem item) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final db = await database;
        final timestamp = DateTime.now().toIso8601String();
        
        // Make sure item has a valid ID
        final String itemId = item.id.isNotEmpty ? 
            item.id : 
            'local_${DateTime.now().millisecondsSinceEpoch}';
        
        final newItem = MenuItem(
          id: itemId,
          name: item.name,
          price: item.price,
          imageUrl: item.imageUrl,
          category: item.category,
          isAvailable: item.isAvailable,
          taxExempt: item.taxExempt,
          isPerPlate: item.isPerPlate,
        );
         // ⭐ CRITICAL: Ensure the boolean is converted to int correctly
        final int taxExemptValue = newItem.taxExempt ? 1 : 0;
        debugPrint('🔍 Repository - taxExempt converted to int: $taxExemptValue');

        // Insert the new item
        await db.insert(
          'menu_items',
          {
            'id': newItem.id,
            'name': newItem.name,
            'price': newItem.price,
            'imageUrl': newItem.imageUrl,
            'category': newItem.category,
            'isAvailable': newItem.isAvailable ? 1 : 0,
            'isDeleted': 0,
            'lastUpdated': timestamp,
            'taxExempt': taxExemptValue,
            'isPerPlate': newItem.isPerPlate ? 1 : 0,
          },
        );
        
        debugPrint('Added menu item to local database: ${newItem.id}');
        return newItem;
      } catch (e) {
        retryCount++;
        debugPrint('Error adding menu item (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for adding menu item');
          rethrow;
        }
        
        // Reset database connection
        try {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
        } catch (closeError) {
          debugPrint('Error closing database after error: $closeError');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    // This should never be reached due to the rethrow above
    throw Exception('Failed to add menu item after $maxRetries attempts');
  }
  
  // Update an existing menu item locally with improved error handling
  Future<void> updateMenuItem(MenuItem item) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final db = await database;
        final timestamp = DateTime.now().toIso8601String();
        
        // Update the item
        await db.update(
          'menu_items',
          {
            'name': item.name,
            'price': item.price,
            'imageUrl': item.imageUrl,
            'category': item.category,
            'isAvailable': item.isAvailable ? 1 : 0,
            'lastUpdated': timestamp,
            'taxExempt': item.taxExempt ? 1 : 0,
            'isPerPlate': item.isPerPlate ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [item.id],
        );
        
        debugPrint('Updated menu item in local database: ${item.id}');
        return;
      } catch (e) {
        retryCount++;
        debugPrint('Error updating menu item (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for updating menu item');
          rethrow;
        }
        
        // Reset database connection
        try {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
        } catch (closeError) {
          debugPrint('Error closing database after error: $closeError');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
  }
  
  // Delete a menu item locally (soft delete) with improved error handling
  Future<void> deleteMenuItem(String id) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final db = await database;
        final timestamp = DateTime.now().toIso8601String();
        
        // Mark as deleted
        await db.update(
          'menu_items',
          {
            'isDeleted': 1,
            'lastUpdated': timestamp,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        
        debugPrint('Deleted menu item from local database: $id');
        return;
      } catch (e) {
        retryCount++;
        debugPrint('Error deleting menu item (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for deleting menu item');
          rethrow;
        }
        
        // Reset database connection
        try {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
        } catch (closeError) {
          debugPrint('Error closing database after error: $closeError');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
  }
  
  // Get all categories from local database with improved error handling
  Future<List<String>> getCategories() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final db = await database;
        final result = await db.rawQuery('''
          SELECT DISTINCT category FROM menu_items 
          WHERE isDeleted = 0
        ''');
        
        return result.map((map) => map['category'] as String).toList();
      } catch (e) {
        retryCount++;
        debugPrint('Error getting categories (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for getting categories');
          return []; // Return empty list instead of throwing
        }
        
        // Reset database connection
        try {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
        } catch (closeError) {
          debugPrint('Error closing database after error: $closeError');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    return []; // This is a fallback that should rarely be reached
  }
  
  // Add a new category (in SQLite this is just updating the schema)
  Future<void> addCategory(String categoryName) async {
    // Categories are just properties of menu items
    // No need to specifically create them in the database
    // This method is kept for API consistency
    debugPrint('Category "$categoryName" ready to use (no database operation needed)');
  }
  

  
  // Force reset the database connection
  static Future<void> resetConnection() async {
    try {
      _isResetting = true; // 🛡️ Block access during reset
      if (_database != null) {
        if (_database!.isOpen) {
          await _database!.close();
        }
        _database = null;
        debugPrint('Menu database connection reset');
      }
    } catch (e) {
      debugPrint('Error resetting menu database connection: $e');
    } finally {
      // Allow re-initialization if accessed again later
      _isResetting = false; 
    }
  }

  // Close the database connection explicitly
  Future<void> close() async {
    await resetConnection();
  }
  // Update category name for all items with that category
  Future<void> updateCategory(String oldCategory, String newCategory) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final db = await database;
        final timestamp = DateTime.now().toIso8601String();
        
        // Update all items with the old category to the new category
        await db.update(
          'menu_items',
          {
            'category': newCategory,
            'lastUpdated': timestamp,
          },
          where: 'category = ? AND isDeleted = ?',
          whereArgs: [oldCategory, 0],
        );
        
        debugPrint('Updated category from "$oldCategory" to "$newCategory"');
        return;
      } catch (e) {
        retryCount++;
        debugPrint('Error updating category (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for updating category');
          rethrow;
        }
        
        // Reset database connection
        try {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
        } catch (closeError) {
          debugPrint('Error closing database after error: $closeError');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
  }

  // Delete category (remove all items in that category)
  Future<void> deleteCategory(String category) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final db = await database;
        final timestamp = DateTime.now().toIso8601String();
        
        // Soft delete all items in this category
        await db.update(
          'menu_items',
          {
            'isDeleted': 1,
            'lastUpdated': timestamp,
          },
          where: 'category = ? AND isDeleted = ?',
          whereArgs: [category, 0],
        );
        
        debugPrint('Deleted all items in category: $category');
        return;
      } catch (e) {
        retryCount++;
        debugPrint('Error deleting category (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for deleting category');
          rethrow;
        }
        
        // Reset database connection
        try {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
        } catch (closeError) {
          debugPrint('Error closing database after error: $closeError');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
  }

  // Delete all items and categories (reset menu)
  Future<void> deleteAllMenuItems() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final db = await database;
        final timestamp = DateTime.now().toIso8601String();
        
        // Soft delete all items
        await db.update(
          'menu_items',
          {
            'isDeleted': 1,
            'lastUpdated': timestamp,
          },
          where: 'isDeleted = ?',
          whereArgs: [0],
        );
        
        debugPrint('Deleted ALL menu items from local database');
        return;
      } catch (e) {
        retryCount++;
        debugPrint('Error deleting all menu items (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
           debugPrint('Maximum retries reached for deleting all menu items');
           rethrow;
        }
        
        // Reset database connection
        try {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
        } catch (closeError) {
          debugPrint('Error closing database after error: $closeError');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
  }
}