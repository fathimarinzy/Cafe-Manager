// lib/providers/menu_provider.dart
import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../repositories/local_menu_repository.dart';

class MenuProvider with ChangeNotifier {
  List<MenuItem> _items = [];
  List<String> _categories = [];
  final LocalMenuRepository _localRepo = LocalMenuRepository();
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<MenuItem> get items => [..._items];
  List<String> get categories => [..._categories];
  
  // Make constructor private to enforce singleton pattern
  static final MenuProvider _instance = MenuProvider._internal();
  
  // Factory constructor returns singleton instance
  factory MenuProvider() => _instance;
  
  // Private constructor
  MenuProvider._internal() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();
    
    debugPrint('Initializing MenuProvider');
    
    // Initial data load
    try {
      await Future.wait([
        fetchMenu(),
        fetchCategories()
      ]);
    } catch (e) {
      debugPrint('Error during initial data load: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> fetchMenu({bool forceRefresh = false}) async {
    // Don't fetch if items already loaded and no force refresh
    if (items.isNotEmpty && !forceRefresh) {
      return;
    }
    
    try {
      // Load from local database
      _items = await _localRepo.getMenuItems();
      debugPrint('Loaded ${_items.length} items from local database');
      
      notifyListeners();
    } catch (error) {
      debugPrint('Error fetching menu: $error');
      rethrow;
    }
  }

  Future<void> fetchCategories({bool forceRefresh = false}) async {
    // Don't fetch if categories already loaded and no force refresh
    if (categories.isNotEmpty && !forceRefresh) {
      return;
    }
    
    try {
      // Load categories from local database
      _categories = await _localRepo.getCategories();
      debugPrint('Loaded ${_categories.length} categories from local database');
      
      notifyListeners();
    } catch (error) {
      debugPrint('Error fetching categories: $error');
      rethrow;
    }
  }
  
  // Helper to check if two lists are equal
  // bool _listsEqual<T>(List<T> list1, List<T> list2) {
  //   if (list1.length != list2.length) return false;
  //   for (int i = 0; i < list1.length; i++) {
  //     if (list1[i] != list2[i]) return false;
  //   }
  //   return true;
  // }

  List<MenuItem> getItemsByCategory(String category) {
    return _items.where((item) => item.category == category).toList();
  }

  // Add a new menu item
  Future<MenuItem> addMenuItem(MenuItem item) async {
    try {
      // Save locally
      debugPrint('Adding menu item to local database');
      final newItem = await _localRepo.addMenuItem(item);
      debugPrint('Added menu item locally: ${newItem.id}');
      
      // Update local state
      _items.add(newItem);
      
      // Make sure the category exists
      if (!_categories.contains(newItem.category)) {
        _categories.add(newItem.category);
      }
      
      notifyListeners();
      return newItem;
    } catch (error) {
      debugPrint('Error adding menu item: $error');
      rethrow;
    }
  }

  // Update an existing menu item
  Future<void> updateMenuItem(MenuItem updatedItem) async {
    try {
      // Save locally
      debugPrint('Updating menu item in local database');
      await _localRepo.updateMenuItem(updatedItem);
      debugPrint('Updated menu item locally: ${updatedItem.id}');
      
      // Update local state
      final index = _items.indexWhere((item) => item.id == updatedItem.id);
      if (index >= 0) {
        _items[index] = updatedItem;
        
        // Make sure the category exists
        if (!_categories.contains(updatedItem.category)) {
          _categories.add(updatedItem.category);
        }
        
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Error updating menu item: $error');
      rethrow;
    }
  }

  // Delete a menu item
  Future<bool> deleteMenuItem(String id) async {
    try {
      // Delete locally
      debugPrint('Deleting menu item from local database');
      await _localRepo.deleteMenuItem(id);
      debugPrint('Deleted menu item locally: $id');
      
      // Update local state
      final previousLength = _items.length;
      _items.removeWhere((item) => item.id == id);
      
      // Verify that an item was actually removed
      final wasRemoved = _items.length < previousLength;
      
      // Only notify listeners if the state actually changed
      if (wasRemoved) {
        notifyListeners();
      } else {
        // If no item was removed locally but operation succeeded,
        // refresh the entire menu to ensure consistency
        await fetchMenu(forceRefresh: true);
      }
      
      return true;
    } catch (e) {
      debugPrint('Error deleting menu item: $e');
      
      // Try to refresh data to ensure UI is in sync
      try {
        await fetchMenu(forceRefresh: true);
      } catch (_) {
        // Ignore errors during refresh attempt
      }
      
      return false;
    }
  }

  // Add a new category
  Future<bool> addCategory(String category) async {
    if (category.isEmpty) return false;
    
    category = category.trim(); // Trim whitespace
    
    try {
      // First check if category already exists to avoid duplicates
      if (_categories.contains(category)) {
        return true; // Category already exists, consider it a success
      }
      
      // Save locally
      debugPrint('Adding category to local database');
      await _localRepo.addCategory(category);
      debugPrint('Added category locally: $category');

      // Update local state
      _categories.add(category);
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('Error adding category: $error');
      return false;
    }
  }
}