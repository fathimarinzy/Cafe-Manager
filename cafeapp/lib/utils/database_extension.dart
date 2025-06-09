import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Extension methods for SQLite Database class
extension DatabaseExtension on Database {
  /// Execute a batch of queries inside a transaction
  /// This is useful for performing multiple operations atomically
  Future<void> executeTransaction(Future<void> Function(Transaction txn) action) async {
    try {
      await transaction((txn) async {
        await action(txn);
      });
    } catch (e) {
      debugPrint('Error executing transaction: $e');
      rethrow;
    }
  }
  
  /// Execute a query with error handling
  Future<List<Map<String, dynamic>>> querySafely(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      return await query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      debugPrint('Error executing query on table $table: $e');
      return [];
    }
  }
  
  /// Insert a record with error handling
  Future<int> insertSafely(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    try {
      return await insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      );
    } catch (e) {
      debugPrint('Error inserting into table $table: $e');
      rethrow;
    }
  }
  
  /// Update records with error handling
  Future<int> updateSafely(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    try {
      return await update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      );
    } catch (e) {
      debugPrint('Error updating table $table: $e');
      return 0;
    }
  }
  
  /// Delete records with error handling
  Future<int> deleteSafely(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      return await delete(
        table,
        where: where,
        whereArgs: whereArgs,
      );
    } catch (e) {
      debugPrint('Error deleting from table $table: $e');
      return 0;
    }
  }
  
  /// Execute a raw query with error handling
  Future<List<Map<String, dynamic>>> rawQuerySafely(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    try {
      return await rawQuery(sql, arguments);
    } catch (e) {
      debugPrint('Error executing raw query: $e');
      return [];
    }
  }
}