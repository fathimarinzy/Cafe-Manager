import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/delivery_boy.dart';
import '../services/device_sync_service.dart';
import '../utils/database_helper.dart';

class LocalDeliveryBoyRepository {
  static Database? _database;

  static Future<Database>? _dbOpenFuture;

  Future<Database> get database async {
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
      version: 1, // Reset version to 1 for new file
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL;');
      },
      onCreate: (db, version) async {
        debugPrint('Creating delivery_boys table in new DB');
        await db.execute('''
          CREATE TABLE delivery_boys (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phoneNumber TEXT NOT NULL
          )
        ''');
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
        await db.update(
          'delivery_boys',
          newBoy.toMap(),
          where: 'id = ?',
          whereArgs: [boyId],
        );
        debugPrint('Updated delivery boy: ${newBoy.name}');
      } else {
        await db.insert(
          'delivery_boys',
          newBoy.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        debugPrint('Inserted delivery boy: ${newBoy.name}');
      }
      // Sync to Firestore ONLY if not from sync
      if (!fromSync) {
        await DeviceSyncService.syncDeliveryBoyToFirestore(newBoy);
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
        final results = await db.query('delivery_boys');
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
      final count = await db.delete(
        'delivery_boys',
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


  // Close the database connection explicitly
  Future<void> close() async {
    try {
      if (_database != null && _database!.isOpen) {
        await _database!.close();
        _database = null;
        debugPrint('Delivery boy database closed successfully');
      }
    } catch (e) {
      debugPrint('Error closing delivery boy database: $e');
    }
  }
}
