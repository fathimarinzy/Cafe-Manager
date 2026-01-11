import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/order_history.dart';
import '../repositories/local_order_repository.dart';

class OrderHistoryProvider with ChangeNotifier {
  List<OrderHistory> _orders = [];
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Filters
  bool _isCateringOnly = false;
  bool _excludeCatering = false; // New flag
  bool _isAdvancedOnly = false;
  String? _statusFilter = 'pending';
  OrderTimeFilter _timeFilter = OrderTimeFilter.today; // Changed to Enum

  String _billNumberQuery = '';
  String? _serviceTypeFilter; // New filter for generic service type

  final LocalOrderRepository _repository = LocalOrderRepository();

  // Getters
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isCateringOnly => _isCateringOnly;
  bool get excludeCatering => _excludeCatering;
  bool get isAdvancedOnly => _isAdvancedOnly;
  
  // NEW: Reset all filters to default state
  void resetFilters() {
    _isCateringOnly = false;
    _excludeCatering = false;
    _isAdvancedOnly = false;
    _statusFilter = null;
    _timeFilter = OrderTimeFilter.today;

    _billNumberQuery = '';
    _serviceTypeFilter = null; // Reset service type filter
    // Do not notify yet, caller will likely set specific filters and load
  }
  
  List<OrderHistory> get orders {
    List<OrderHistory> filtered = List.from(_orders);

    // 1. Status Filter
    if (_statusFilter != null && _statusFilter != 'all') {
      filtered = filtered.where((o) => o.status.toLowerCase() == _statusFilter!.toLowerCase()).toList();
    }

    // 2. Catering Filter - Exclusive or Inclusive
    if (_isCateringOnly) {
      filtered = filtered.where((o) => o.serviceType.toLowerCase().contains('catering')).toList();
    } else if (_excludeCatering) {
      filtered = filtered.where((o) => !o.serviceType.toLowerCase().contains('catering')).toList();
    }

    // 3. Advanced Filter
    if (_isAdvancedOnly) {
       filtered = filtered.where((o) => o.depositAmount != null && o.depositAmount! > 0).toList();
    }

    // 4. Time Filter - Using Enum extension
    // FIXED: Skip time filtering if we are in Advanced Mode (show all bookings)
    if (_timeFilter != OrderTimeFilter.all && !_isAdvancedOnly) {
       filtered = filtered.where((o) => _timeFilter.isInPeriod(o.createdAt)).toList();
    }

    // 5. Bill Number Search
    if (_billNumberQuery.isNotEmpty) {
      filtered = filtered.where((o) {
        return o.orderNumber.toString().contains(_billNumberQuery) ||
               (o.mainOrderNumber != null && o.mainOrderNumber.toString().contains(_billNumberQuery)) ||
               (o.tokenNumber != null && o.tokenNumber.toString().toLowerCase().contains(_billNumberQuery.toLowerCase())) ||
               (o.customerName != null && o.customerName!.toLowerCase().contains(_billNumberQuery.toLowerCase()));
      }).toList();

    }
    
    // 6. Generic Service Type Filter
    if (_serviceTypeFilter != null && _serviceTypeFilter!.isNotEmpty) {
      filtered = filtered.where((o) => o.serviceType.toLowerCase() == _serviceTypeFilter!.toLowerCase()).toList();
    }

    return filtered;
  }

  // Actions
  void setExcludeCatering(bool value) {
    _excludeCatering = value;
    // If excluding catering, ensure "isCateringOnly" is false to avoid conflict
    if (value) _isCateringOnly = false;
    notifyListeners();
  }
  
  void setCateringOnly(bool value) {
    _isCateringOnly = value;
    // If showing catering only, exclude flag must be false
    if (value) {
      _excludeCatering = false;
    } else {
      // If catering logic is disabled, also disable advanced/deposit filter
      _isAdvancedOnly = false;
    }
    notifyListeners();
  }

