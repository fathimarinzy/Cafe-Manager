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
      version: 2,
      onCreate: (db, version) async {
        // Create persons table with simplified schema
        await db.execute('''
          CREATE TABLE persons (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phoneNumber TEXT NOT NULL,
            place TEXT NOT NULL,
            dateVisited TEXT NOT NULL,
            credit REAL DEFAULT 0.0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add credit column to existing table
          await db.execute('ALTER TABLE persons ADD COLUMN credit REAL DEFAULT 0.0');
        }
      },
    );
  }

  // Save person to local database with improved error handling
  Future<Person> savePerson(Person person) async {
    final db = await database;
    // final timestamp = DateTime.now().toIso8601String();
    
    // Generate a local ID if not provided
    final String personId = person.id ?? 'local_${DateTime.now().millisecondsSinceEpoch}';
    
    final newPerson = Person(
      id: personId,
      name: person.name,
      phoneNumber: person.phoneNumber,
      place: person.place,
      dateVisited: person.dateVisited,
      credit: person.credit,
    );
    
    try {
      // Check if the person already exists
      final existing = await db.query(
        'persons',
        where: 'id = ?',
        whereArgs: [personId],
      );
      
      if (existing.isNotEmpty) {
        // Update existing person
        await db.update(
          'persons',
          {
            'name': newPerson.name,
            'phoneNumber': newPerson.phoneNumber,
            'place': newPerson.place,
            'dateVisited': newPerson.dateVisited,
            'credit': newPerson.credit,
          },
          where: 'id = ?',
          whereArgs: [personId],
        );
      } else {
        // Insert new person
        await db.insert(
          'persons',
          {
            'id': personId,
            'name': newPerson.name,
            'phoneNumber': newPerson.phoneNumber,
            'place': newPerson.place,
            'dateVisited': newPerson.dateVisited,
            'credit': newPerson.credit,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      return newPerson;
    } catch (e) {
      // Log the error but don't rethrow to prevent app crashes
      debugPrint('Error saving person to local database: $e');
      
      // Still return the person object even if save failed
      // This ensures the app continues to function
      return newPerson;
    }
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
        credit: (map['credit'] ?? 0.0) as double,
      )).toList();
    } catch (e) {
      debugPrint('Error getting all persons: $e');
      return []; // Return empty list on error
    }
  }
  // Add method to add credit to existing balance
Future<bool> addCreditToCustomer(String personId, double creditToAdd) async {
  try {
    final db = await database;
    
    // Get current credit
    final result = await db.query(
      'persons',
      columns: ['credit'],
      where: 'id = ?',
      whereArgs: [personId],
    );
    
    if (result.isNotEmpty) {
      final currentCredit = (result.first['credit'] ?? 0.0) as double;
      final newCredit = currentCredit + creditToAdd;
      
      final count = await db.update(
        'persons',
        {'credit': newCredit},
        where: 'id = ?',
        whereArgs: [personId],
      );
      
      return count > 0;
    }
    
    return false;
  } catch (e) {
    debugPrint('Error adding credit to customer: $e');
    return false;
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
      
      final count = await db.update(
        'persons',
        {
          'name': person.name,
          'phoneNumber': person.phoneNumber,
          'place': person.place,
          'dateVisited': person.dateVisited,
        },
        where: 'id = ?',
        whereArgs: [person.id],
      );
      
      return count > 0;
    } catch (e) {
      debugPrint('Error updating person: $e');
      return false;
    }
  }

  // Add this method to your LocalPersonRepository class:

Future<Person?> getPersonById(String id) async {
  try {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'persons',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return Person(
        id: maps.first['id'] as String,
        name: maps.first['name'] as String,
        phoneNumber: maps.first['phoneNumber'] as String,
        place: maps.first['place'] as String,
        dateVisited: maps.first['dateVisited'] as String,
        credit: (maps.first['credit'] ?? 0.0) as double,
      );
    }
    
    return null;
  } catch (e) {
    debugPrint('Error getting person by ID: $e');
    return null;
  }
}
}