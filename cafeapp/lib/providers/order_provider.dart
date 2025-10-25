// lib/providers/order_provider.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/order_item.dart'; 
import '../models/person.dart';
import '../models/table_model.dart';
import '../providers/table_provider.dart';
import '../services/bill_service.dart';
import '../providers/settings_provider.dart';
import '../repositories/local_order_repository.dart';

class OrderProvider with ChangeNotifier {
  // Map to store cart items for each service type or table
  final Map<String, List<MenuItem>> _serviceTypeCarts = {};
  
  // Map to store totals for each service type
  final Map<String, Map<String, double>> _serviceTotals = {};
  
  String _currentServiceType = '';
  final LocalOrderRepository _localOrderRepo = LocalOrderRepository();
  
  // Add this property to track current order ID
  int? _currentOrderId;

  // Getter and setter for current order ID
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

  // Constructor
  // OrderProvider() {}

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
  // Add this getter after the existing getters (around line 70-100)
Future<List<Order>> get orders async {
  try {
    return await _localOrderRepo.getAllOrders();
  } catch (error) {
    debugPrint('Error fetching orders: $error');
    return [];
  }
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
    
    // Get the existing item
    final existingItem = _serviceTypeCarts[_currentServiceType]![existingIndex];
    
    // Remove the item from its current position
    _serviceTypeCarts[_currentServiceType]!.removeAt(existingIndex);
    
    // Create updated item with incremented quantity
    final updatedItem = MenuItem(
      id: item.id,
      name: item.name,
      price: item.price,
      imageUrl: item.imageUrl,
      category: item.category,
      isAvailable: item.isAvailable,
      quantity: existingItem.quantity + 1, // Increment quantity
      kitchenNote: noteToUse,
      taxExempt: item.taxExempt,
    );
    
    // Insert the updated item at the beginning of the list
    _serviceTypeCarts[_currentServiceType]!.insert(0, updatedItem);
  } else {
    // If it's a new item, add it to the beginning of the list
    final newItem = MenuItem(
      id: item.id,
      name: item.name,
      price: item.price,
      imageUrl: item.imageUrl,
      category: item.category,
      isAvailable: item.isAvailable,
      quantity: 1,
      kitchenNote: item.kitchenNote,
      taxExempt: item.taxExempt,
    );
    _serviceTypeCarts[_currentServiceType]!.insert(0, newItem);
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
  
  // Separate taxable and tax-exempt items
  double taxableTotal = 0.0;
  double taxExemptTotal = 0.0;
  
  for (var item in cartItems) {
    final itemTotal = item.price * item.quantity;
    if (item.taxExempt) {
      taxExemptTotal += itemTotal;
    } else {
      taxableTotal += itemTotal;
    }
  }
  
  // Get tax rate and VAT type from SettingsProvider
  final BuildContext? context = _context;
  double taxRate = 0.0;
  bool isVatInclusive = false;
  
  if (context != null && context.mounted) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    taxRate = settingsProvider.taxRate;
    isVatInclusive = settingsProvider.isVatInclusive;
  }
  
  double subtotal;
  double tax;
  double total;
  
  if (isVatInclusive) {
    // Inclusive VAT: tax is already in the price for taxable items
    // Extract tax only from taxable items
    final taxableAmount = taxableTotal / (1 + (taxRate / 100));
    tax = taxableTotal - taxableAmount;
    subtotal = taxableAmount + taxExemptTotal;
    total = taxableTotal + taxExemptTotal;
  } else {
    // Exclusive VAT: add tax on top of taxable items only
    subtotal = taxableTotal + taxExemptTotal;
    tax = taxableTotal * (taxRate / 100);
    total = subtotal + tax;
  }
  
  final discount = _serviceTotals[serviceType]?['discount'] ?? 0.0;

  _serviceTotals[serviceType] = {
    'subtotal': subtotal,
    'tax': tax,
    'discount': discount,
    'total': total - discount,
  };
  
  debugPrint('Order totals updated - Taxable: $taxableTotal, Tax-Exempt: $taxExemptTotal, Tax: $tax, Total: $total');
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

