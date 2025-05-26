import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/order_history.dart';
import '../services/api_service.dart';

class OrderHistoryProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<OrderHistory> _orders = [];
  List<OrderHistory> _filteredOrders = [];
  bool _isLoading = false;
  String _errorMessage = '';
  OrderTimeFilter _currentFilter = OrderTimeFilter.today; // Changed default to today
  String _searchQuery = '';
  String? _serviceTypeFilter;
  String? _statusFilter;
  
  // Getters
  List<OrderHistory> get orders => _filteredOrders;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  OrderTimeFilter get currentFilter => _currentFilter;
  String get searchQuery => _searchQuery;
  String? get serviceTypeFilter => _serviceTypeFilter;
  void setStatusFilter(String? status) {
    _statusFilter = status;
    _applyFilters();
    notifyListeners();
  }

  // Load all orders
  Future<void> loadOrders() async {
    _setLoading(true);
    
    try {
      // Clear any service type filter when loading all orders
      _serviceTypeFilter = null;
      
      final List<Order> apiOrders = await _apiService.getOrders();
      
      // Debug info about dates
      for (var order in apiOrders) {
        if (order.createdAt != null) {
          debugPrint('Raw order date from API: ${order.createdAt}');
          final parsedDate = DateTime.parse(order.createdAt!).toLocal();
          debugPrint('Parsed date in local time: $parsedDate');
        }
      }
      
      _orders = apiOrders.map((order) => OrderHistory.fromOrder(order)).toList();
      
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

  // Load orders for a specific service type
 Future<void> loadOrdersByServiceType(String serviceType) async {
  try {
    _isLoading = true;
    notifyListeners();
    
    final orders = await _apiService.getOrdersByServiceType(serviceType);
    _orders = orders.map((order) => OrderHistory.fromOrder(order)).toList();
    _errorMessage = '';
  } catch (e) {
    _errorMessage = e.toString();
    debugPrint('Error loading orders: $e');
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
  // Load orders for a specific table
  Future<void> loadOrdersByTable(String tableInfo) async {
    _setLoading(true);
    
    try {
      // Extract table number if needed
      String tableNumber = tableInfo;
      if (tableInfo.contains('Table ')) {
        tableNumber = tableInfo.split('Table ').last;
      }
      
      final List<Order> apiOrders = await _apiService.getOrdersByTable(tableInfo);
      _orders = apiOrders.map((order) => OrderHistory.fromOrder(order)).toList();
      
      // Sort by newest first
      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Apply current filters
      _applyFilters();
      
      debugPrint('Loaded ${_orders.length} orders for table $tableNumber');
    } catch (e) {
      _errorMessage = 'Failed to load table orders: $e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }
  
 // Search for an order by bill number
  Future<void> searchOrdersByBillNumber(String billNumber) async {
    if (billNumber.isEmpty) {
      _searchQuery = '';
      _applyFilters();
      return;
    }
    
    _setLoading(true);
    _searchQuery = billNumber;
    
    try {
      final List<Order> apiOrders = await _apiService.searchOrdersByBillNumber(billNumber);
      final searchResults = apiOrders.map((order) => OrderHistory.fromOrder(order)).toList();
      
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

  // Get an order by ID
  Future<OrderHistory?> getOrderDetails(int orderId) async {
    _setLoading(true);
    
    try {
      final Order? order = await _apiService.getOrderById(orderId);
      if (order != null) {
        return OrderHistory.fromOrder(order);
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
}