import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/order_item.dart'; 
import '../models/person.dart';
import '../models/table_model.dart';
import '../providers/table_provider.dart';
import '../services/api_service.dart';
import '../services/bill_service.dart';
import '../providers/settings_provider.dart';
import '../repositories/local_order_repository.dart';
import '../services/connectivity_service.dart';

class OrderProvider with ChangeNotifier {
  // Map to store cart items for each service type or table
  final Map<String, List<MenuItem>> _serviceTypeCarts = {};
  
  // Map to store totals for each service type
  final Map<String, Map<String, double>> _serviceTotals = {};
  
  String _currentServiceType = '';
  final ApiService _apiService = ApiService();
  final LocalOrderRepository _localOrderRepo = LocalOrderRepository();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  // Add this property to track current order ID
  int? _currentOrderId;

  // Offline mode tracking
  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;

  // Sync in progress flag
  bool _isSyncingOrders = false;
  bool get isSyncingOrders => _isSyncingOrders;

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

  // Constructor with connectivity check
  OrderProvider() {
    _initializeConnectivity();
  }

  // Initialize connectivity monitoring
  Future<void> _initializeConnectivity() async {
    // First load the saved connectivity status
    await _connectivityService.loadSavedConnectionStatus();
    
    // Then check current status
    _isOfflineMode = !await _connectivityService.checkConnection();
    
    // Listen for connectivity changes
    _connectivityService.connectivityStream.listen((isConnected) {
      final wasOffline = _isOfflineMode;
      _isOfflineMode = !isConnected;
      
      debugPrint('Connectivity changed: ${isConnected ? 'Online' : 'Offline'}, was offline: $wasOffline');
      notifyListeners();
      
      // If connection is restored, try to sync pending orders
      if (isConnected && wasOffline) {
        debugPrint('Connection restored, triggering sync');
        syncPendingOrders();
      }
    });
  }

