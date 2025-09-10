import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/credit_transaction.dart';
import 'package:flutter/foundation.dart';

class CreditTransactionRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'credit_transactions.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE credit_transactions (
            id TEXT PRIMARY KEY,
            customerId TEXT NOT NULL,
            customerName TEXT NOT NULL,
            orderNumber TEXT NOT NULL,
            amount REAL NOT NULL,
            createdAt TEXT NOT NULL,
            serviceType TEXT NOT NULL,
            isCompleted INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<CreditTransaction> saveCreditTransaction(CreditTransaction transaction) async {
    final db = await database;
    
    try {
      await db.insert(
        'credit_transactions',
        transaction.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      return transaction;
    } catch (e) {
      debugPrint('Error saving credit transaction: $e');
      return transaction;
    }
  }

  Future<List<CreditTransaction>> getCreditTransactionsByCustomer(String customerId) async {
    try {
      final db = await database;
      final results = await db.query(
        'credit_transactions',
        where: 'customerId = ? AND isCompleted = ?',
        whereArgs: [customerId, 0], // Only pending (not completed) credits
        orderBy: 'createdAt DESC',
      );
      
      return results.map((map) => CreditTransaction.fromJson(map)).toList();
    } catch (e) {
      debugPrint('Error getting credit transactions: $e');
      return [];
    }
  }

  Future<bool> markCreditTransactionCompleted(String transactionId) async {
    try {
      final db = await database;
      
      final count = await db.update(
        'credit_transactions',
        {'isCompleted': 1},
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      
      return count > 0;
    } catch (e) {
      debugPrint('Error marking credit transaction completed: $e');
      return false;
    }
  }

  Future<CreditTransaction?> getCreditTransactionById(String id) async {
    try {
      final db = await database;
      final results = await db.query(
        'credit_transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      if (results.isNotEmpty) {
        return CreditTransaction.fromJson(results.first);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting credit transaction by ID: $e');
      return null;
    }
  }
}