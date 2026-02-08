// lib/repositories/local_expense_repository.dart
import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../utils/database_helper.dart';

class LocalExpenseRepository {
  static Database? _database;
  static final LocalExpenseRepository _instance = LocalExpenseRepository._internal();
  
  // Factory constructor for singleton pattern
  factory LocalExpenseRepository() {
    return _instance;
  }
  
  // Private constructor
  LocalExpenseRepository._internal();
  
  static bool _isResetting = false; // 🛡️ Guard flag
  
  // Get database instance with proper checks
  Future<Database> get database async {
    if (_isResetting) {
      throw StateError('Database is currently resetting - access denied');
    }

    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database with retry logic
  Future<Database> _initDatabase() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final path = await DatabaseHelper.getDatabasePath('cafe_expenses.db');
        
        debugPrint('Initializing expense database at: $path (Attempt ${retryCount + 1})');
        
        return await openDatabase(
          path,
          version: 1,
          onConfigure: (db) async {
            await db.rawQuery('PRAGMA journal_mode=WAL;');
          },
          onCreate: (db, version) async {
            debugPrint('Creating expense database tables...');
            
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
            
            debugPrint('Expense database tables created successfully');
          },
          onOpen: (db) {
            debugPrint('Expense database opened successfully');
          },
        );
      } catch (e) {
        retryCount++;
        debugPrint('Error initializing expense database (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for expense database initialization');
          rethrow;
        }
        
        // Close any existing database connection
        try {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
        } catch (closeError) {
          debugPrint('Error closing existing database: $closeError');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    throw Exception('Failed to initialize expense database after $maxRetries attempts');
  }

  // Save expense and its items with retry logic
  Future<bool> saveExpense(Map<String, dynamic> expenseData) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final db = await database;
        
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
          
          debugPrint('Saved expense #$expenseId successfully');
          return true;
        });
      } catch (e) {
        retryCount++;
        debugPrint('Error saving expense (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for saving expense');
          return false;
        }
        
        // Reset database connection
        try {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
        } catch (closeError) {
          debugPrint('Error closing database after error: $closeError');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    return false;
  }

  // Get all expenses with retry logic
  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final db = await database;
        
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
        retryCount++;
        debugPrint('Error fetching expenses (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for fetching expenses');
          return [];
        }
        
        // Reset database connection
        try {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
        } catch (closeError) {
          debugPrint('Error closing database after error: $closeError');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    return [];
  }
  
  // Get expense by ID with retry logic
  Future<Map<String, dynamic>?> getExpenseById(int id) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
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
      } catch (e) {
        retryCount++;
        debugPrint('Error getting expense by ID (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for getting expense by ID');
          return null;
        }
        
        // Reset database connection
        try {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
        } catch (closeError) {
          debugPrint('Error closing database after error: $closeError');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    return null;
  }

  // Delete expense with retry logic
  Future<bool> deleteExpense(int id) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final db = await database;
        
        await db.delete(
          'expenses',
          where: 'id = ?',
          whereArgs: [id],
        );
        
        debugPrint('Deleted expense #$id successfully');
        return true;
      } catch (e) {
        retryCount++;
        debugPrint('Error deleting expense (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for deleting expense');
          return false;
        }
        
        // Reset database connection
        try {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
        } catch (closeError) {
          debugPrint('Error closing database after error: $closeError');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    return false;
  }
  
  // Update expense with retry logic
  Future<bool> updateExpense(Map<String, dynamic> expenseData) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final db = await database;
        final expenseId = expenseData['id'] as int;
        
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
          
          debugPrint('Updated expense #$expenseId successfully');
          return true;
        });
      } catch (e) {
        retryCount++;
        debugPrint('Error updating expense (Attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          debugPrint('Maximum retries reached for updating expense');
          return false;
        }
        
        // Reset database connection
        try {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
        } catch (closeError) {
          debugPrint('Error closing database after error: $closeError');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    return false;
  }
  
  // Clear all data from the database
  Future<void> clearData() async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('expense_items');
        await txn.delete('expenses');
      });
      debugPrint('Expense data cleared');
    } catch (e) {
      debugPrint('Error clearing expense data: $e');
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
        debugPrint('Expense database connection reset');
      }
    } catch (e) {
      debugPrint('Error resetting expense database connection: $e');
    } finally {
      _isResetting = false;
    }
  }

  // Close the database connection explicitly
  Future<void> close() async {
     await resetConnection();
  }
}