import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Added import for Provider
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/person.dart';
import '../models/table_model.dart';
import '../providers/table_provider.dart';
import '../services/api_service.dart';
import '../services/bill_service.dart';
import '../providers/settings_provider.dart';

class OrderProvider with ChangeNotifier {
  // Map to store cart items for each service type or table
  // The key is the service type identifier (e.g., "Delivery", "Takeout", "Dining - Table 1")
  final Map<String, List<MenuItem>> _serviceTypeCarts = {};
  
  // Map to store totals for each service type
  final Map<String, Map<String, double>> _serviceTotals = {};
  
  String _currentServiceType = '';
  final ApiService _apiService = ApiService();
  // Add this property to track current order ID
  int? _currentOrderId;

  // Add getter and setter for current order ID
  int? get currentOrderId => _currentOrderId;

  void setCurrentOrderId(int? orderId) {
    _currentOrderId = orderId;
    notifyListeners();
  }
  void resetCurrentOrder() {
  _currentOrderId = null;
  notifyListeners();
}
  // Track selected person for order
  Person? _selectedPerson;
  
  // Getter for current service type
  String get currentServiceType => _currentServiceType;

  // Getter and setter for selected person
  Person? get selectedPerson => _selectedPerson;
  
  void setSelectedPerson(Person? person) {
    _selectedPerson = person;
    notifyListeners();
  }
  void clearSelectedPerson() {
  _selectedPerson = null;
  notifyListeners();
}

  // Set current service type and notify listeners
  void setCurrentServiceType(String serviceType, [BuildContext? context]) {
    _currentServiceType = serviceType;
    if (context != null) {
      _context = context;
    }
    // Initialize the cart for this service type if it doesn't exist
    if (!_serviceTypeCarts.containsKey(serviceType)) {
      _serviceTypeCarts[serviceType] = [];
    }
    
    // Initialize the totals for this service type if they don't exist
    if (!_serviceTotals.containsKey(serviceType)) {
      _serviceTotals[serviceType] = {
        'subtotal': 0,
        'tax': 0,
        'discount': 0,
        'total': 0,
      };
    }
    
    notifyListeners();
  }

  // Get cart items for current service type
  List<MenuItem> get cartItems {
    return [...(_serviceTypeCarts[_currentServiceType] ?? [])];
  }
  
  // Get subtotal for current service type
  double get subtotal {
    return _serviceTotals[_currentServiceType]?['subtotal'] ?? 0;
  }
  
  // Get tax for current service type
  double get tax {
    return _serviceTotals[_currentServiceType]?['tax'] ?? 0;
  }
  
  // Get discount for current service type
  double get discount {
    return _serviceTotals[_currentServiceType]?['discount'] ?? 0;
  }
  
  // Get total for current service type
  double get total {
    return _serviceTotals[_currentServiceType]?['total'] ?? 0;
  }

  // Add item to cart for current service type
  void addToCart(MenuItem item) {
  if (_currentServiceType.isEmpty) {
    debugPrint('Warning: No service type selected');
    return;
  }
  
  final existingIndex = _serviceTypeCarts[_currentServiceType]!
      .indexWhere((cartItem) => cartItem.id == item.id);

  if (existingIndex >= 0) {
    // Keep the existing kitchen note if the item already has one
    String existingNote = _serviceTypeCarts[_currentServiceType]![existingIndex].kitchenNote;
    String noteToUse = item.kitchenNote.isNotEmpty ? item.kitchenNote : existingNote;
    
    _serviceTypeCarts[_currentServiceType]![existingIndex].quantity += 1;
    
    // Update the kitchen note if needed
    if (item.kitchenNote.isNotEmpty && item.kitchenNote != existingNote) {
      _serviceTypeCarts[_currentServiceType]![existingIndex] = MenuItem(
        id: item.id,
        name: item.name,
        price: item.price,
        imageUrl: item.imageUrl,
        category: item.category,
        isAvailable: item.isAvailable,
        quantity: _serviceTypeCarts[_currentServiceType]![existingIndex].quantity,
        kitchenNote: noteToUse,
      );
    }
    } else {
      final newItem = MenuItem(
        id: item.id,
        name: item.name,
        price: item.price,
        imageUrl: item.imageUrl,
        category: item.category,
        isAvailable: item.isAvailable,
        quantity: 1,
        kitchenNote: item.kitchenNote,
      );
      _serviceTypeCarts[_currentServiceType]!.add(newItem);
    }
    
    _updateTotals(_currentServiceType);
    notifyListeners();
  }
  // Update item quantity for current service type
  void updateItemQuantity(String id, int quantity) {
    if (_currentServiceType.isEmpty) return;
    
    final itemIndex = _serviceTypeCarts[_currentServiceType]!
        .indexWhere((item) => item.id == id);
        
    if (itemIndex >= 0) {
      _serviceTypeCarts[_currentServiceType]![itemIndex].quantity = 
          quantity > 0 ? quantity : 1; // Ensure min quantity is 1
      _updateTotals(_currentServiceType);
      notifyListeners();
    }
  }

