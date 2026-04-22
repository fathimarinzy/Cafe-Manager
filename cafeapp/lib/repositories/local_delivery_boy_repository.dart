import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/delivery_boy.dart';
import '../services/device_sync_service.dart';
import '../utils/database_helper.dart';

class LocalDeliveryBoyRepository {
  static Database? _database;

  static Future<Database>? _dbOpenFuture;

  static bool _isResetting = false; // 🛡️ Guard flag

  Future<Database> get database async {
    if (_isResetting) {
      throw StateError('Database is currently resetting - access denied');
    }

    if (_database != null) return _database!;
    
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

  Future<Database> _initDatabase() async {
    // Changing DB name to force fresh creation and avoid any migration issues
    final path = await DatabaseHelper.getDatabasePath('cafe_delivery_boys_store.db'); 
    
    debugPrint('Initializing delivery boy database at: $path');

    return await openDatabase(
      path,
      version: 2, // Increment for LAN sync columns
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL;');
      },
      onCreate: (db, version) async {
        debugPrint('Creating delivery_boys table in new DB');
        await db.execute('''
          CREATE TABLE delivery_boys (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phoneNumber TEXT NOT NULL,
            updated_at TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // LAN Sync: Add updated_at and is_deleted columns
          try {
            await db.execute('ALTER TABLE delivery_boys ADD COLUMN updated_at TEXT');
            await db.execute('ALTER TABLE delivery_boys ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
            // Backfill updated_at for existing rows
            await db.execute("UPDATE delivery_boys SET updated_at = '${DateTime.now().toIso8601String()}' WHERE updated_at IS NULL");
            debugPrint('Added LAN sync columns (updated_at, is_deleted) to delivery_boys table');
          } catch (e) {
            debugPrint('Error adding LAN sync columns to delivery_boys: $e');
          }
        }
      },
    );
  }


  Future<DeliveryBoy> saveDeliveryBoy(DeliveryBoy boy, {bool fromSync = false}) async {
    final db = await database;
    final String boyId = boy.id ?? 'local_${DateTime.now().millisecondsSinceEpoch}';

    final newBoy = DeliveryBoy(
      id: boyId,
      name: boy.name,
      phoneNumber: boy.phoneNumber,
    );

    try {
      final existing = await db.query(
        'delivery_boys',
        where: 'id = ?',
        whereArgs: [boyId],
      );

      if (existing.isNotEmpty) {
        final map = newBoy.toMap();
        map['updated_at'] = DateTime.now().toIso8601String();
        await db.update(
          'delivery_boys',
          map,
          where: 'id = ?',
          whereArgs: [boyId],
        );
        debugPrint('Updated delivery boy: ${newBoy.name}');
      } else {
        final map = newBoy.toMap();
        map['updated_at'] = DateTime.now().toIso8601String();
        await db.insert(
          'delivery_boys',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        debugPrint('Inserted delivery boy: ${newBoy.name}');
      }
      // Sync to Firestore ONLY if not from sync
      // Fire-and-forget: don't await so save isn't blocked by network issues
      if (!fromSync) {
        DeviceSyncService.syncDeliveryBoyToFirestore(newBoy);
      }
      return newBoy;
    } catch (e) {
      debugPrint('Error saving delivery boy: $e');
      rethrow;
    }
  }

  Future<List<DeliveryBoy>> getAllDeliveryBoys() async {
    try {
      final db = await database;
      // Ensure we catch issues if table doesn't exist
      try {
        final results = await db.query('delivery_boys', where: 'is_deleted = ?', whereArgs: [0]);
        debugPrint('Retrieved ${results.length} delivery boys');
        return results.map((map) => DeliveryBoy.fromMap(map)).toList();
      } catch (e) {
        debugPrint('Error querying delivery_boys table (might be missing): $e');
        // Attempt to create table if it's missing (failsafe)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS delivery_boys (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phoneNumber TEXT NOT NULL
          )
        ''');
        return [];
      }
    } catch (e) {
      debugPrint('Database error in getAllDeliveryBoys: $e');
      return [];
    }
  }

  Future<bool> deleteDeliveryBoy(String id, {bool fromSync = false}) async {
    try {
      final db = await database;
      // Soft delete to ensure sync picks it up
      final count = await db.update(
        'delivery_boys',
        {
          'is_deleted': 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('Deleted delivery boy $id, count: $count');
      if (count > 0 && !fromSync) {
        await DeviceSyncService.deleteDeliveryBoyFromFirestore(id);
      }
      return count > 0;
    } catch (e) {
      debugPrint('Error deleting delivery boy: $e');
      return false;
    }
  }


  // Clear all data from the database
  Future<void> clearData() async {
    try {
      final db = await database;
      await db.delete('delivery_boys');
      debugPrint('Delivery boy data cleared');
    } catch (e) {
      debugPrint('Error clearing delivery boy data: $e');
    }
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
        debugPrint('Delivery boy database connection reset');
      }
    } catch (e) {
      debugPrint('Error resetting delivery boy database connection: $e');
    } finally {
      _isResetting = false;
    }
  }

  // Close the database connection explicitly
  Future<void> close() async {
    await resetConnection();
  }
}
