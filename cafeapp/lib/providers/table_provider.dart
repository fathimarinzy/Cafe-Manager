import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/table_model.dart';

class TableProvider with ChangeNotifier {
  List<TableModel> _tables = [];
  final String _storageKey = 'dining_tables';

  List<TableModel> get tables => [..._tables];

  TableProvider() {
    _loadTables();
  }

  Future<void> _loadTables() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tablesJson = prefs.getString(_storageKey);
    
    if (tablesJson != null) {
      final List<dynamic> decodedData = jsonDecode(tablesJson);
      _tables = decodedData.map((item) => TableModel.fromJson(item)).toList();
    } else {
      // Initial default tables if none exist
      _tables = List.generate(16, (index) => 
        TableModel(
          id: DateTime.now().millisecondsSinceEpoch.toString() + index.toString(),
          number: index + 1,
          isOccupied: false,
          capacity: 4,
        )
      );
      _saveTables();
    }
    notifyListeners();
  }

  Future<void> _saveTables() async {
    final prefs = await SharedPreferences.getInstance();
    final String tablesJson = jsonEncode(_tables.map((table) => table.toJson()).toList());
    await prefs.setString(_storageKey, tablesJson);
     await prefs.reload();
  }

  Future<void> addTable() async {
    final newTableNumber = _tables.isEmpty ? 1 : _tables.map((t) => t.number).reduce((a, b) => a > b ? a : b) + 1;
    
    _tables.add(
      TableModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        number: newTableNumber,
        isOccupied: false,
        capacity: 4,
      )
    );
    
    await _saveTables();
    notifyListeners();
  }

  Future<void> addSpecificTable(TableModel table) async {
    // Check if a table with the same number already exists
    final tableWithSameNumber = _tables.any((t) => t.number == table.number);
    if (tableWithSameNumber) {
      // In a real app, you might want to handle this differently
      // For now, we'll just add the table with a different number
      final newTableNumber = _tables.isEmpty ? 1 : _tables.map((t) => t.number).reduce((a, b) => a > b ? a : b) + 1;
      table = TableModel(
        id: table.id,
        number: newTableNumber,
        capacity: table.capacity,
        isOccupied: table.isOccupied,
        note: table.note,
      );
    }
    
    _tables.add(table);
    await _saveTables();
    notifyListeners();
  }

  Future<void> updateTable(TableModel table) async {
    final index = _tables.indexWhere((t) => t.id == table.id);
    if (index >= 0) {
      _tables[index] = table;
      await _saveTables();
      notifyListeners();
    }
  }

  // Method to update table by number instead of id
  Future<void> updateTableByNumber(int tableNumber, {bool? isOccupied}) async {
    final index = _tables.indexWhere((t) => t.number == tableNumber);
    if (index >= 0) {
      final table = _tables[index];
      
      // Only update the isOccupied status if provided
      if (isOccupied != null) {
        _tables[index] = TableModel(
          id: table.id,
          number: table.number,
          capacity: table.capacity,
          isOccupied: isOccupied,
          note: table.note,
        );
        
        await _saveTables();
        notifyListeners();
      }
    }
  }

  Future<void> deleteTable(String id) async {
    _tables.removeWhere((table) => table.id == id);
    await _saveTables();
    notifyListeners();
  }

  Future<void> toggleTableStatus(String id) async {
    final index = _tables.indexWhere((table) => table.id == id);
    if (index >= 0) {
      _tables[index].isOccupied = !_tables[index].isOccupied;
      await _saveTables();
      notifyListeners();
    }
  }

  // Add a method to set a specific table as occupied or available
  Future<void> setTableStatus(int tableNumber, bool isOccupied) async {
    final index = _tables.indexWhere((table) => table.number == tableNumber);
    if (index >= 0) {
      _tables[index].isOccupied = isOccupied;
      await _saveTables();
      notifyListeners();
      debugPrint('Table $tableNumber status set to ${isOccupied ? 'occupied' : 'available'}');
    } else {
      debugPrint('Table $tableNumber not found');
    }
  }

  // Method to refresh the tables data from storage
  // This ensures the status is always current across screens
  Future<void> refreshTables() async {
    await _loadTables();
  }
}