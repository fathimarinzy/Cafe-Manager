// lib/providers/menu_provider.dart (UPDATED WITH SYNC)
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';
import '../repositories/local_menu_repository.dart';
import '../services/menu_sync_service.dart';

class MenuProvider with ChangeNotifier {
  List<MenuItem> _items = [];
  List<String> _categories = [];
  final LocalMenuRepository _localRepo = LocalMenuRepository();
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _syncEnabled = false;

  List<MenuItem> get items => [..._items];
  List<String> get categories => [..._categories];
  
  static final MenuProvider _instance = MenuProvider._internal();
  
  factory MenuProvider() => _instance;
  
  MenuProvider._internal() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();
    
    debugPrint('Initializing MenuProvider');
    
    try {
      // Check if device sync is enabled
      final prefs = await SharedPreferences.getInstance();
      _syncEnabled = prefs.getBool('device_sync_enabled') ?? false;
      final companyId = prefs.getString('company_id') ?? '';
      
      // Load initial data
      await Future.wait([
        fetchMenu(),
        fetchCategories()
      ]);
      
      // Start listening to menu changes if sync is enabled
      if (_syncEnabled && companyId.isNotEmpty) {
        _startMenuSync(companyId);
      }
    } catch (e) {
      debugPrint('Error during initial data load: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  /// Start menu sync listeners
  void _startMenuSync(String companyId) {
    debugPrint('🔄 Starting menu sync listeners');
    
    // Listen to menu item changes
    MenuSyncService.startListeningToMenuItems(
      companyId,
      (syncItem) async {
        // New or updated item received
        await MenuSyncService.saveSyncedMenuItemLocally(syncItem);
        // Refresh both menu items and categories (in case a new category was added)
        await Future.wait([
          fetchMenu(forceRefresh: true),
          fetchCategories(forceRefresh: true),
        ]);
      },
      (itemId) async {
        // Item deleted
        await MenuSyncService.deleteSyncedMenuItemLocally(itemId);
        await fetchMenu(forceRefresh: true);
      },
    );
    
    // Listen to business info changes
    MenuSyncService.startListeningToBusinessInfo(
      companyId,
      (businessInfo) async {
        await MenuSyncService.saveSyncedBusinessInfoLocally(businessInfo);
        debugPrint('✅ Business info updated from sync');
      },
    );
    
    // Listen to category changes
    MenuSyncService.startListeningToCategories(
      companyId,
      (categories) async {
        await MenuSyncService.saveSyncedCategoriesLocally(categories);
        await fetchCategories(forceRefresh: true);
      },
    );
  }
  
  Future<void> fetchMenu({bool forceRefresh = false}) async {
    if (items.isNotEmpty && !forceRefresh) {
      return;
    }
    
    try {
      _items = await _localRepo.getMenuItems();
      debugPrint('Loaded ${_items.length} items from local database');
      
      notifyListeners();
    } catch (error) {
      debugPrint('Error fetching menu: $error');
      rethrow;
    }
  }

  Future<void> fetchCategories({bool forceRefresh = false}) async {
    if (categories.isNotEmpty && !forceRefresh) {
      return;
    }
    
    try {
      _categories = await _localRepo.getCategories();
      debugPrint('Loaded ${_categories.length} categories from local database');
      
      notifyListeners();
    } catch (error) {
      debugPrint('Error fetching categories: $error');
      rethrow;
    }
  }

  List<MenuItem> getItemsByCategory(String category) {
    return _items.where((item) => item.category == category).toList();
  }

  /// Add a new menu item (with sync)
  Future<MenuItem> addMenuItem(MenuItem item) async {
    try {
      debugPrint('Adding menu item to local database');
      final newItem = await _localRepo.addMenuItem(item);
      debugPrint('Added menu item locally: ${newItem.id}');
      
      _items.add(newItem);
      
      bool isNewCategory = false;
      if (!_categories.contains(newItem.category)) {
        _categories.add(newItem.category);
        isNewCategory = true;
      }
      
      notifyListeners();
      
      // Sync to Firestore if enabled
      if (_syncEnabled) {
        MenuSyncService.syncMenuItemToFirestore(newItem);
        
        // If this is a new category, sync categories too
        if (isNewCategory) {
          MenuSyncService.syncCategoriesToFirestore(_categories);
        }
      }
      
      return newItem;
    } catch (error) {
      debugPrint('Error adding menu item: $error');
      rethrow;
    }
  }

  /// Update an existing menu item (with sync)
  Future<void> updateMenuItem(MenuItem updatedItem) async {
    try {
      debugPrint('Updating menu item in local database');
      await _localRepo.updateMenuItem(updatedItem);
      debugPrint('Updated menu item locally: ${updatedItem.id}');
      
      final index = _items.indexWhere((item) => item.id == updatedItem.id);
      if (index >= 0) {
        _items[index] = updatedItem;
        
        if (!_categories.contains(updatedItem.category)) {
          _categories.add(updatedItem.category);
        }
        
        notifyListeners();
      }
      
      // Sync to Firestore if enabled
      if (_syncEnabled) {
        MenuSyncService.syncMenuItemToFirestore(updatedItem);
      }
    } catch (error) {
      debugPrint('Error updating menu item: $error');
      rethrow;
    }
  }

  /// Delete a menu item (with sync)
  Future<bool> deleteMenuItem(String id) async {
    try {
      debugPrint('Deleting menu item from local database');
      await _localRepo.deleteMenuItem(id);
      debugPrint('Deleted menu item locally: $id');
      
      final previousLength = _items.length;
      _items.removeWhere((item) => item.id == id);
      
      final wasRemoved = _items.length < previousLength;
      
      if (wasRemoved) {
        notifyListeners();
      } else {
        await fetchMenu(forceRefresh: true);
      }
      
      // Sync deletion to Firestore if enabled
      if (_syncEnabled) {
        MenuSyncService.syncMenuItemDeletionToFirestore(id);
      }
      
      return true;
    } catch (e) {
      debugPrint('Error deleting menu item: $e');
      
      try {
        await fetchMenu(forceRefresh: true);
      } catch (_) {}
      
      return false;
    }
  }

  /// Add a new category (with sync)
  Future<bool> addCategory(String category) async {
    if (category.isEmpty) return false;
    
    category = category.trim();
    
    try {
      if (_categories.contains(category)) {
        return true;
      }
      
      debugPrint('Adding category to local database');
      await _localRepo.addCategory(category);
      debugPrint('Added category locally: $category');

      _categories.add(category);
      notifyListeners();
      
      // Sync categories to Firestore if enabled
      if (_syncEnabled) {
        MenuSyncService.syncCategoriesToFirestore(_categories);
      }
      
      return true;
    } catch (error) {
      debugPrint('Error adding category: $error');
      return false;
    }
  }

  /// Update a category name (with sync)
  Future<bool> updateCategory(String oldCategory, String newCategory) async {
    if (oldCategory.isEmpty || newCategory.isEmpty) return false;
    
    final trimmedNewCategory = newCategory.trim();
    final trimmedOldCategory = oldCategory.trim();
    
    if (trimmedOldCategory == trimmedNewCategory) return true;
    
    try {
      if (_categories.contains(trimmedNewCategory)) {
        debugPrint('Category "$trimmedNewCategory" already exists');
        return false;
      }
      
      debugPrint('Updating category from "$trimmedOldCategory" to "$trimmedNewCategory"');
      await _localRepo.updateCategory(trimmedOldCategory, trimmedNewCategory);
      debugPrint('Category updated successfully');
      
      final index = _categories.indexOf(trimmedOldCategory);
      if (index >= 0) {
        _categories[index] = trimmedNewCategory;
      }
      
      for (var item in _items) {
        if (item.category == trimmedOldCategory) {
          final updatedItem = item.copyWith(category: trimmedNewCategory);
          final itemIndex = _items.indexWhere((i) => i.id == item.id);
          if (itemIndex >= 0) {
            _items[itemIndex] = updatedItem;
          }
        }
      }
      
      notifyListeners();
      
      // Sync categories to Firestore if enabled
      if (_syncEnabled) {
        MenuSyncService.syncCategoriesToFirestore(_categories);
        
        // Also sync all updated items
        final updatedItems = _items.where((item) => item.category == trimmedNewCategory);
        for (var item in updatedItems) {
          MenuSyncService.syncMenuItemToFirestore(item);
        }
      }
      
      return true;
    } catch (error) {
      debugPrint('Error updating category: $error');
      return false;
    }
  }

  /// Delete a category (with sync)
  Future<bool> deleteCategory(String category) async {
    if (category.isEmpty) return false;
    
    try {
      debugPrint('Deleting category: $category');
      await _localRepo.deleteCategory(category);
      debugPrint('Category deleted successfully');
      
      _categories.remove(category);
      
      // Get items to delete for syncing
      final itemsToDelete = _items.where((item) => item.category == category).toList();
      _items.removeWhere((item) => item.category == category);
      
      notifyListeners();
      
      // Sync deletion to Firestore if enabled
      if (_syncEnabled) {
        MenuSyncService.syncCategoriesToFirestore(_categories);
        
        // Sync item deletions
        for (var item in itemsToDelete) {
          MenuSyncService.syncMenuItemDeletionToFirestore(item.id);
        }
      }
      
      return true;
    } catch (error) {
      debugPrint('Error deleting category: $error');
      return false;
    }
  }

  int getCategoryItemCount(String category) {
    return _items.where((item) => item.category == category).length;
  }

  /// Enable/disable sync
  Future<void> setSyncEnabled(bool enabled) async {
    _syncEnabled = enabled;
    
    if (enabled) {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id') ?? '';
      
      if (companyId.isNotEmpty) {
        _startMenuSync(companyId);
        
        // If main device, sync all items immediately
        final isMainDevice = prefs.getBool('is_main_device') ?? false;
        if (isMainDevice) {
          await MenuSyncService.syncAllMenuItemsToFirestore();
        }
      }
    } else {
      MenuSyncService.stopAllListeners();
    }
  }



  /// Delete ALL menu items and categories (reset menu)
  Future<bool> deleteAllMenuItems() async {
    try {
      debugPrint('🚨 Deleting ALL menu items and categories');
      
      // Get all item IDs before deleting to sync the deletions
      final allItems = [..._items];
      
      await _localRepo.deleteAllMenuItems();
      debugPrint('Local database cleared');
      
      // Update local state
      _items.clear();
      _categories.clear();
      
      notifyListeners();
      
      // Sync to Firestore if enabled
      if (_syncEnabled) {
        // We sync deletions for each item
        for (var item in allItems) {
           MenuSyncService.syncMenuItemDeletionToFirestore(item.id);
        }
        // Sync empty categories list
        MenuSyncService.syncCategoriesToFirestore([]);
      }
      
      return true;
    } catch (e) {
      debugPrint('Error deleting all menu items: $e');
      // Attempt to reload state if something went wrong
      try {
        await fetchMenu(forceRefresh: true);
        await fetchCategories(forceRefresh: true);
      } catch (_) {}
      
      return false;
    }
  }

  @override
  void dispose() {
    MenuSyncService.stopAllListeners();
    super.dispose();
  }
} 