  // Remove one quantity from cart item for current service type
  void removeFromCart(String id) {
    if (_currentServiceType.isEmpty) return;
    
    try {
      final cartItemIndex = _serviceTypeCarts[_currentServiceType]!
          .indexWhere((item) => item.id == id);
          
      if (cartItemIndex >= 0) {
        final cartItem = _serviceTypeCarts[_currentServiceType]![cartItemIndex];
        
        if (cartItem.quantity > 1) {
          cartItem.quantity -= 1;
        } else {
          _serviceTypeCarts[_currentServiceType]!.removeAt(cartItemIndex);
        }
        
        _updateTotals(_currentServiceType);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Item not found in cart: $e');
    }
  }

  // Remove item completely from cart for current service type
  void removeItem(String id) {
    if (_currentServiceType.isEmpty) return;
    
    _serviceTypeCarts[_currentServiceType]!
        .removeWhere((item) => item.id == id);
    _updateTotals(_currentServiceType);
    notifyListeners();
  }

  // Clear cart for current service type
  void clearCart() {
    if (_currentServiceType.isEmpty) return;
    
    _serviceTypeCarts[_currentServiceType]!.clear();
    _updateTotals(_currentServiceType);
    notifyListeners();
  }

  // Clear all carts
  void clearAllCarts() {
    _serviceTypeCarts.clear();
    _serviceTotals.clear();
    notifyListeners();
  }

   // Update _updateTotals to use the tax rate from settings
  void _updateTotals(String serviceType) {
    if (!_serviceTypeCarts.containsKey(serviceType)) return;

    final cartItems = _serviceTypeCarts[serviceType]!;
    final subtotal = cartItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    
    // Get tax rate from SettingsProvider (need to pass context)
    final BuildContext? context = _context;
    double taxRate = 0.0; // Default value
    
    if (context != null && context.mounted) {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      taxRate = settingsProvider.taxRate;
    }
    
    // Calculate tax using the configured tax rate
    final tax = subtotal * (taxRate / 100.0);
    final discount = _serviceTotals[serviceType]?['discount'] ?? 0.0;
    final calculatedTotal = (subtotal + tax - discount).clamp(0.0, double.infinity);

    _serviceTotals[serviceType] = {
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': calculatedTotal,
    };
  }
   // For this to work, we need to store the BuildContext
  BuildContext? _context;
  
  // Method to set context
  void setContext(BuildContext context) {
    _context = context;
  }

  // Set discount for current service type
  void setDiscount(double discount) {
    if (_currentServiceType.isEmpty) return;
    
    if (!_serviceTotals.containsKey(_currentServiceType)) {
      _serviceTotals[_currentServiceType] = {
        'subtotal': 0,
        'tax': 0,
        'discount': 0,
        'total': 0,
      };
    }
    
    _serviceTotals[_currentServiceType]!['discount'] = discount >= 0 ? discount : 0;
    _updateTotals(_currentServiceType);
    notifyListeners();
  }



  Future<Map<String, dynamic>> processOrderWithBill(BuildContext context) async {
  // First check if we have items in the cart
  if (_currentServiceType.isEmpty || cartItems.isEmpty) {
    return {
      'success': false,
      'message': 'No items in cart',
    };
  }

  try {
    // Extract table number from service type if this is a dining order
    String? tableInfo;
    int? tableNumber;
    
    if (_currentServiceType.startsWith('Dining - Table')) {
      tableInfo = _currentServiceType;
      // Extract the table number
      final tableNumberString = _currentServiceType.split('Table ').last;
      tableNumber = int.tryParse(tableNumberString);
    }
    
    // Create or update the order first (to get the order ID)
    Order? order;
    if (_currentOrderId != null) {
      // Update existing order
      final items = _serviceTypeCarts[_currentServiceType]!.map((item) => item.toJson()).toList();
      order = await _apiService.updateOrder(
        _currentOrderId!,
        _currentServiceType,
        items,
        subtotal,
        tax,
        discount,
        total,
      );
    } else {
      // Create a new order in the database
      final items = _serviceTypeCarts[_currentServiceType]!.map((item) => item.toJson()).toList();
      order = await _apiService.createOrder(
        _currentServiceType,
        items,
        subtotal,
        tax,
        discount,
        total,
      );
    }
    
    if (order == null) {
      return {
        'success': false,
        'message': 'Failed to create or update order in the system',
      };
    }
    
    // Now print the kitchen receipt with the order ID
    final String orderNumberPadded = order.id.toString().padLeft(4, '0');
    Map<String, dynamic> printResult = await BillService.printKitchenOrderReceipt(
      items: cartItems,
      serviceType: _currentServiceType,
      tableInfo: tableInfo,
      orderNumber: orderNumberPadded,
      context: context, // Pass context for dialog if needed
    );
    
    // If this is a table order, update the table status to occupied
    if (tableNumber != null && context.mounted) {
      final tableProvider = Provider.of<TableProvider>(context, listen: false);
      final table = tableProvider.tables.firstWhere(
        (table) => table.number == tableNumber,
        orElse: () => TableModel(id: '', number: tableNumber!, isOccupied: false)
      );
      
      if (table.id.isNotEmpty) {
        // Set the table as occupied
        final updatedTable = TableModel(
          id: table.id,
          number: table.number,
          isOccupied: true,
          capacity: table.capacity,
          note: table.note,
        );
        
        await tableProvider.updateTable(updatedTable);
        debugPrint('Table ${tableNumber.toString()} status updated to occupied');
      } else if (tableNumber > 0) {
        // If the table wasn't found in the provider but we have a valid number,
        // try to update it by number
        await tableProvider.setTableStatus(tableNumber, true);
        debugPrint('Table ${tableNumber.toString()} status set to occupied by number');
      }
    }

    // Clear the current service type's cart
    clearCart();
    // Reset the current order ID
    _currentOrderId = null;
    
    return {
      'success': true,
      'message': printResult['message'] ?? 'Order processed successfully',
      'order': order,
      'billPrinted': printResult['printed'] ?? false,
      'billSaved': printResult['saved'] ?? false,
    };
  } catch (error) {
    debugPrint('Error processing order: $error');
    return {
      'success': false,
      'message': 'Error processing order: $error',
    };
  }
}
  // Place order for current service type (original method kept for compatibility)
  Future<bool> placeOrder(String serviceType) async {
    if (_currentServiceType.isEmpty || _serviceTypeCarts[_currentServiceType]!.isEmpty) {
      return false;
    }

    try {
      final items = _serviceTypeCarts[_currentServiceType]!.map((item) => item.toJson()).toList();
      final subtotal = _serviceTotals[_currentServiceType]!['subtotal'] ?? 0;
      final tax = _serviceTotals[_currentServiceType]!['tax'] ?? 0;
      final discount = _serviceTotals[_currentServiceType]!['discount'] ?? 0;
      final total = _serviceTotals[_currentServiceType]!['total'] ?? 0;
      
      final order = await _apiService.createOrder(
        serviceType,
        items,
        subtotal,
        tax,
        discount,
        total,
      );

      if (order != null) {
        // Clear only the current service type's cart
        _serviceTypeCarts[_currentServiceType]!.clear();
        _updateTotals(_currentServiceType);
        notifyListeners();
        return true;
      }
      return false;
    } catch (error) {
      debugPrint('Error placing order: $error');
      return false;
    }
  }

  // Fetch orders from the API
  Future<List<Order>> fetchOrders() async {
    try {
      return await _apiService.getOrders();
    } catch (error) {
      debugPrint('Error fetching orders: $error');
      return [];
    }
  }
  
  // Check if a service type has items in cart
  bool hasItemsInCart(String serviceType) {
    return _serviceTypeCarts.containsKey(serviceType) && 
           _serviceTypeCarts[serviceType]!.isNotEmpty;
  }
  
  // Get the number of items in a service type's cart
  int getItemCount(String serviceType) {
    if (!_serviceTypeCarts.containsKey(serviceType)) {
      return 0;
    }
    
    return _serviceTypeCarts[serviceType]!.fold(
        0, (sum, item) => sum + item.quantity);
  }

  // Update an item's kitchen note in the cart
  void updateItemNote(String id, String note) {
  if (_currentServiceType.isEmpty) return;
  
  // Ensure the service type cart exists
  if (!_serviceTypeCarts.containsKey(_currentServiceType)) {
    _serviceTypeCarts[_currentServiceType] = [];
  }
  
  final itemIndex = _serviceTypeCarts[_currentServiceType]!
      .indexWhere((item) => item.id == id);
      
  if (itemIndex >= 0) {
    // Create a copy with the updated note to ensure proper state management
    final item = _serviceTypeCarts[_currentServiceType]![itemIndex];
    final updatedItem = MenuItem(
      id: item.id,
      name: item.name,
      price: item.price,
      imageUrl: item.imageUrl,
      category: item.category,
      isAvailable: item.isAvailable,
      quantity: item.quantity,
      kitchenNote: note,
    );
    
    // Replace the item in the cart
    _serviceTypeCarts[_currentServiceType]![itemIndex] = updatedItem;
    
    notifyListeners();
    debugPrint('Updated kitchen note for item $id: $note');
  }
}


// Modify the existing placeOrder method or add a new one to handle updating existing orders
Future<bool> updateExistingOrder(int orderId) async {
  if (_currentServiceType.isEmpty || _serviceTypeCarts[_currentServiceType]!.isEmpty) {
    return false;
  }

  try {
    final items = _serviceTypeCarts[_currentServiceType]!.map((item) => item.toJson()).toList();
    final subtotal = _serviceTotals[_currentServiceType]!['subtotal'] ?? 0;
    final tax = _serviceTotals[_currentServiceType]!['tax'] ?? 0;
    final discount = _serviceTotals[_currentServiceType]!['discount'] ?? 0;
    final total = _serviceTotals[_currentServiceType]!['total'] ?? 0;
    
    // Call API to update the existing order
    final order = await _apiService.updateOrder(
      orderId,
      _currentServiceType,
      items,
      subtotal,
      tax,
      discount,
      total,
    );

    if (order != null) {
      // Clear only the current service type's cart
      _serviceTypeCarts[_currentServiceType]!.clear();
      _updateTotals(_currentServiceType);
      notifyListeners();
      return true; 
    }
    return false;
  } catch (error) {
    debugPrint('Error updating order: $error');
    return false;
  }
}
// Add this method to the OrderProvider class to load existing items into the cart

// Load items from an existing order into the cart
Future<void> loadExistingOrderItems(int orderId) async {
  try {
    // First clear the current cart to avoid duplicates
    if (_serviceTypeCarts.containsKey(_currentServiceType)) {
      _serviceTypeCarts[_currentServiceType]!.clear();
    }
    
    // Fetch the order from the API
    final order = await _apiService.getOrderById(orderId);
    
    if (order != null) {
      // Track the current order ID
      _currentOrderId = orderId;
      
      // Convert order items to menu items and add to cart
      for (var item in order.items) {
        final menuItem = MenuItem(
          id: item.id.toString(),
          name: item.name,
          price: item.price,
          quantity: item.quantity,
          imageUrl: '', // No image info in order items
          category: '', // No category info in order items
          kitchenNote: item.kitchenNote,
        );
        
        // Add to cart without incrementing quantity (we already have the correct quantity)
        _addToCartWithoutIncrementing(menuItem);
      }
      
      // Update totals
      _updateTotals(_currentServiceType);
      notifyListeners();
      
      debugPrint('Loaded ${order.items.length} items from existing order #$orderId');
    }
  } catch (e) {
    debugPrint('Error loading existing order items: $e');
  }
}

// Add item to cart without incrementing quantity for existing items
void _addToCartWithoutIncrementing(MenuItem item) {
  if (_currentServiceType.isEmpty) {
    debugPrint('Warning: No service type selected');
    return;
  }
  
  // Initialize the cart for this service type if it doesn't exist
  if (!_serviceTypeCarts.containsKey(_currentServiceType)) {
    _serviceTypeCarts[_currentServiceType] = [];
  }
  
  // Don't check for existing items, just add directly
  _serviceTypeCarts[_currentServiceType]!.add(item);
}

}