  // Process order and save locally with printing
  Future<Map<String, dynamic>> processOrderWithBill(BuildContext context) async {
    // First check if we have items in the cart
    if (_currentServiceType.isEmpty || cartItems.isEmpty) {
      return {
        'success': false,
        'message': 'No items in cart',
      };
    }

    try {
      // Get settings for VAT calculation
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // Calculate totals based on VAT type
      final itemPricesSum = cartItems.fold(
        0.0, 
        (sum, item) => sum + (item.price * item.quantity)
      );
      
      double calculatedSubtotal;
      double calculatedTax;
      double calculatedTotal;
      
      if (settingsProvider.isVatInclusive) {
        // Inclusive VAT: item prices already include tax
        calculatedTotal = itemPricesSum - discount;
        calculatedTax = calculatedTotal - (calculatedTotal / (1 + (settingsProvider.taxRate / 100)));
        calculatedSubtotal = calculatedTotal - calculatedTax;
      } else {
        // Exclusive VAT: add tax on top
        calculatedSubtotal = itemPricesSum - discount;
        calculatedTax = calculatedSubtotal * (settingsProvider.taxRate / 100);
        calculatedTotal = calculatedSubtotal + calculatedTax;
      }
      
      // Extract table number from service type if this is a dining order
      String? tableInfo;
      int? tableNumber;
      
      if (_currentServiceType.startsWith('Dining - Table')) {
        tableInfo = _currentServiceType;
        final tableNumberMatch = RegExp(r'Table (\d+)').firstMatch(_currentServiceType);
        if (tableNumberMatch != null && tableNumberMatch.groupCount >= 1) {
          tableNumber = int.tryParse(tableNumberMatch.group(1)!);
        }
      }
      
      final formattedTimestamp = DateTime.now().toLocal().toIso8601String();
      Order? localOrder;
      
      debugPrint('Processing order: currentOrderId=$_currentOrderId');
      debugPrint('Order timestamp: $formattedTimestamp');
      debugPrint('VAT Inclusive: ${settingsProvider.isVatInclusive}, Subtotal: $calculatedSubtotal, Tax: $calculatedTax, Total: $calculatedTotal');
      
      if (_currentOrderId != null) {
        // Updating existing order
        final existingOrderId = _currentOrderId!;
        debugPrint('Updating existing order #$existingOrderId');
        
        final orderItems = _serviceTypeCarts[_currentServiceType]!.map((item) => 
          OrderItem(
            id: int.tryParse(item.id) ?? 0,
            name: item.name,
            price: item.price,
            quantity: item.quantity,
            kitchenNote: item.kitchenNote,
            taxExempt: item.taxExempt, // FIX: Copy taxExempt from MenuItem
          )
        ).toList();
        
        localOrder = Order(
          id: existingOrderId,
          serviceType: _currentServiceType,
          items: orderItems,
          subtotal: calculatedSubtotal,
          tax: calculatedTax,
          discount: discount,
          total: calculatedTotal,
          status: 'pending',
          createdAt: formattedTimestamp,
          customerId: _selectedPerson?.id,
          paymentMethod: 'cash',
        );
        
        localOrder = await _localOrderRepo.saveOrder(localOrder);
        debugPrint('Updated order in local database: ID=${localOrder.id}');
      } else {
        // Create a new order
        debugPrint('Creating new order');
        
        final orderItems = _serviceTypeCarts[_currentServiceType]!.map((item) => 
          OrderItem(
            id: int.tryParse(item.id) ?? 0,
            name: item.name,
            price: item.price,
            quantity: item.quantity,
            kitchenNote: item.kitchenNote,
            taxExempt: item.taxExempt, // FIX: Copy taxExempt from MenuItem
          )
        ).toList();
        
        localOrder = Order(
          serviceType: _currentServiceType,
          items: orderItems,
          subtotal: calculatedSubtotal,
          tax: calculatedTax,
          discount: discount,
          total: calculatedTotal,
          status: 'pending',
          createdAt: formattedTimestamp,
          customerId: _selectedPerson?.id,
          paymentMethod: 'cash',
        );
        
        localOrder = await _localOrderRepo.saveOrder(localOrder);
        debugPrint('Created new order in local database: ID=${localOrder.id}');
      }
      
      final isContextMounted = context.mounted;
      
      final String orderNumberPadded = localOrder.id.toString().padLeft(4, '0');
      Map<String, dynamic> printResult = await BillService.printKitchenOrderReceipt(
        items: cartItems,
        serviceType: _currentServiceType,
        tableInfo: tableInfo,
        orderNumber: orderNumberPadded,
        context: isContextMounted ? context : null,
      );
      
      // Update table status if needed
      if (tableNumber != null && isContextMounted && context.mounted) {
        final tableProvider = Provider.of<TableProvider>(context, listen: false);
        final nonNullTableNumber = tableNumber;
        
        final table = tableProvider.tables.firstWhere(
          (t) => t.number == nonNullTableNumber,
          orElse: () => TableModel(id: '', number: nonNullTableNumber, isOccupied: false)
        );
        
        if (table.id.isNotEmpty) {
          final updatedTable = TableModel(
            id: table.id,
            number: table.number,
            isOccupied: true,
            capacity: table.capacity,
            note: table.note,
          );
          
          await tableProvider.updateTable(updatedTable);
          debugPrint('Table ${nonNullTableNumber.toString()} status updated to occupied');
        } else {
          await tableProvider.setTableStatus(nonNullTableNumber, true);
          debugPrint('Table ${nonNullTableNumber.toString()} status set to occupied by number');
        }
      }

      // Clear the current service type's cart
      clearCart();
      // Reset the current order ID
      _currentOrderId = null;
      
      return {
        'success': true,
        'message': printResult['message'] ?? 'Order processed successfully',
        'order': localOrder,
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
  
  // Get all orders from local repository
  Future<List<Order>> fetchOrders() async {
    try {
      return await _localOrderRepo.getAllOrders();
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
        taxExempt: item.taxExempt,
      );
      
      // Replace the item in the cart
      _serviceTypeCarts[_currentServiceType]![itemIndex] = updatedItem;
      
      notifyListeners();
      debugPrint('Updated kitchen note for item $id: $note');
    }
  }

  // Load items from an existing order into the cart
  Future<void> loadExistingOrderItems(int orderId) async {
    try {
      // First clear the current cart to avoid duplicates
      if (_serviceTypeCarts.containsKey(_currentServiceType)) {
        _serviceTypeCarts[_currentServiceType]!.clear();
      }
      
      // Get the order from local storage
      final localOrders = await _localOrderRepo.getAllOrders();
      debugPrint('Checking ${localOrders.length} local orders for ID: $orderId');
      
      // Debug log all local orders to help with troubleshooting
      for (var localOrder in localOrders) {
        debugPrint('Local order: ID=${localOrder.id}, Type=${localOrder.serviceType}');
      }
      
      // Find the order with matching ID
      final order = localOrders.firstWhere(
        (o) => o.id == orderId,
        orElse: () => Order(
          serviceType: '',
          items: [],
          subtotal: 0,
          tax: 0,
          discount: 0,
          total: 0
        )
      );
      
      debugPrint('Local order lookup result: ${order.serviceType.isNotEmpty ? "Found" : "Not found"}');
      
      if (order.serviceType.isNotEmpty) {
        // Track the current order ID
        _currentOrderId = orderId;
        
        // Convert order items to menu items and add to cart
        for (var item in order.items) {
          final menuItem = MenuItem(
            id: item.id.toString(),
            name: item.name,
            price: item.price,
            imageUrl: '', // No image info in order items
            category: '', // No category info in order items
            quantity: item.quantity,
            kitchenNote: item.kitchenNote,
          );
          
          // Add to cart without incrementing quantity (we already have the correct quantity)
          _addToCartWithoutIncrementing(menuItem);
        }
        
        // Update totals
        _updateTotals(_currentServiceType);
        notifyListeners();
        
        debugPrint('Loaded ${order.items.length} items from existing order #$orderId');
      } else {
        debugPrint('Failed to load order #$orderId: Not found in local storage');
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
    
    // Add the item to the beginning of the list (for consistency with addToCart)
  _serviceTypeCarts[_currentServiceType]!.insert(0, item);
  }
  
  // Update payment method for an order
  Future<bool> updateOrderPaymentMethod(int orderId, String paymentMethod) async {
    try {
      // Get the order from local storage
      final localOrders = await _localOrderRepo.getAllOrders();
      
      // Find the order with matching ID
      final orderIndex = localOrders.indexWhere((o) => o.id == orderId);
      
      if (orderIndex >= 0) {
        final order = localOrders[orderIndex];
        
        // Create a new order with updated payment method
        final updatedOrder = Order(
          id: order.id,
          serviceType: order.serviceType,
          items: order.items,
          subtotal: order.subtotal,
          tax: order.tax,
          discount: order.discount,
          total: order.total,
          status: order.status,
          createdAt: order.createdAt,
          customerId: order.customerId,
          paymentMethod: paymentMethod,
        );
        
        // Save the updated order
        await _localOrderRepo.saveOrder(updatedOrder);
        debugPrint('Updated payment method for order #$orderId to $paymentMethod');
        return true;
      } else {
        debugPrint('Cannot update payment method: Order not found');
        return false;
      }
    } catch (e) {
      debugPrint('Error updating payment method: $e');
      return false;
    }
  }
}