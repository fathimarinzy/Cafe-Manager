// lib/repositories/local_person_repository.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/person.dart';
import 'package:flutter/foundation.dart';

class LocalPersonRepository {
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
    final path = join(dbPath, 'cafe_persons.db');
    
    return await openDatabase(
      path,
      version: 2, // Increment version to handle any schema changes
      onCreate: (db, version) async {
        // Create persons table
        await db.execute('''
          CREATE TABLE persons (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phoneNumber TEXT NOT NULL,
            place TEXT NOT NULL,
            dateVisited TEXT NOT NULL,
            isSync INTEGER NOT NULL DEFAULT 0,
            lastUpdated TEXT NOT NULL
          )
        ''');
        
        // Create pending operations table
        await db.execute('''
          CREATE TABLE pending_person_operations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            personId TEXT NOT NULL,
            operation TEXT NOT NULL,
            personData TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            retries INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Handle schema upgrades if needed
        if (oldVersion < 2) {
          // Add any new columns or tables for version 2
          try {
            // Check if retries column exists, add if it doesn't
            await db.execute('ALTER TABLE pending_person_operations ADD COLUMN retries INTEGER NOT NULL DEFAULT 0');
          } catch (e) {
            // Column may already exist
          }
        }
      },
    );
  }

  // Save person to local database with improved error handling and conflict resolution
  Future<Person> savePerson(Person person) async {
    final db = await database;
    final timestamp = DateTime.now().toIso8601String();
    
    // Generate a temporary local ID if not provided
    final String personId = person.id ?? 'local_${DateTime.now().millisecondsSinceEpoch}';
    
    final newPerson = Person(
      id: personId,
      name: person.name,
      phoneNumber: person.phoneNumber,
      place: person.place,
      dateVisited: person.dateVisited,
    );
    
    try {
      // Start a transaction to ensure data consistency
      await db.transaction((txn) async {
        // Check if the person already exists
        final existing = await txn.query(
          'persons',
          where: 'id = ?',
          whereArgs: [personId],
        );
        
        if (existing.isNotEmpty) {
          // Update existing person
          await txn.update(
            'persons',
            {
              'name': newPerson.name,
              'phoneNumber': newPerson.phoneNumber,
              'place': newPerson.place,
              'dateVisited': newPerson.dateVisited,
              'isSync': 0,  // Mark as not synced since we're updating
              'lastUpdated': timestamp,
            },
            where: 'id = ?',
            whereArgs: [personId],
          );
        } else {
          // Insert new person
          await txn.insert(
            'persons',
            {
              'id': personId,
              'name': newPerson.name,
              'phoneNumber': newPerson.phoneNumber,
              'place': newPerson.place,
              'dateVisited': newPerson.dateVisited,
              'isSync': 0,
              'lastUpdated': timestamp,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        
        // Add to pending operations if it's a local ID (needs to be synced)
        if (personId.startsWith('local_')) {
          await txn.insert(
            'pending_person_operations',
            {
              'personId': personId,
              'operation': 'ADD',
              'personData': _personToJson(newPerson),
              'timestamp': timestamp,
              'retries': 0,
            },
          );
        }
      });
      
      return newPerson;
    } catch (e) {
      // Log the error but don't rethrow to prevent app crashes
      debugPrint('Error saving person to local database: $e');
      
      // Still return the person object even if save failed
      // This ensures the app continues to function
      return newPerson;
    }
  }
  
  // Convert person to JSON string
  String _personToJson(Person person) {
    return '''
      {
        "id": "${person.id}",
        "name": "${person.name}",
        "phoneNumber": "${person.phoneNumber}",
        "place": "${person.place}",
        "dateVisited": "${person.dateVisited}"
      }
    ''';
  }
  
  // Get all persons from local database
  Future<List<Person>> getAllPersons() async {
    try {
      final db = await database;
      final results = await db.query('persons');
      
      return results.map((map) => Person(
        id: map['id'] as String,
        name: map['name'] as String,
        phoneNumber: map['phoneNumber'] as String,
        place: map['place'] as String,
        dateVisited: map['dateVisited'] as String,
      )).toList();
    } catch (e) {
      debugPrint('Error getting all persons: $e');
      return []; // Return empty list on error
    }
  }
  
  // Get unsynchronized persons
  Future<List<Person>> getUnsyncedPersons() async {
    try {
      final db = await database;
      final results = await db.query(
        'persons',
        where: 'isSync = ?',
        whereArgs: [0],
      );
      
      return results.map((map) => Person(
        id: map['id'] as String,
        name: map['name'] as String,
        phoneNumber: map['phoneNumber'] as String,
        place: map['place'] as String,
        dateVisited: map['dateVisited'] as String,
      )).toList();
    } catch (e) {
      debugPrint('Error getting unsynced persons: $e');
      return []; // Return empty list on error
    }
  }
  
  // Mark person as synchronized
  Future<void> markPersonAsSynced(String localId, String? serverId) async {
    try {
      final db = await database;
      await db.update(
        'persons',
        {
          'isSync': 1,
          'id': serverId ?? localId,
        },
        where: 'id = ?',
        whereArgs: [localId],
      );
      
      // Remove from pending operations
      await db.delete(
        'pending_person_operations',
        where: 'personId = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      debugPrint('Error marking person as synced: $e');
    }
  }
  
  // Get pending operations count
  Future<int> getPendingOperationsCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) FROM pending_person_operations');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('Error getting pending operations count: $e');
      return 0;
    }
  }
  
  // Delete a person by ID
  Future<bool> deletePerson(String id) async {
    try {
      final db = await database;
      final count = await db.delete(
        'persons',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      // Add to pending operations if not already synced
      final timestamp = DateTime.now().toIso8601String();
      await db.insert(
        'pending_person_operations',
        {
          'personId': id,
          'operation': 'DELETE',
          'personData': '{"id": "$id"}',
          'timestamp': timestamp,
          'retries': 0,
        },
      );
      
      return count > 0;
    } catch (e) {
      debugPrint('Error deleting person: $e');
      return false;
    }
  }
  
  // Update person details
  Future<bool> updatePerson(Person person) async {
    if (person.id == null) return false;
    
    try {
      final db = await database;
      final timestamp = DateTime.now().toIso8601String();
      
      final count = await db.update(
        'persons',
        {
          'name': person.name,
          'phoneNumber': person.phoneNumber,
          'place': person.place,
          'dateVisited': person.dateVisited,
          'isSync': 0, // Mark as not synced
          'lastUpdated': timestamp,
        },
        where: 'id = ?',
        whereArgs: [person.id],
      );
      
      // Add to pending operations
      await db.insert(
        'pending_person_operations',
        {
          'personId': person.id!,
          'operation': 'UPDATE',
          'personData': _personToJson(person),
          'timestamp': timestamp,
          'retries': 0,
        },
      );
      
      return count > 0;
    } catch (e) {
      debugPrint('Error updating person: $e');
      return false;
    }
  }
}