import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../services/api_service.dart';

class MenuProvider with ChangeNotifier {
  List<MenuItem> _items = [];
  List<String> _categories = [];
  final ApiService _apiService = ApiService();

  List<MenuItem> get items => [..._items];
  List<String> get categories => [..._categories];

  Future<void> fetchMenu() async {
    try {
      final menuItems = await _apiService.getMenu();
      _items = menuItems;
      notifyListeners();
    } catch (error) {
      debugPrint('Error fetching menu: $error');
      rethrow; // Preserves original stack trace
    }
  }

  Future<void> fetchCategories() async {
    try {
      final categories = await _apiService.getCategories();
      _categories = categories;
      notifyListeners();
    } catch (error) {
      debugPrint('Error fetching categories: $error');
      rethrow; // Preserves original stack trace
    }
  }

  List<MenuItem> getItemsByCategory(String category) {
    return _items.where((item) => item.category == category).toList();
  }

  // Add new methods for CRUD operations
  Future<void> addMenuItem(MenuItem item) async {
    try {
      // First ensure the category exists
      if (!_categories.contains(item.category)) {
        await addCategory(item.category);
      }
      
      // Call the API service to persist to database
      final newItem = await _apiService.addMenuItem(item);
      
      // Update local state after successful API call
      _items.add(newItem);
      notifyListeners();
    } catch (error) {
      debugPrint('Error adding menu item: $error');
      rethrow;
    }
  }

  Future<void> updateMenuItem(MenuItem updatedItem) async {
    try {
      // Ensure the category exists if it's been changed
      if (!_categories.contains(updatedItem.category)) {
        await addCategory(updatedItem.category);
      }
      
      // Call the API service to persist to database
      await _apiService.updateMenuItem(updatedItem);
      
      // Update local state after successful API call
      final index = _items.indexWhere((item) => item.id == updatedItem.id);
      if (index >= 0) {
        _items[index] = updatedItem;
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Error updating menu item: $error');
      rethrow;
    }
  }

  Future<bool> deleteMenuItem(String id) async {
    try {
      // Call the API service to persist to database
      await _apiService.deleteMenuItem(id);
      
      // Update local state after successful API call
      final previousLength = _items.length;
      _items.removeWhere((item) => item.id == id);
      
      // Verify that an item was actually removed
      final wasRemoved = _items.length < previousLength;
      
      // Only notify listeners if the state actually changed
      if (wasRemoved) {
        notifyListeners();
      } else {
        // If no item was removed locally but API call succeeded,
        // refresh the entire menu to ensure consistency
        await fetchMenu();
      }
      
      return true;
    } catch (error) {
      debugPrint('Error deleting menu item: $error');
      // Try to refresh data to ensure UI is in sync
      try {
        await fetchMenu();
      } catch (_) {
        // Ignore errors during refresh attempt
      }
      return false;
    }
  }

  // Improved addCategory method with error handling
  Future<bool> addCategory(String category) async {
    if (category.isEmpty) return false;
    
    category = category.trim(); // Trim whitespace
    
    try {
      // First check if category already exists to avoid duplicates
      if (_categories.contains(category)) {
        return true; // Category already exists, consider it a success
      }
      
      // Call the API service to persist to database
      await _apiService.addCategory(category);

      // Update local state after successful API call
      if (!_categories.contains(category)) {
        _categories.add(category);
        // Make sure to notify listeners to update the UI
        notifyListeners();
      }
      return true;
    } catch (error) {
      debugPrint('Error adding category: $error');
      // Return false instead of rethrowing to allow graceful failure handling
      return false;
    }
  }
}