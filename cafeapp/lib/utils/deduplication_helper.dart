// lib/utils/deduplication_helper.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

/// A helper class to track and prevent duplicate API operations
class DeduplicationHelper {
  static DeduplicationHelper? _instance;
  static Database? _database;
  
  // Private constructor for singleton
  DeduplicationHelper._();
  
  // Factory constructor that returns the singleton instance
  factory DeduplicationHelper() {
    _instance ??= DeduplicationHelper._();
    return _instance!;
  }
  
  // Initialize the deduplication database
  Future<void> initialize() async {
    if (_database != null) return;
    
    try {
      // Get path to the database
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'deduplication.db');
      
      // Open the database
      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          // Create table to store processed operations
          await db.execute('''
            CREATE TABLE processed_operations (
              operation_hash TEXT PRIMARY KEY,
              operation_type TEXT NOT NULL,
              item_id TEXT NOT NULL,
              processed_at TEXT NOT NULL
            )
          ''');
        },
      );
      
      debugPrint('Deduplication database initialized');
    } catch (e) {
      debugPrint('Error initializing deduplication database: $e');
    }
  }
  
  // Generate a hash for an operation
  String _generateOperationHash(String operationType, String itemId, Map<String, dynamic> data) {
    final dataString = json.encode(data);
    final input = '$operationType:$itemId:$dataString';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Check if an operation has already been processed
  Future<bool> isOperationProcessed(String operationType, String itemId, Map<String, dynamic> data) async {
    await initialize();
    
    if (_database == null) {
      debugPrint('Database not initialized, cannot check for duplicates');
      return false;
    }
    
    try {
      final hash = _generateOperationHash(operationType, itemId, data);
      
      final result = await _database!.query(
        'processed_operations',
        where: 'operation_hash = ?',
        whereArgs: [hash],
      );
      
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if operation is processed: $e');
      return false;
    }
  }
  
  // Mark an operation as processed
  Future<void> markOperationProcessed(String operationType, String itemId, Map<String, dynamic> data) async {
    await initialize();
    
    if (_database == null) {
      debugPrint('Database not initialized, cannot mark operation as processed');
      return;
    }
    
    try {
      final hash = _generateOperationHash(operationType, itemId, data);
      
      await _database!.insert(
        'processed_operations',
        {
          'operation_hash': hash,
          'operation_type': operationType,
          'item_id': itemId,
          'processed_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error marking operation as processed: $e');
    }
  }
  
  // Clean up old processed operations (older than 30 days)
  Future<void> cleanupOldOperations() async {
    await initialize();
    
    if (_database == null) {
      debugPrint('Database not initialized, cannot clean up old operations');
      return;
    }
    
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      
      final deletedCount = await _database!.delete(
        'processed_operations',
        where: 'processed_at < ?',
        whereArgs: [cutoffDate],
      );
      
      debugPrint('Cleaned up $deletedCount old processed operations');
    } catch (e) {
      debugPrint('Error cleaning up old operations: $e');
    }
  }
  
  // Reset all processed operations - use with caution!
  Future<void> resetAllProcessedOperations() async {
    await initialize();
    
    if (_database == null) {
      debugPrint('Database not initialized, cannot reset processed operations');
      return;
    }
    
    try {
      await _database!.delete('processed_operations');
      debugPrint('Reset all processed operations');
    } catch (e) {
      debugPrint('Error resetting processed operations: $e');
    }
  }
}