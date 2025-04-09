import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/person.dart';
import '../services/api_service.dart';
import '../services/bill_service.dart';

class OrderProvider with ChangeNotifier {
  // Map to store cart items for each service type or table
  // The key is the service type identifier (e.g., "Delivery", "Takeout", "Dining - Table 1")
  final Map<String, List<MenuItem>> _serviceTypeCarts = {};
  
  // Map to store totals for each service type
  final Map<String, Map<String, double>> _serviceTotals = {};
  
  String _currentServiceType = '';
  final ApiService _apiService = ApiService();
  
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

  // Set current service type and notify listeners
  void setCurrentServiceType(String serviceType) {
    _currentServiceType = serviceType;
    
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
      _serviceTypeCarts[_currentServiceType]![existingIndex].quantity += 1;
    } else {
      final newItem = MenuItem(
        id: item.id,
        name: item.name,
        price: item.price,
        imageUrl: item.imageUrl,
        category: item.category,
        isAvailable: item.isAvailable,
        quantity: 1,
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

  // Update totals for a specific service type
  void _updateTotals(String serviceType) {
    if (!_serviceTypeCarts.containsKey(serviceType)) return;

    final cartItems = _serviceTypeCarts[serviceType]!;
    final subtotal = cartItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    final tax = subtotal * 0.05;
    final discount = _serviceTotals[serviceType]?['discount'] ?? 0.0;
    final calculatedTotal = (subtotal + tax - discount).clamp(0.0, double.infinity);

    _serviceTotals[serviceType] = {
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': calculatedTotal,
    };
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

  // New method: Process order with bill generation
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
      if (_currentServiceType.startsWith('Dining - Table')) {
        tableInfo = _currentServiceType;
      }
      
      // Generate and process the bill
      final billResult = await BillService.processOrderBill(
        items: cartItems,
        serviceType: _currentServiceType,
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        total: total,
        personName: _selectedPerson?.name,
        tableInfo: tableInfo,
        context: context,
      );
      
      // Create the order in the database regardless of whether the bill was printed/saved
      final items = _serviceTypeCarts[_currentServiceType]!.map((item) => item.toJson()).toList();
      
      final order = await _apiService.createOrder(
        _currentServiceType,
        items,
        subtotal,
        tax,
        discount,
        total,
      );

      if (order != null) {
        // Clear the current service type's cart
        clearCart();
        
        return {
          'success': true,
          'message': billResult['message'],
          'order': order,
          'billPrinted': billResult['printed'],
          'billSaved': billResult['saved'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to create order in the system',
        };
      }
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
}