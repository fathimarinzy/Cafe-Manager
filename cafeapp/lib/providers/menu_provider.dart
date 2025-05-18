import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../services/api_service.dart';

class MenuProvider with ChangeNotifier {
  List<MenuItem> _items = [];
  List<String> _categories = [];
  final ApiService _apiService = ApiService();

  List<MenuItem> get items => [..._items];
  List<String> get categories => [..._categories];

   Future<void> fetchMenu({bool forceRefresh = false}) async {
  // Don't fetch if items already loaded and no force refresh
  if (items.isNotEmpty && !forceRefresh) {
    return;
  }
  
  try {
    final menuItems = await _apiService.getMenu();
    
    // Only update and notify if there's an actual change
    if (!_itemListsEqual(_items, menuItems)) {
      _items = menuItems;
      notifyListeners();
    }
  } catch (error) {
    debugPrint('Error fetching menu: $error');
    rethrow;
  }
}

  // Helper to check if two item lists are logically equal
  bool _itemListsEqual(List<MenuItem> list1, List<MenuItem> list2) {
    if (list1.length != list2.length) return false;
    
    // Create maps by ID for fast comparison
    final map1 = {for (var item in list1) item.id: item};
    final map2 = {for (var item in list2) item.id: item};
    
    // Check if all keys match
    if (!_setsEqual(map1.keys.toSet(), map2.keys.toSet())) {
      return false;
    }
    
    // Check if all values match
    for (final id in map1.keys) {
      final item1 = map1[id]!;
      final item2 = map2[id]!;
      
      if (item1.name != item2.name ||
          item1.price != item2.price ||
          item1.category != item2.category ||
          item1.isAvailable != item2.isAvailable) {
        return false;
      }
    }
    
    return true;
  }
  
  // Helper to check if two sets are equal
  bool _setsEqual<T>(Set<T> a, Set<T> b) {
    return a.length == b.length && a.containsAll(b);
  }

  Future<void> fetchCategories({bool forceRefresh = false}) async {
  // Don't fetch if categories already loaded and no force refresh
  if (categories.isNotEmpty && !forceRefresh) {
    return;
  }
  
  try {
    final newCategories = await _apiService.getCategories();
    
    // Only update and notify if there's an actual change
    if (!_listsEqual(_categories, newCategories)) {
      _categories = newCategories;
      notifyListeners();
    }
  } catch (error) {
    debugPrint('Error fetching categories: $error');
    rethrow;
  }
}

  
  // Helper to check if two lists are equal
  bool _listsEqual<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  List<MenuItem> getItemsByCategory(String category) {
    return _items.where((item) => item.category == category).toList();
  }

  // Add new methods for CRUD operations
  Future<MenuItem> addMenuItem(MenuItem item) async {
    try {
      // First ensure the category exists
      if (!_categories.contains(item.category)) {
        await addCategory(item.category);
      }
      
      // Call the API service to persist to database - pass the MenuItem directly
      final newItem = await _apiService.addMenuItem(item);
      
      // Update local state after successful API call
      _items.add(newItem);
      notifyListeners();
      
      return newItem;
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
    // Call the API service to delete from database
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
  } catch (e) {
    debugPrint('Error deleting menu item: $e');
    
    // Check if this is a foreign key constraint error
    final String errorMsg = e.toString().toLowerCase();
    if (errorMsg.contains('foreign key') || errorMsg.contains('constraint')) {
      // This is expected for items used in orders - provide proper error handling
      debugPrint('Cannot delete menu item because it is referenced in orders');
    }
    
    // Try to refresh data to ensure UI is in sync
    try {
      await fetchMenu();
    } catch (_) {
      // Ignore errors during refresh attempt
    }
    
    // Propagate the error to the UI
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