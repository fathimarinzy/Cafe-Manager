import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class LocalExpenseRepository {
  static Database? _database;

  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
    Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'cafe_expenses.db');
      
      debugPrint('Initializing database at: $path');
      
      return await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          debugPrint('Creating database tables...');
          // Create expenses table
          await db.execute('''
            CREATE TABLE expenses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              cashier TEXT NOT NULL,
              accountType TEXT NOT NULL,
              grandTotal REAL NOT NULL,
              createdAt TEXT NOT NULL
            )
          ''');

          // Create expense items table
          await db.execute('''
            CREATE TABLE expense_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              expense_id INTEGER NOT NULL,
              slNo INTEGER NOT NULL,
              account TEXT NOT NULL,
              narration TEXT NOT NULL,
              amount REAL NOT NULL,
              remarks TEXT,
              FOREIGN KEY (expense_id) REFERENCES expenses (id) ON DELETE CASCADE
            )
          ''');
          debugPrint('Database tables created successfully');
        },
      );
    } catch (e) {
      debugPrint('Error initializing database: $e');
      rethrow;
    }
  }


  // Save expense and its items
  Future<bool> saveExpense(Map<String, dynamic> expenseData) async {
    final db = await database;
    
    try {
      return await db.transaction((txn) async {
        // Insert expense
        final expenseId = await txn.insert(
          'expenses',
          {
            'date': expenseData['date'],
            'cashier': expenseData['cashier'],
            'accountType': expenseData['accountType'],
            'grandTotal': expenseData['grandTotal'],
            'createdAt': DateTime.now().toIso8601String(),
          },
        );
        
        // Insert expense items
        for (var item in expenseData['items']) {
          await txn.insert(
            'expense_items',
            {
              'expense_id': expenseId,
              'slNo': item['slNo'],
              'account': item['account'],
              'narration': item['narration'],
              'amount': item['amount'],
              'remarks': item['remarks'] ?? '',
            },
          );
        }
        
        return true;
      });
    } catch (e) {
      debugPrint('Error saving expense: $e');
      return false;
    }
  }

  // Get all expenses
  Future<List<Map<String, dynamic>>> getAllExpenses() async {
  final db = await database;
  try {
    debugPrint('Fetching all expenses...');
    final expenses = await db.query('expenses', orderBy: 'date DESC');
    debugPrint('Found ${expenses.length} expenses');
    
    final List<Map<String, dynamic>> result = [];
    
    for (var expense in expenses) {
      try {
        final expenseId = expense['id'] as int;
        debugPrint('Fetching items for expense $expenseId');
        final items = await db.query(
          'expense_items',
          where: 'expense_id = ?',
          whereArgs: [expenseId],
        );
        debugPrint('Found ${items.length} items for expense $expenseId');
        
        result.add({
          ...expense,
          'items': items,
        });
      } catch (e) {
        debugPrint('Error fetching items for expense ${expense['id']}: $e');
      }
    }
    
    return result;
  } catch (e) {
    debugPrint('Error fetching expenses: $e');
    rethrow;
  }
}
 
  // Get expense by ID
  Future<Map<String, dynamic>?> getExpenseById(int id) async {
    final db = await database;
    final expenses = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (expenses.isEmpty) return null;
    
    final expense = expenses.first;
    final items = await db.query(
      'expense_items',
      where: 'expense_id = ?',
      whereArgs: [id],
    );
    
    expense['items'] = items;
    return expense;
  }

  // Delete expense (will cascade to delete items as well)
  Future<bool> deleteExpense(int id) async {
    try {
      final db = await database;
      await db.delete(
        'expenses',
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      return false;
    }
  }
  // Update expense and its items
Future<bool> updateExpense(Map<String, dynamic> expenseData) async {
  final db = await database;
  final expenseId = expenseData['id'] as int;
  
  try {
    return await db.transaction((txn) async {
      // Update expense
      await txn.update(
        'expenses',
        {
          'date': expenseData['date'],
          'cashier': expenseData['cashier'],
          'accountType': expenseData['accountType'],
          'grandTotal': expenseData['grandTotal'],
        },
        where: 'id = ?',
        whereArgs: [expenseId],
      );
      
      // Delete existing items for this expense
      await txn.delete(
        'expense_items',
        where: 'expense_id = ?',
        whereArgs: [expenseId],
      );
      
      // Insert updated expense items
      for (var item in expenseData['items']) {
        await txn.insert(
          'expense_items',
          {
            'expense_id': expenseId,
            'slNo': item['slNo'],
            'account': item['account'],
            'narration': item['narration'],
            'amount': item['amount'],
            'remarks': item['remarks'] ?? '',
          },
        );
      }
      
      return true;
    });
  } catch (e) {
    debugPrint('Error updating expense: $e');
    return false;
  }
}
}