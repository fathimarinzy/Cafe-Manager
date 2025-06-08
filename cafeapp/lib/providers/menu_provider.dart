// lib/providers/menu_provider.dart
import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../services/api_service.dart';
import '../repositories/local_menu_repository.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import 'dart:async';

class MenuProvider with ChangeNotifier {
  List<MenuItem> _items = [];
  List<String> _categories = [];
  final ApiService _apiService = ApiService();
  final LocalMenuRepository _localRepo = LocalMenuRepository();
  final ConnectivityService _connectivityService = ConnectivityService();
  final SyncService _syncService = SyncService();
  
  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  SyncStatus get syncStatus => _syncService.currentStatus;
  Stream<SyncStatus> get syncStatusStream => _syncService.syncStatusStream;

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
    
    // Initialize connectivity service
    _connectivityService.initialize();
    
    // Initialize sync service
    _syncService.initialize();
    
    // Check initial connection status
    _isOfflineMode = !await _connectivityService.checkConnection();
    
    // Listen for connectivity changes
    _connectivityService.connectivityStream.listen((isConnected) {
      _isOfflineMode = !isConnected;
      
      // If we just went from offline to online, trigger a sync
      if (isConnected) {
        debugPrint('Connectivity restored, triggering sync');
        
        // Delay sync slightly to ensure connectivity is stable
        Future.delayed(const Duration(seconds: 2), () {
          _syncService.syncChanges().then((_) {
            // After sync completes, refresh data
            fetchMenu(forceRefresh: true);
            fetchCategories(forceRefresh: true);
          });
        });
      }
      
      notifyListeners();
    });
    
    // Listen for sync status changes
    _syncService.syncStatusStream.listen((status) {
      // Only notify if we're in a sync-related state
      if (status != SyncStatus.idle) {
        notifyListeners();
      }
      
      // If sync completed, refresh data
      if (status == SyncStatus.completed) {
        debugPrint('Sync completed, refreshing data');
        fetchMenu(forceRefresh: true);
        fetchCategories(forceRefresh: true);
      }
    });
    
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
      if (_isOfflineMode) {
        // Load from local database
        _items = await _localRepo.getMenuItems();
        debugPrint('Loaded ${_items.length} items from local database');
      } else {
        // Try to load from API first
        final menuItems = await _apiService.getMenu();
        
        // Save to local database for offline use
        await _localRepo.saveMenuItems(menuItems);
        
        // Only update and notify if there's an actual change
        if (!_itemListsEqual(_items, menuItems)) {
          _items = menuItems;
          debugPrint('Updated items from API: ${_items.length} items');
        }
      }
      