  // Sync pending orders when online with better error handling and duplicate prevention
  Future<void> syncPendingOrders() async {
    if (_isOfflineMode || _isSyncingOrders) return;
    
    try {
      _isSyncingOrders = true;
      notifyListeners();
      
      // Get unsynced orders
      final unsyncedOrders = await _localOrderRepo.getUnsyncedOrders();
      debugPrint('Found ${unsyncedOrders.length} unsynced orders to sync');
      
      if (unsyncedOrders.isEmpty) {
        _isSyncingOrders = false;
        notifyListeners();
        return;
      }
      
      for (var order in unsyncedOrders) {
        try {
          // Skip if no ID
          if (order.id == null) continue;
          
          // Try to create order on server
          final serverOrder = await _apiService.createOrder(
            order.serviceType,
            order.items.map((item) => item.toJson()).toList(),
            order.subtotal,
            order.tax,
            order.discount,
            order.total,
            paymentMethod: order.paymentMethod ?? 'cash',
            customerId: order.customerId,
          );
          
          if (serverOrder != null) {
            // Mark local order as synced
            await _localOrderRepo.markOrderAsSynced(order.id!, serverOrder.id);
            debugPrint('Order synced successfully: Local ID ${order.id} -> Server ID ${serverOrder.id}');
          }
        } catch (e) {
          debugPrint('Error syncing order ${order.id}: $e');
          // Record the sync error
          await _localOrderRepo.recordSyncError(order.id!, e.toString());
        }
      }
    } catch (e) {
      debugPrint('Error syncing pending orders: $e');
    } finally {
      _isSyncingOrders = false;
      notifyListeners();
    }
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

  // Process order and handle online/offline scenarios
  // Updated processOrderWithBill method in lib/providers/order_provider.dart
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
    
    // Generate a timestamp for order creation
    final now = DateTime.now();
    
    // Format for consistent timestamp handling across online/offline
    String formattedTimestamp;
    if (_isOfflineMode) {
      // Use special format for offline orders so we can identify them later
       final timestamp = now.millisecondsSinceEpoch;
      formattedTimestamp = 'local_$timestamp';
    } else {
      // Use ISO format for online orders
      formattedTimestamp = now.toUtc().toIso8601String();    }
      
    // Create or update the order - handling both online and offline scenarios
    Order? order;
    Order? localOrder;
    int? serverOrderId;
    
    // Log the current state for debugging
    debugPrint('Processing order: currentOrderId=$_currentOrderId, isOfflineMode=$_isOfflineMode');
    
    if (_currentOrderId != null) {
      // Updating existing order - make sure to use the existing order ID
      final existingOrderId = _currentOrderId!;
      debugPrint('Updating existing order #$existingOrderId');
      
      final items = _serviceTypeCarts[_currentServiceType]!.map((item) => item.toJson()).toList();
      
      if (!_isOfflineMode) {
        // Online mode - update on server
        order = await _apiService.updateOrder(
          existingOrderId,
          _currentServiceType,
          items,
          subtotal,
          tax,
          discount,
          total,
        );
        
        // Also update in local database for redundancy
        if (order != null) {
          serverOrderId = order.id;
          
          // Convert cart items to OrderItem objects
          final orderItems = _serviceTypeCarts[_currentServiceType]!.map((item) => 
            OrderItem(
              id: int.tryParse(item.id) ?? 0,
              name: item.name,
              price: item.price,
              quantity: item.quantity,
              kitchenNote: item.kitchenNote,
            )
          ).toList();
          
          // Create an order object with the existing ID
          localOrder = Order(
            id: existingOrderId, // Use existing order ID
            serviceType: _currentServiceType,
            items: orderItems,
            subtotal: subtotal,
            tax: tax,
            discount: discount,
            total: total,
            status: 'pending',
            createdAt: formattedTimestamp,
            customerId: _selectedPerson?.id,
          );
          
          // Save to local storage with is_synced=1 since we just synced it
          try {
            localOrder = await _localOrderRepo.saveOrderAsSynced(localOrder, serverOrderId);
            debugPrint('Updated order in local database with synced status: ID=${localOrder.id}, ServerID=$serverOrderId');
          } catch (e) {
            debugPrint('Error saving synced order to local database: $e');
          }
        }
      } else {
        // Offline mode - update locally
        debugPrint('Updating order locally in offline mode, order ID: $existingOrderId');
        
        // Convert cart items to OrderItem objects
        final orderItems = _serviceTypeCarts[_currentServiceType]!.map((item) => 
          OrderItem(
            id: int.tryParse(item.id) ?? 0,
            name: item.name,
            price: item.price,
            quantity: item.quantity,
            kitchenNote: item.kitchenNote,
          )
        ).toList();
        
        // Create an order object with the EXISTING ID
        localOrder = Order(
          id: existingOrderId, // Critical: Use existing order ID
          serviceType: _currentServiceType,
          items: orderItems,
          subtotal: subtotal,
          tax: tax,
          discount: discount,
          total: total,
          status: 'pending',
          createdAt: formattedTimestamp,
          customerId: _selectedPerson?.id,
        );
        
        // Update the existing order in local storage
        localOrder = await _localOrderRepo.saveOrder(localOrder);
        order = localOrder; // Use local order as the main order
      }
    } else {
      // Create a new order
      debugPrint('Creating new order');
      final items = _serviceTypeCarts[_currentServiceType]!.map((item) => item.toJson()).toList();
      
      if (!_isOfflineMode) {
        // Online mode - create on server
        order = await _apiService.createOrder(
          _currentServiceType,
          items,
          subtotal,
          tax,
          discount,
          total,
          customerId: _selectedPerson?.id,
        );
        
        // IMPORTANT: Also save to local database for redundancy
        if (order != null) {
          serverOrderId = order.id;
          
          // Convert cart items to OrderItem objects
          final orderItems = _serviceTypeCarts[_currentServiceType]!.map((item) => 
            OrderItem(
              id: int.tryParse(item.id) ?? 0,
              name: item.name,
              price: item.price,
              quantity: item.quantity,
              kitchenNote: item.kitchenNote,
            )
          ).toList();
          
          // Create a local order with the server-generated ID
          localOrder = Order(
            id: serverOrderId, // Use server-generated ID
            serviceType: _currentServiceType,
            items: orderItems,
            subtotal: subtotal,
            tax: tax,
            discount: discount,
            total: total,
            status: 'pending',
            createdAt: formattedTimestamp,
            customerId: _selectedPerson?.id,
          );
          
          // Save to local storage with is_synced=1 since we just synced it
          try {
            localOrder = await _localOrderRepo.saveOrderAsSynced(localOrder, serverOrderId);
            debugPrint('Saved order to local database with synced status: ID=${localOrder.id}, ServerID=$serverOrderId');
          } catch (e) {
            debugPrint('Error saving synced order to local database: $e');
          }
        }
      } else {
        // Offline mode - save locally
        debugPrint('Creating new order locally in offline mode');
        
        // Convert cart items to OrderItem objects
        final orderItems = _serviceTypeCarts[_currentServiceType]!.map((item) => 
          OrderItem(
            id: int.tryParse(item.id) ?? 0,
            name: item.name,
            price: item.price,
            quantity: item.quantity,
            kitchenNote: item.kitchenNote,
          )
        ).toList();
        
        // Create a new local order
        localOrder = Order(
          serviceType: _currentServiceType,
          items: orderItems,
          subtotal: subtotal,
          tax: tax,
          discount: discount,
          total: total,
          status: 'pending',
          createdAt: formattedTimestamp,
          customerId: _selectedPerson?.id,
        );
        
        // Save to local storage
        localOrder = await _localOrderRepo.saveOrder(localOrder);
        order = localOrder; // Use local order as the main order
      }
    }
      
    if (order == null && localOrder == null) {
      return {
        'success': false,
        'message': 'Failed to create or update order in the system',
      };
    }
    
    // Use local order if online order failed
    if (order == null && localOrder != null) {
      order = localOrder;
    }
    
    // Now print the kitchen receipt with the order ID
    final String orderNumberPadded = order!.id.toString().padLeft(4, '0');
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
    
    // Display offline message if needed
    String successMessage = printResult['message'] ?? 'Order processed successfully';
    if (_isOfflineMode) {
      successMessage += ' (Offline mode - will sync when connection is restored)';
    }
    
    debugPrint('Order processed successfully: ID=${order.id}');
    
    return {
      'success': true,
      'message': successMessage,
      'order': order,
      'billPrinted': printResult['printed'] ?? false,
      'billSaved': printResult['saved'] ?? false,
      'offlineMode': _isOfflineMode,
    };
  } catch (error) {
    debugPrint('Error processing order: $error');
    return {
      'success': false,
      'message': 'Error processing order: $error',
    };
  }
}
  
  // Get all orders (both online and offline)
  Future<List<Order>> fetchOrders() async {
    List<Order> orders = [];
    
    try {
      if (!_isOfflineMode) {
        // Online mode - get from server
        orders = await _apiService.getOrders();
      }
      
      // Always get local orders and merge (avoid duplicates by ID)
      final localOrders = await _localOrderRepo.getAllOrders();
      
      // Create a map of server orders by ID
      final Map<int, bool> serverOrderIds = {};
      for (var order in orders) {
        if (order.id != null) {
          serverOrderIds[order.id!] = true;
        }
      }
      
      // Add local orders that aren't in server orders
      for (var localOrder in localOrders) {
        if (localOrder.id != null && !serverOrderIds.containsKey(localOrder.id)) {
          orders.add(localOrder);
        }
      }
      
      return orders;
    } catch (error) {
      debugPrint('Error fetching orders: $error');
      
      // If server fetch fails, return local orders
      return await _localOrderRepo.getAllOrders();
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
      
      Order? order;
      
      if (!_isOfflineMode) {
        // Online mode - update on server
        order = await _apiService.updateOrder(
          orderId,
          _currentServiceType,
          items,
          subtotal,
          tax,
          discount,
          total,
        );
      } else {
        // Offline mode - save locally
        // For simplicity, we're creating a new local order
        order = await _localOrderRepo.saveOrder(
          Order(
            id: orderId,
            serviceType: _currentServiceType,
            items: _serviceTypeCarts[_currentServiceType]!.map((item) => 
              OrderItem(
                id: int.tryParse(item.id) ?? 0,
                name: item.name,
                price: item.price,
                quantity: item.quantity,
                kitchenNote: item.kitchenNote,
              )
            ).toList(),
            subtotal: subtotal,
            tax: tax,
            discount: discount,
            total: total,
            status: 'pending',
            createdAt: DateTime.now().toIso8601String(),
            customerId: _selectedPerson?.id,
          )
        );
      }

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

  // Load items from an existing order into the cart
Future<void> loadExistingOrderItems(int orderId) async {
  try {
    // First clear the current cart to avoid duplicates
    if (_serviceTypeCarts.containsKey(_currentServiceType)) {
      _serviceTypeCarts[_currentServiceType]!.clear();
    }
    
    Order? order;
    
    // Check if we're in offline mode
    if (!_isOfflineMode) {
      // Online mode - fetch from server
      try {
        order = await _apiService.getOrderById(orderId);
        debugPrint('Loaded order #$orderId from API: ${order?.serviceType}');
      } catch (e) {
        debugPrint('Error loading order from API, will try local storage: $e');
      }
    }
    
    // Always check local storage regardless of online/offline status or API result
    if (order == null || order.serviceType.isEmpty) {
      final localOrders = await _localOrderRepo.getAllOrders();
      debugPrint('Checking ${localOrders.length} local orders for ID: $orderId');
      
      // Debug log all local orders to help with troubleshooting
      for (var localOrder in localOrders) {
        debugPrint('Local order: ID=${localOrder.id}, Type=${localOrder.serviceType}');
      }
      
      // Find the order with matching ID
      order = localOrders.firstWhere(
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
    }
    
    if (order != null && order.serviceType.isNotEmpty) {
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
      debugPrint('Failed to load order #$orderId: Not found in API or local storage');
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
  
  // Check connection status and attempt to sync
  Future<void> checkConnectionAndSync() async {
    final isOnline = await _connectivityService.checkConnection();
    
    if (isOnline && _isOfflineMode) {
      // We just went online, update state and sync
      _isOfflineMode = false;
      notifyListeners();
      await syncPendingOrders();
    } else if (!isOnline && !_isOfflineMode) {
      // We just went offline, update state
      _isOfflineMode = true;
      notifyListeners();
    }
  }
  
  // Place order (legacy method kept for compatibility)
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
      
      Order? order;
      
      if (!_isOfflineMode) {
        // Online mode - create on server
        order = await _apiService.createOrder(
          serviceType,
          items,
          subtotal,
          tax,
          discount,
          total,
        );
      } else {
        // Offline mode - save locally
        order = await _localOrderRepo.saveOrder(
          Order(
            serviceType: serviceType,
            items: _serviceTypeCarts[_currentServiceType]!.map((item) => 
              OrderItem(
                id: int.tryParse(item.id) ?? 0,
                name: item.name,
                price: item.price,
                quantity: item.quantity,
                kitchenNote: item.kitchenNote,
              )
            ).toList(),
            subtotal: subtotal,
            tax: tax,
            discount: discount,
            total: total,
            status: 'pending',
            createdAt: DateTime.now().toIso8601String(),
            customerId: _selectedPerson?.id,
          )
        );
      }

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
}