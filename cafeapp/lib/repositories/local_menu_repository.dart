// lib/repositories/local_menu_repository.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/menu_item.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class LocalMenuRepository {
  static Database? _database;

  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cafe_menu.db');
    
    return await openDatabase(
      path,
      version: 2, // Increased version for schema updates
      onCreate: (db, version) async {
        // Create menu items table
        await db.execute('''
          CREATE TABLE menu_items (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            imageUrl TEXT,
            category TEXT NOT NULL,
            isAvailable INTEGER NOT NULL,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            isSynced INTEGER NOT NULL DEFAULT 0,
            lastUpdated TEXT NOT NULL
          )
        ''');
        
        // Create pending operations table with improved schema
        await db.execute('''
          CREATE TABLE pending_operations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            itemId TEXT NOT NULL,
            operation TEXT NOT NULL,
            itemData TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            retries INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add retries column if upgrading from version 1
          await db.execute('ALTER TABLE pending_operations ADD COLUMN retries INTEGER NOT NULL DEFAULT 0');
        }
      },
    );
  }

  // Save menu items to local database
  Future<void> saveMenuItems(List<MenuItem> items) async {
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
          'isSynced': 1,
          'lastUpdated': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
    debugPrint('Saved ${items.length} items to local database');
  }

  // Get all menu items from local database
  Future<List<MenuItem>> getMenuItems() async {
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
  }

  // Add a new pending operation with better formatting
  Future<int> queueOperation(String operation, String itemId, MenuItem item) async {
    final db = await database;
    
    try {
      // Convert MenuItem to a clean JSON string
      final Map<String, dynamic> itemData = {
        'id': item.id,
        'name': item.name,
        'price': item.price,
        'image': item.imageUrl, // Use 'image' to match server expectations
        'category': item.category,
        'available': item.isAvailable, // Use 'available' to match server expectations
      };
      
      final String dataString = json.encode(itemData);
      
      return await db.insert(
        'pending_operations',
        {
          'itemId': itemId,
          'operation': operation,
          'itemData': dataString,
          'timestamp': DateTime.now().toIso8601String(),
          'retries': 0,
        },
      );
    } catch (e) {
      debugPrint('Error queueing operation: $e');
      return -1;
    }
  }

  // Increment retry count for a pending operation
  Future<void> incrementRetryCount(int operationId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE pending_operations SET retries = retries + 1 WHERE id = ?',
      [operationId]
    );
  }
  
  // Add a new menu item locally
  Future<MenuItem> addMenuItem(MenuItem item) async {
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
        'isSynced': 0,
        'lastUpdated': timestamp,
      },
    );
    
    // Add to pending operations
    await queueOperation('ADD', newItem.id, newItem);
    
    return newItem;
  }
  
  // Update an existing menu item locally
  Future<void> updateMenuItem(MenuItem item) async {
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
        'isSynced': 0,
        'lastUpdated': timestamp,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
    
    // Add to pending operations
    await queueOperation('UPDATE', item.id, item);
  }
  
  // Delete a menu item locally (soft delete)
  Future<void> deleteMenuItem(String id) async {
    final db = await database;
    final timestamp = DateTime.now().toIso8601String();
    
    // Get the item before marking as deleted
    final item = await db.query(
      'menu_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (item.isEmpty) return;
    
    // Mark as deleted
    await db.update(
      'menu_items',
      {
        'isDeleted': 1,
        'isSynced': 0,
        'lastUpdated': timestamp,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    
    // Create a MenuItem object for the pending operation
    final menuItem = MenuItem(
      id: id,
      name: item.first['name'] as String,
      price: item.first['price'] as double,
      imageUrl: item.first['imageUrl'] as String,
      category: item.first['category'] as String,
      isAvailable: item.first['isAvailable'] == 1,
    );
    
    // Add to pending operations
    await queueOperation('DELETE', id, menuItem);
  }
  
  // Get all pending operations
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await database;
    return db.query('pending_operations', orderBy: 'timestamp ASC');
  }
  
  // Mark item as synced
  Future<void> markItemAsSynced(String id) async {
    final db = await database;
    await db.update(
      'menu_items',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // Remove a pending operation
  Future<void> removePendingOperation(int operationId) async {
    final db = await database;
    await db.delete(
      'pending_operations',
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }
  
  // Get all categories from local database
  Future<List<String>> getCategories() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT category FROM menu_items 
      WHERE isDeleted = 0
    ''');
    
    return result.map((map) => map['category'] as String).toList();
  }
  
  // Add a new category (in SQLite this is just updating the schema)
  Future<void> addCategory(String categoryName) async {
    // In our implementation, categories are just properties of menu items
    // No need to specifically create them in the database
  }
  
  // Get unsynchronized items
  Future<List<MenuItem>> getUnsyncedItems() async {
    final db = await database;
    final maps = await db.query(
      'menu_items',
      where: 'isSynced = ?',
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
  }
}