      notifyListeners();
    } catch (error) {
      debugPrint('Error fetching menu: $error');
      
      // If we're online but API call failed, try to load from local database
      if (!_isOfflineMode) {
        try {
          _items = await _localRepo.getMenuItems();
          debugPrint('Fallback: Loaded ${_items.length} items from local database');
          notifyListeners();
        } catch (localError) {
          debugPrint('Error loading from local database: $localError');
          rethrow;
        }
      } else {
        rethrow;
      }
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
      if (_isOfflineMode) {
        // Load categories from local database
        _categories = await _localRepo.getCategories();
        debugPrint('Loaded ${_categories.length} categories from local database');
      } else {
        // Try to load from API first
        final newCategories = await _apiService.getCategories();
        
        // Only update and notify if there's an actual change
        if (!_listsEqual(_categories, newCategories)) {
          _categories = newCategories;
          debugPrint('Updated categories from API: ${_categories.length} categories');
        }
      }
      
      notifyListeners();
    } catch (error) {
      debugPrint('Error fetching categories: $error');
      
      // If we're online but API call failed, try to load from local database
      if (!_isOfflineMode) {
        try {
          _categories = await _localRepo.getCategories();
          debugPrint('Fallback: Loaded ${_categories.length} categories from local database');
          notifyListeners();
        } catch (localError) {
          debugPrint('Error loading categories from local database: $localError');
          rethrow;
        }
      } else {
        rethrow;
      }
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

  // Add a new menu item (works online or offline)
  Future<MenuItem> addMenuItem(MenuItem item) async {
    try {
      MenuItem newItem;
      
      if (_isOfflineMode) {
        // Save locally only and queue for sync
        debugPrint('Adding menu item in offline mode');
        newItem = await _localRepo.addMenuItem(item);
        debugPrint('Added menu item locally: ${newItem.id}');
      } else {
        // Try to save to API first
        try {
          debugPrint('Adding menu item in online mode');
          newItem = await _apiService.addMenuItem(item);
          debugPrint('Added menu item to API: ${newItem.id}');
          
          // Also save to local DB for offline access
          await _localRepo.saveMenuItems([newItem]);
        } catch (apiError) {
          debugPrint('API error, falling back to local save: $apiError');
          
          // If API fails, save locally and queue for sync
          newItem = await _localRepo.addMenuItem(item);
          
          // Since we're technically online but API failed, trigger sync
          _syncService.syncChanges();
        }
      }
      
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

  // Update an existing menu item (works online or offline)
  Future<void> updateMenuItem(MenuItem updatedItem) async {
    try {
      if (_isOfflineMode) {
        // Save locally only and queue for sync
        debugPrint('Updating menu item in offline mode');
        await _localRepo.updateMenuItem(updatedItem);
        debugPrint('Updated menu item locally: ${updatedItem.id}');
      } else {
        // Try to update on API first
        try {
          debugPrint('Updating menu item in online mode');
          await _apiService.updateMenuItem(updatedItem);
          debugPrint('Updated menu item on API: ${updatedItem.id}');
          
          // Also update local DB for offline access
          await _localRepo.updateMenuItem(updatedItem);
        } catch (apiError) {
          debugPrint('API update error, falling back to local save: $apiError');
          
          // If API fails, update locally and queue for sync
          await _localRepo.updateMenuItem(updatedItem);
          
          // Since we're technically online but API failed, trigger sync
          _syncService.syncChanges();
        }
      }
      
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

  // Delete a menu item (works online or offline)
  Future<bool> deleteMenuItem(String id) async {
    try {
      if (_isOfflineMode) {
        // Delete locally only and queue for sync
        debugPrint('Deleting menu item in offline mode');
        await _localRepo.deleteMenuItem(id);
        debugPrint('Deleted menu item locally: $id');
      } else {
        // Try to delete from API first
        try {
          debugPrint('Deleting menu item in online mode');
          await _apiService.deleteMenuItem(id);
          debugPrint('Deleted menu item from API: $id');
          
          // Also delete from local DB
          await _localRepo.deleteMenuItem(id);
        } catch (apiError) {
          debugPrint('API delete error, falling back to local delete: $apiError');
          
          // If API fails, delete locally and queue for sync
          await _localRepo.deleteMenuItem(id);
          
          // Since we're technically online but API failed, trigger sync
          _syncService.syncChanges();
        }
      }
      
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

  // Add a new category (works online or offline)
  Future<bool> addCategory(String category) async {
    if (category.isEmpty) return false;
    
    category = category.trim(); // Trim whitespace
    
    try {
      // First check if category already exists to avoid duplicates
      if (_categories.contains(category)) {
        return true; // Category already exists, consider it a success
      }
      
      if (_isOfflineMode) {
        // Save locally only
        debugPrint('Adding category in offline mode');
        await _localRepo.addCategory(category);
        debugPrint('Added category locally: $category');
      } else {
        // Try to save to API first
        try {
          debugPrint('Adding category in online mode');
          await _apiService.addCategory(category);
          debugPrint('Added category to API: $category');
          
          // Also add to local DB for offline access
          await _localRepo.addCategory(category);
        } catch (apiError) {
          debugPrint('API error adding category, falling back to local save: $apiError');
          
          // If API fails, save locally
          await _localRepo.addCategory(category);
          
          // Since we're technically online but API failed, trigger sync
          _syncService.syncChanges();
        }
      }

      // Update local state
      _categories.add(category);
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('Error adding category: $error');
      return false;
    }
  }
  
  // Manually trigger synchronization
  Future<bool> syncChanges() async {
    debugPrint('Manually triggering sync from MenuProvider');
    return await _syncService.syncChanges();
  }
  
  // Check if there are pending changes to be synced
  Future<bool> hasPendingChanges() async {
    final pendingOps = await _localRepo.getPendingOperations();
    return pendingOps.isNotEmpty;
  }
  
  // Get the count of pending operations
  Future<int> getPendingChangesCount() async {
    final pendingOps = await _localRepo.getPendingOperations();
    return pendingOps.length;
  }
}