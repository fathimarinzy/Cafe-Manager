// lib/repositories/local_menu_repository.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/menu_item.dart';
// import 'dart:convert';
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
      version: 1,
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
            lastUpdated TEXT NOT NULL
          )
        ''');
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
        'lastUpdated': timestamp,
      },
    );
    
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
        'lastUpdated': timestamp,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }
  
  // Delete a menu item locally (soft delete)
  Future<void> deleteMenuItem(String id) async {
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
    // Categories are just properties of menu items
    // No need to specifically create them in the database
    // This method is kept for API consistency
  }
}