  // Helper to get date range for current filter
  (DateTime, DateTime)? _getDateRangeForFilter() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    switch (_timeFilter) {
      case OrderTimeFilter.today:
        return (todayStart, todayEnd);
      case OrderTimeFilter.weekly:
        // Start of week (Monday)
        final startOfWeek = todayStart.subtract(Duration(days: todayStart.weekday - 1));
        return (startOfWeek, todayEnd);
      case OrderTimeFilter.monthly:
        final startOfMonth = DateTime(now.year, now.month, 1);
        return (startOfMonth, todayEnd);
      case OrderTimeFilter.yearly:
        final startOfYear = DateTime(now.year, 1, 1);
        return (startOfYear, todayEnd);
      case OrderTimeFilter.all:
        return null;
    }
  }

  // Actions
  // Optimized loadOrders with DB filtering
  Future<void> loadOrders() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      List<Order> orderList;
      
      // OPTIMIZATION: Use specialized DB queries
      if (_isAdvancedOnly) {
         // 1. Advanced Mode: Fetch only orders with deposits, sorted by event date
         // This bypasses the time filter to show all upcoming bookings
         orderList = await _repository.getAdvancedOrders();
         
         // If we have a specific status to filter in DB, we could do it here too,
         // but status is simple enough to filter in memory for this smaller subset.
      } else if (_timeFilter != OrderTimeFilter.all && !_isCateringOnly && _statusFilter != 'all') {
         // 2. Normal Mode with Time Filter: Fetch only relevant date range
         // (Only apply if not in some complex mixed mode)
         final range = _getDateRangeForFilter();
         if (range != null) {
            // FIXED: Widen the search range by +/- 24 hours to account for timezone differences
            // between stored UTC strings and query Local strings.
            // The memory filter (isInPeriod) will ensure strict accuracy.
            final bufferStart = range.$1.subtract(const Duration(hours: 24));
            final bufferEnd = range.$2.add(const Duration(hours: 24));
            orderList = await _repository.getOrdersByDateRange(bufferStart, bufferEnd);
         } else {
            orderList = await _repository.getAllOrders();
         }
      } else {
         // 3. Fallback: Fetch all
         orderList = await _repository.getAllOrders();
      }

      // Convert Order to OrderHistory
      _orders = orderList.map((o) => OrderHistory.fromOrder(o)).toList();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error loading orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOrdersByServiceType(String serviceType) async {
     _serviceTypeFilter = serviceType;
     // When filtering by specific service type, we might want to relax other filters
     // or keep them. For now, we keeps them but ensure we re-load.
     await loadOrders();
  }
  
  // Added: Load orders for a specific table
  Future<void> loadOrdersByTable(String tableInfo) async {
    await loadOrders();
    // Filter to only show orders for this table
    _orders = _orders.where((o) => o.serviceType == tableInfo).toList();
    notifyListeners();
  }

  void searchOrdersByBillNumber(String val) {
    _billNumberQuery = val;
    notifyListeners();
  }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    notifyListeners();
  }

  // FIXED: Accept dynamic to handle both String (legacy) and OrderTimeFilter
  void setTimeFilter(dynamic filter) {
    if (filter is OrderTimeFilter) {
      _timeFilter = filter;
    } else if (filter is String) {
      // Basic mapping for legacy string calls
      switch (filter.toLowerCase()) {
        case 'today': _timeFilter = OrderTimeFilter.today; break;
        case 'week': _timeFilter = OrderTimeFilter.weekly; break;
        case 'month': _timeFilter = OrderTimeFilter.monthly; break;
        case 'year': _timeFilter = OrderTimeFilter.yearly; break;
        case 'all': _timeFilter = OrderTimeFilter.all; break;
        default: _timeFilter = OrderTimeFilter.today;
      }
    }
    // Optimization: Reload from DB when filter changes
    loadOrders();
  }

  void toggleCateringOnly() {
    _isCateringOnly = !_isCateringOnly;
    
    if (_isCateringOnly) {
       // Showing catering only -> enable catering, disable exclusion
       _excludeCatering = false;
    } else {
       // Not showing catering -> disable catering, ENABLE exclusion (hide catering from main list)
       _excludeCatering = true;
       // Also disable advanced filter
       _isAdvancedOnly = false;
    }
    loadOrders(); // Reload needed if logic changes fetching strategy
  }

  void toggleAdvancedOnly() {
    _isAdvancedOnly = !_isAdvancedOnly;
    // If enabling advanced, force catering only to be true (optional, but ensures consistency)
    if (_isAdvancedOnly) {
      _isCateringOnly = true;
    }
    // Optimization: Trigger reload to fetch advanced orders from DB
    loadOrders();
  }
  
  // Wrapper for refreshing data
  Future<void> refreshOrdersAndConnectivity() async {
    await loadOrders();
  }
  
  // Added: Get order details by ID
  Future<Order?> getOrderDetails(int orderId) async {
    try {
      return await _repository.getOrderById(orderId);
    } catch (e) {
      debugPrint('Error fetching order details: $e');
      return null;
    }
  }
  
  // Added: Update delivery details
  Future<bool> updateOrderDeliveryDetails(int orderId, String address, String boy, double charge) async {
    try {
      final order = await _repository.getOrderById(orderId);
      if (order != null) {
        final updatedOrder = order.copyWith(
          deliveryAddress: address,
          deliveryBoy: boy,
          deliveryCharge: charge,
        );
        await _repository.saveOrder(updatedOrder);
        
        // Update local list
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          _orders[index] = OrderHistory.fromOrder(updatedOrder);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating delivery details: $e');
      return false;
    }
  }
}