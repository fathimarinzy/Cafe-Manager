// lib/repositories/local_menu_repository.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/menu_item.dart';
import 'package:flutter/foundation.dart';

class LocalMenuRepository {
  static Database? _database;
  static final LocalMenuRepository _instance = LocalMenuRepository._internal();
  
  // Factory constructor
  factory LocalMenuRepository() {
    return _instance;
  }
  
  // Private constructor
  LocalMenuRepository._internal();
  
  // Get database instance with retry logic
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database with retry logic
  Future<Database> _initDatabase() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, 'cafe_menu.db');
        
        debugPrint('Initializing menu database at: $path (Attempt ${retryCount + 1})');
        
        // Open the database with explicit version and onCreate handler
        return await openDatabase(
          path,
          version: 1,
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
                lastUpdated TEXT NOT NULL
              )
            ''');
            debugPrint('menu_items table created successfully');
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
        
        return List.generate(maps.length, (i) {
          return MenuItem(
            id: maps[i]['id'] as String,
            name: maps[i]['name'] as String,
            price: maps[i]['price'] as double,
            imageUrl: maps[i]['imageUrl'] as String,
            category: maps[i]['category'] as String,
            isAvailable: maps[i]['isAvailable'] == 1,
          );
        });
      } catch (e) {
        retryCount++;
        debugPrint('Error getting menu items (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for getting menu items');
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
        );
        
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
  
  // Close the database connection explicitly
  Future<void> close() async {
    try {
      if (_database != null && _database!.isOpen) {
        await _database!.close();
        _database = null;
        debugPrint('Menu database closed successfully');
      }
    } catch (e) {
      debugPrint('Error closing menu database: $e');
    }
  }
}