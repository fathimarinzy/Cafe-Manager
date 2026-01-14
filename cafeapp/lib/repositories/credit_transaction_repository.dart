import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
import '../models/credit_transaction.dart';
import '../services/device_sync_service.dart';
import 'package:flutter/foundation.dart';
import '../utils/database_helper.dart';

class CreditTransactionRepository {
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
    final path = await DatabaseHelper.getDatabasePath('credit_transactions.db');
    
    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL;');
      },
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

  Future<CreditTransaction> saveCreditTransaction(CreditTransaction transaction, {bool fromSync = false}) async {
    final db = await database;
    
    try {
      await db.insert(
        'credit_transactions',
        transaction.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      
      // SYNC: Sync credit transaction (ONLY if not from sync)
      if (!fromSync) {
        await DeviceSyncService.syncCreditTransactionToFirestore(transaction);
      }
      
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
      
      if (count > 0) {
        // SYNC: Fetch and sync updated transaction
        try {
           final updatedTx = await getCreditTransactionById(transactionId);
           if (updatedTx != null) {
             await DeviceSyncService.syncCreditTransactionToFirestore(updatedTx);
           }
        } catch (e) {
          debugPrint('Error syncing completed credit transaction: $e');
        }
      }
      
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