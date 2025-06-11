import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/person.dart';
// import 'package:flutter/foundation.dart';

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
      version: 1,
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
    );
  }

  // Save person to local database
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
    
    // Insert person record
    await db.insert(
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
    
    // Add to pending operations
    await db.insert(
      'pending_person_operations',
      {
        'personId': personId,
        'operation': 'ADD',
        'personData': _personToJson(newPerson),
        'timestamp': timestamp,
        'retries': 0,
      },
    );
    
    return newPerson;
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
    final db = await database;
    final results = await db.query('persons');
    
    return results.map((map) => Person(
      id: map['id'] as String,
      name: map['name'] as String,
      phoneNumber: map['phoneNumber'] as String,
      place: map['place'] as String,
      dateVisited: map['dateVisited'] as String,
    )).toList();
  }
  
  // Get unsynchronized persons
  Future<List<Person>> getUnsyncedPersons() async {
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
  }
  
  // Mark person as synchronized
  Future<void> markPersonAsSynced(String localId, String? serverId) async {
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
  }
  
  // Get pending operations count
  Future<int> getPendingOperationsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM pending_person_operations');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}