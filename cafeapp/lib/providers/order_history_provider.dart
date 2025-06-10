import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/order_history.dart';
import '../services/api_service.dart';
import '../repositories/local_order_repository.dart';
import '../services/connectivity_service.dart';

class OrderHistoryProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocalOrderRepository _localOrderRepo = LocalOrderRepository();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  List<OrderHistory> _orders = [];
  List<OrderHistory> _filteredOrders = [];
  bool _isLoading = false;
  String _errorMessage = '';
  OrderTimeFilter _currentFilter = OrderTimeFilter.today;
  String _searchQuery = '';
  String? _serviceTypeFilter;
  String? _statusFilter;
  bool _isOfflineMode = false;
  
  // Getters
  List<OrderHistory> get orders => _filteredOrders;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  OrderTimeFilter get currentFilter => _currentFilter;
  String get searchQuery => _searchQuery;
  String? get serviceTypeFilter => _serviceTypeFilter;
  bool get isOfflineMode => _isOfflineMode;
  
  // Constructor with offline mode initialization
  OrderHistoryProvider() {
    _initConnectivity();
  }
  
  void _initConnectivity() async {
    _isOfflineMode = !await _connectivityService.checkConnection();
    
    // Listen for connectivity changes
    _connectivityService.connectivityStream.listen((isConnected) {
      final wasOffline = _isOfflineMode;
      _isOfflineMode = !isConnected;
      
      if (wasOffline && !_isOfflineMode) {
        // We just came back online, refresh orders
        loadOrders();
      }
      
      notifyListeners();
    });
  }
  
  void setStatusFilter(String? status) {
    _statusFilter = status;
    _applyFilters();
    notifyListeners();
  }

  // Load all orders - updated to handle offline mode
  Future<void> loadOrders() async {
    _setLoading(true);
    
    try {
      // Clear any service type filter when loading all orders
      _serviceTypeFilter = null;
      
      List<Order> apiOrders = [];
      List<Order> localOrders = [];
      
      // Get orders from API if online
      if (!_isOfflineMode) {
        try {
          apiOrders = await _apiService.getOrders();
          debugPrint('Loaded ${apiOrders.length} orders from API');
        } catch (e) {
          debugPrint('Error loading orders from API: $e');
          // Continue with local orders if API fails
        }
      }
      
      // Always get local orders
      try {
        localOrders = await _localOrderRepo.getAllOrders();
        debugPrint('Loaded ${localOrders.length} orders from local database');
      } catch (e) {
        debugPrint('Error loading orders from local database: $e');
      }
      
      // Merge orders from both sources, avoiding duplicates
      final Map<int, bool> apiOrderIds = {};
      for (var order in apiOrders) {
        if (order.id != null) {
          apiOrderIds[order.id!] = true;
        }
      }
      
      // Combine the lists, adding local orders that aren't in API orders
      List<Order> combinedOrders = [...apiOrders];
      for (var localOrder in localOrders) {
        if (localOrder.id != null && !apiOrderIds.containsKey(localOrder.id)) {
          combinedOrders.add(localOrder);
        }
      }
      
      // Convert to OrderHistory objects
      _orders = combinedOrders.map((order) => OrderHistory.fromOrder(order)).toList();
      
      // Debug info about dates
      for (var order in _orders) {
        debugPrint('Order ID: ${order.id}, Date: ${order.formattedDate}, Time: ${order.formattedTime}');
      }
      
      // Sort by newest first
      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Apply current filters
      _applyFilters();
    } catch (e) {
      _errorMessage = 'Failed to load orders: $e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Load orders for a specific service type - updated for offline support
  Future<void> loadOrdersByServiceType(String serviceType) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      List<Order> apiOrders = [];
      List<Order> localOrders = [];
      
      // Get orders from API if online
      if (!_isOfflineMode) {
        try {
          apiOrders = await _apiService.getOrdersByServiceType(serviceType);
        } catch (e) {
          debugPrint('Error loading orders from API by service type: $e');
        }
      }
      
      // Always get local orders
      try {
        final allLocalOrders = await _localOrderRepo.getAllOrders();
        // Filter by service type
        localOrders = allLocalOrders.where((order) => 
          order.serviceType == serviceType
        ).toList();
      } catch (e) {
        debugPrint('Error loading orders from local database: $e');
      }
      
      // Merge orders from both sources, avoiding duplicates
      final Map<int, bool> apiOrderIds = {};
      for (var order in apiOrders) {
        if (order.id != null) {
          apiOrderIds[order.id!] = true;
        }
      }
      
      // Combine the lists, adding local orders that aren't in API orders
      List<Order> combinedOrders = [...apiOrders];
      for (var localOrder in localOrders) {
        if (localOrder.id != null && !apiOrderIds.containsKey(localOrder.id)) {
          combinedOrders.add(localOrder);
        }
      }
      
      _orders = combinedOrders.map((order) => OrderHistory.fromOrder(order)).toList();
      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _applyFilters();
      _errorMessage = '';
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error loading orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load orders for a specific table - updated for offline support
Future<void> loadOrdersByTable(String tableInfo) async {
  _setLoading(true);
  
  try {
    // Extract table number if needed
    String tableNumber = tableInfo;
    if (tableInfo.contains('Table ')) {
      tableNumber = tableInfo.split('Table ').last;
    }
    
    List<Order> apiOrders = [];
    List<Order> localOrders = [];
    
    // Get orders from API if online
    if (!_isOfflineMode) {
      try {
        apiOrders = await _apiService.getOrdersByTable(tableInfo);
        debugPrint('Loaded ${apiOrders.length} orders from API for table $tableNumber');
      } catch (e) {
        debugPrint('Error loading table orders from API: $e');
      }
    }
    
    // Always get local orders
    try {
      final allLocalOrders = await _localOrderRepo.getAllOrders();
      // Filter by table info
      localOrders = allLocalOrders.where((order) => 
        order.serviceType.contains('Table $tableNumber')
      ).toList();
      debugPrint('Loaded ${localOrders.length} orders from local database for table $tableNumber');
      
      // Log all local orders to help with debugging
      for (var order in localOrders) {
        debugPrint('Local order: ID=${order.id}, Status=${order.status}, ServiceType=${order.serviceType}');
      }
    } catch (e) {
      debugPrint('Error loading table orders from local database: $e');
    }
    
    // Merge orders from both sources, avoiding duplicates
    final Map<int, bool> apiOrderIds = {};
    for (var order in apiOrders) {
      if (order.id != null) {
        apiOrderIds[order.id!] = true;
      }
    }
    
    // Combine the lists, adding local orders that aren't in API orders
    List<Order> combinedOrders = [...apiOrders];
    for (var localOrder in localOrders) {
      if (localOrder.id != null && !apiOrderIds.containsKey(localOrder.id)) {
        combinedOrders.add(localOrder);
      }
    }
    
    _orders = combinedOrders.map((order) => OrderHistory.fromOrder(order)).toList();
    
    // Sort by newest first
    _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Apply current filters
    _applyFilters();
    
    debugPrint('Combined ${_orders.length} orders for table $tableNumber');
  } catch (e) {
    _errorMessage = 'Failed to load table orders: $e';
    debugPrint(_errorMessage);
  } finally {
    _setLoading(false);
  }
}
 
  
  // Search for an order by bill number - updated for offline support
  Future<void> searchOrdersByBillNumber(String billNumber) async {
    if (billNumber.isEmpty) {
      _searchQuery = '';
      _applyFilters();
      return;
    }
    
    _setLoading(true);
    _searchQuery = billNumber;
    
    try {
      List<Order> apiOrders = [];
      List<Order> localOrders = [];
      
      // Get orders from API if online
      if (!_isOfflineMode) {
        try {
          apiOrders = await _apiService.searchOrdersByBillNumber(billNumber);
        } catch (e) {
          debugPrint('Error searching orders from API: $e');
        }
      }
      
      // Search local orders
      try {
        final allLocalOrders = await _localOrderRepo.getAllOrders();
        // Filter by bill number (order ID)
        localOrders = allLocalOrders.where((order) => 
          order.id.toString().contains(billNumber)
        ).toList();
      } catch (e) {
        debugPrint('Error searching local orders: $e');
      }
      
      // Merge orders from both sources, avoiding duplicates
      final Map<int, bool> apiOrderIds = {};
      for (var order in apiOrders) {
        if (order.id != null) {
          apiOrderIds[order.id!] = true;
        }
      }
      
      // Combine the lists, adding local orders that aren't in API orders
      List<Order> combinedOrders = [...apiOrders];
      for (var localOrder in localOrders) {
        if (localOrder.id != null && !apiOrderIds.containsKey(localOrder.id)) {
          combinedOrders.add(localOrder);
        }
      }
      
      final searchResults = combinedOrders.map((order) => OrderHistory.fromOrder(order)).toList();
      
      // Update filtered orders directly for search
      _filteredOrders = searchResults;
    } catch (e) {
      _errorMessage = 'Failed to search orders: $e';
      debugPrint(_errorMessage);
      // If search fails, just filter the existing orders
      _applyFilters();
    } finally {
      _setLoading(false);
    }
  }

  // Set the time filter
  void setTimeFilter(OrderTimeFilter filter) {
    _currentFilter = filter;
    _applyFilters();
  }
  
  // Set the service type filter
  void setServiceTypeFilter(String? serviceType) {
    _serviceTypeFilter = serviceType;
    loadOrders();
  }

  // Clear all filters
  void clearFilters() {
    _currentFilter = OrderTimeFilter.all;
    _searchQuery = '';
    _serviceTypeFilter = null;
    _statusFilter = null;
    _applyFilters();
  }

  // Update the _applyFilters method to include status filtering
  void _applyFilters() {
    if (_searchQuery.isNotEmpty) {
      // Search takes precedence over other filters
      _filteredOrders = _orders.where((order) => 
        order.orderNumber.contains(_searchQuery) ||
        order.serviceType.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    } else {
      // Apply time filter
      _filteredOrders = _orders.where((order) => 
        _currentFilter.isInPeriod(order.createdAt)
      ).toList();
      
      // Apply service type filter if set
      if (_serviceTypeFilter != null && _serviceTypeFilter!.isNotEmpty) {
        _filteredOrders = _filteredOrders.where((order) => 
          order.serviceType == _serviceTypeFilter
        ).toList();
      }
      
      // Apply status filter if set
      if (_statusFilter != null && _statusFilter!.isNotEmpty) {
        _filteredOrders = _filteredOrders.where((order) => 
          order.status.toLowerCase() == _statusFilter!.toLowerCase()
        ).toList();
      }
      
      // Log results
      debugPrint('Applied filters, found ${_filteredOrders.length} orders');
    }
    
    notifyListeners();
  }

  // Get an order by ID - updated for offline support
  Future<OrderHistory?> getOrderDetails(int orderId) async {
    _setLoading(true);
    
    try {
      // Try to get from API if online
      if (!_isOfflineMode) {
        try {
          final Order? apiOrder = await _apiService.getOrderById(orderId);
          if (apiOrder != null) {
            return OrderHistory.fromOrder(apiOrder);
          }
        } catch (e) {
          debugPrint('Error getting order details from API: $e');
        }
      }
      
      // Try to get from local database
      final localOrders = await _localOrderRepo.getAllOrders();
      final localOrder = localOrders.firstWhere(
        (order) => order.id == orderId,
        orElse: () => Order(
          serviceType: '',
          items: [],
          subtotal: 0,
          tax: 0,
          discount: 0,
          total: 0
        )
      );
      
      if (localOrder.serviceType.isNotEmpty) {
        return OrderHistory.fromOrder(localOrder);
      }
      
      return null;
    } catch (e) {
      _errorMessage = 'Failed to get order details: $e';
      debugPrint(_errorMessage);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Helper to set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _errorMessage = '';
    }
    notifyListeners();
  }
  
  // Force a refresh of the connectivity status and orders
  Future<void> refreshOrdersAndConnectivity() async {
    final isConnected = await _connectivityService.checkConnection();
    final wasOffline = _isOfflineMode;
    _isOfflineMode = !isConnected;
    
    if (wasOffline != _isOfflineMode) {
      notifyListeners();
    }
    
    loadOrders();
  }
}