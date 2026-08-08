import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/order_history.dart';
import '../repositories/local_order_repository.dart';
import '../repositories/order_query_filters.dart';
import '../utils/logger.dart';
import '../utils/payment_trace.dart';

// Which repository query loadOrders()/loadMoreOrders() should use, based on
// the active filter combination. Kept as a single source of truth so the two
// methods can't drift out of sync with each other.
enum _FetchMode { advanced, dateRange, unbounded }

class OrderHistoryProvider with ChangeNotifier {
  List<OrderHistory> _orders = [];
  bool _isLoading = false;
  String _errorMessage = '';

  // Pagination (only meaningful in the unbounded "all orders" fetch mode -
  // see _resolveFetchMode). Bumps _ordersVersion whenever _orders changes so
  // the memoized `orders` getter below knows to recompute.
  static const int _pageSize = 200;
  int _pageOffset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _ordersVersion = 0;

  // Filters
  bool _isCateringOnly = false;
  bool _excludeCatering = false; // New flag
  bool _isAdvancedOnly = false;
  String? _statusFilter = 'pending';
  OrderTimeFilter _timeFilter = OrderTimeFilter.today; // Changed to Enum

  String _billNumberQuery = '';
  String? _serviceTypeFilter; // New filter for generic service type

  final LocalOrderRepository _repository;

  /// [repository] is injectable so the search debounce and its stale-result
  /// guard can be tested without a database.
  OrderHistoryProvider({LocalOrderRepository? repository})
      : _repository = repository ?? LocalOrderRepository();

  // Getters
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isCateringOnly => _isCateringOnly;
  bool get excludeCatering => _excludeCatering;
  bool get isAdvancedOnly => _isAdvancedOnly;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  // True once the user has scrolled past the first page in unbounded ("All
  // Orders") mode - used by the screen to skip its periodic auto-refresh
  // there, since reloading would reset pagination and snap the list back to
  // the top.
  bool get hasLoadedMultiplePages => _pageOffset > _pageSize;
  
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
  
  /// The filters that can be decided in SQL, as the repository wants them.
  ///
  /// The time filter is absent on purpose - `created_at` is a mixed-format
  /// column, so date narrowing stays in Dart behind the ±24h buffer. See
  /// OrderQueryFilters.
  OrderQueryFilters get _sqlFilters => OrderQueryFilters(
        status: _statusFilter,
        cateringOnly: _isCateringOnly,
        excludeCatering: _excludeCatering,
        advancedOnly: _isAdvancedOnly,
        serviceType: _serviceTypeFilter,
      );

  /// How long to wait before refetching after a filter changes.
  ///
  /// Screen init sets several filters in a row (resetFilters, setTimeFilter,
  /// setExcludeCatering), and each one now needs a refetch because filtering
  /// happens in SQL. Coalescing turns that burst into one query.
  @visibleForTesting
  static Duration filterReloadDebounce = const Duration(milliseconds: 50);

  Timer? _reloadDebounceTimer;

  /// Refetch because a filter changed, coalescing bursts into one query.
  ///
  /// Necessary now that filters run in SQL: the getter can only narrow what was
  /// fetched, so widening a filter without refetching would show too few
  /// orders. Before this change these setters only called notifyListeners().
  void _scheduleReload() {
    _reloadDebounceTimer?.cancel();
    _reloadDebounceTimer = Timer(filterReloadDebounce, loadOrders);
    // Immediate, so filter chips and toggles reflect the tap without waiting
    // for the query.
    notifyListeners();
  }

  // Memoization cache for the `orders` getter below - it used to re-run its
  // full filter chain on every read (i.e. every Consumer rebuild), which got
  // expensive once the in-memory order list grew into the thousands.
  String? _cachedFilterKey;
  List<OrderHistory>? _cachedFilteredOrders;

  List<OrderHistory> get orders {
    final key = '$_statusFilter|$_isCateringOnly|$_excludeCatering|'
        '$_isAdvancedOnly|$_timeFilter|$_billNumberQuery|'
        '$_serviceTypeFilter|$_ordersVersion';
    if (_cachedFilterKey == key && _cachedFilteredOrders != null) {
      return _cachedFilteredOrders!;
    }

    List<OrderHistory> filtered = List.from(_orders);

    // Filters 1, 2, 3 and 6 are now also applied in SQL (see _sqlFilters and
    // OrderQueryFilters), so on a normal fetch they drop nothing here. They are
    // kept deliberately: re-filtering already-filtered rows is a no-op, and it
    // means any query path that forgets to pass the filters still renders the
    // right list rather than showing rows the user filtered out. It cannot mask
    // the dangerous direction - a query returning too few rows is not
    // recoverable in memory - which is what the equivalence test covers.

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
               (o.customerName != null && o.customerName!.toLowerCase().contains(_billNumberQuery.toLowerCase())) ||
               (o.serviceType.toLowerCase().contains(_billNumberQuery.toLowerCase()));
      }).toList();

    }
    
    // 6. Generic Service Type Filter
    if (_serviceTypeFilter != null && _serviceTypeFilter!.isNotEmpty) {
      filtered = filtered.where((o) => o.serviceType.toLowerCase() == _serviceTypeFilter!.toLowerCase()).toList();
    }

    _cachedFilterKey = key;
    _cachedFilteredOrders = filtered;
    return filtered;
  }

  // Actions
  void setExcludeCatering(bool value) {
    _excludeCatering = value;
    // If excluding catering, ensure "isCateringOnly" is false to avoid conflict
    if (value) _isCateringOnly = false;
    _scheduleReload();
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
    _scheduleReload();
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

  // Which query loadOrders()/loadMoreOrders() should hit, given the active
  // filter combination. Mirrors the branching that used to live inline in
  // loadOrders() - kept here so loadMoreOrders() can reuse the same decision.
  // ── order-list tracing ────────────────────────────────────────────────────
  // Without this the order list is invisible in the crash log: nothing is timed
  // and only a thrown query leaves a trace, so there is no way to confirm from
  // a customer's log that a filter is fast or that pagination is working.
  //
  // Emitted as `⏱️ orders[...]` so it greps apart from `⏱️ payment[...]`.

  /// Skip logging a repeat of the same query below this, so the 30-second
  /// auto-refresh does not add ~2,900 lines a day and evict payment history
  /// from the capped log.
  static const int _listingLogThresholdMs = 150;

  /// Test seam. The default appends to the user's real
  /// Documents\cafeapp_crash_log.txt on Windows, which a test run must not do.
  @visibleForTesting
  static TraceWriter listingLogWriter = logErrorToFile;

  String? _lastLoggedQuery;

  String _modeLabel(_FetchMode mode) => switch (mode) {
        _FetchMode.advanced => 'advanced',
        _FetchMode.dateRange => 'dateRange:${_timeFilter.name}',
        _FetchMode.unbounded => 'unbounded',
      };

  /// Writes a listing line when it says something new: a different query, a
  /// page beyond the first, or anything slow enough to be worth knowing about.
  Future<void> _logListing(
    PaymentTrace trace,
    _FetchMode mode, {
    required int rows,
    required int page,
  }) async {
    final signature = '${_modeLabel(mode)}|${_sqlFilters.describe()}';
    final isNewQuery = signature != _lastLoggedQuery;
    final isSlow = trace.elapsedMs >= _listingLogThresholdMs;

    if (!isNewQuery && page == 0 && !isSlow) return;
    _lastLoggedQuery = signature;

    await trace.flush(
      outcome: 'rows=$rows visible=${orders.length} page=$page '
          'hasMore=$_hasMore filters=${_sqlFilters.describe()}',
    );
  }

  // The active range, widened by 24 hours on each side.
  //
  // The buffer accounts for created_at being compared as a string while being
  // written in more than one format; isInPeriod in the `orders` getter applies
  // the exact semantics afterwards. Extracted so loadOrders and loadMoreOrders
  // page over identical bounds.
  (DateTime, DateTime)? _bufferedRange() {
    final range = _getDateRangeForFilter();
    if (range == null) return null;
    return (
      range.$1.subtract(const Duration(hours: 24)),
      range.$2.add(const Duration(hours: 24)),
    );
  }

  _FetchMode _resolveFetchMode() {
    if (_isAdvancedOnly) return _FetchMode.advanced;
    if (_timeFilter != OrderTimeFilter.all && !_isCateringOnly && _statusFilter != 'all') {
      if (_getDateRangeForFilter() != null) return _FetchMode.dateRange;
    }
    return _FetchMode.unbounded;
  }

  // Actions
  // Optimized loadOrders with DB filtering
  Future<void> loadOrders() async {
    // An explicit load absorbs any reload a filter setter just scheduled, so a
    // screen that sets filters and then calls loadOrders() itself still issues
    // exactly one query.
    _reloadDebounceTimer?.cancel();

    _isLoading = true;
    _errorMessage = '';
    _pageOffset = 0;
    _hasMore = true;
    notifyListeners();

    final mode = _resolveFetchMode();
    final trace = PaymentTrace(_modeLabel(mode),
        writer: listingLogWriter, category: 'orders');

    try {
      List<Order> orderList;

      switch (mode) {
        case _FetchMode.advanced:
          // Advanced Mode: Fetch only orders with deposits, sorted by event date.
          // This bypasses the time filter to show all upcoming bookings.
          // Status is simple enough to filter in memory for this smaller subset.
          orderList = await _repository.getAdvancedOrders();
          _hasMore = false;
          break;
        case _FetchMode.dateRange:
          // Normal Mode with Time Filter: one page of the relevant date range.
          // This used to be unbounded, which made Yearly load the whole period -
          // measured at 22,383 rows / 996ms on a seeded dataset, extrapolating
          // to ~5s for a cafe taking 300 orders a day.
          final (bufferStart, bufferEnd) = _bufferedRange()!;
          orderList = await _repository.getOrdersByDateRange(
            bufferStart,
            bufferEnd,
            limit: _pageSize,
            offset: 0,
            filters: _sqlFilters,
          );
          _hasMore = orderList.length == _pageSize;
          break;
        case _FetchMode.unbounded:
          // No bounded date range to filter by (e.g. "All Orders") - page
          // through the table instead of pulling every row at once so this
          // stays fast regardless of how much order history has piled up.
          orderList = await _repository.getOrdersPage(
            limit: _pageSize,
            offset: 0,
            filters: _sqlFilters,
          );
          _hasMore = orderList.length == _pageSize;
          break;
      }

      _pageOffset = orderList.length;

      // Convert Order to OrderHistory
      _orders = orderList.map((o) => OrderHistory.fromOrder(o)).toList();
      _ordersVersion++;
      trace.mark('query');
      await _logListing(trace, mode, rows: orderList.length, page: 0);
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error loading orders: $e');
      await trace.flush(outcome: 'error=$e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch the next page of orders and append it to the current list. Only
  // meaningful in unbounded mode (advanced/date-range modes already fetch
  // their whole - naturally small - result set in one go).
  Future<void> loadMoreOrders() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    if (_billNumberQuery.isNotEmpty) return; // search results aren't paginated

    final mode = _resolveFetchMode();
    // Advanced mode fetches its whole - naturally small - set in one go and
    // sorts by event date rather than created_at, so it does not page.
    if (mode == _FetchMode.advanced) return;

    _isLoadingMore = true;
    notifyListeners();

    // Always logged - a load-more is user-driven and bounded, and it is the
    // only positive proof in the log that pagination is working.
    final trace = PaymentTrace(_modeLabel(mode),
        writer: listingLogWriter, category: 'orders');

    try {
      List<Order> more;
      if (mode == _FetchMode.dateRange) {
        final range = _bufferedRange();
        if (range == null) {
          _hasMore = false;
          return;
        }
        more = await _repository.getOrdersByDateRange(
          range.$1,
          range.$2,
          limit: _pageSize,
          offset: _pageOffset,
          filters: _sqlFilters,
        );
      } else {
        more = await _repository.getOrdersPage(
          limit: _pageSize,
          offset: _pageOffset,
          filters: _sqlFilters,
        );
      }
      final page = _pageOffset ~/ _pageSize;
      _hasMore = more.length == _pageSize;
      _pageOffset += more.length;
      _orders = List.of(_orders)..addAll(more.map((o) => OrderHistory.fromOrder(o)));
      _ordersVersion++;
      trace.mark('query');
      await _logListing(trace, mode, rows: more.length, page: page);
    } catch (e) {
      debugPrint('Error loading more orders: $e');
      await trace.flush(outcome: 'error=$e');
    } finally {
      _isLoadingMore = false;
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
    _ordersVersion++;
    notifyListeners();
  }

  /// How long typing must pause before a search actually runs.
  ///
  /// searchOrders is a LIKE scan with a leading wildcard, so no index can help
  /// it and its cost grows with order history - benchmarked at 38ms per call
  /// against 50,000 orders. Firing that on every keystroke made typing a bill
  /// number progressively laggier as a cafe's history grew. 300ms is below the
  /// ~400ms most people notice as delay, and coalesces a typed bill number into
  /// a single query instead of one per character.
  @visibleForTesting
  static Duration searchDebounce = const Duration(milliseconds: 300);

  Timer? _searchDebounceTimer;

  /// Incremented per search so a slow query cannot overwrite a newer one.
  int _searchSeq = 0;

  // Search across the whole order history via an indexed SQL query instead
  // of filtering whatever happens to already be loaded in memory - keeps bill
  // number / customer lookups fast even with thousands of historical orders.
  //
  // Returns immediately: the query is debounced and runs later. No caller
  // awaits this, and awaiting a debounced call would be misleading anyway.
  void searchOrdersByBillNumber(String val) {
    _billNumberQuery = val;
    _searchDebounceTimer?.cancel();

    if (val.isEmpty) {
      // Clearing runs immediately. The user is trying to get back to the full
      // list, and making them wait 300ms for that feels broken.
      _searchSeq++;
      loadOrders();
      return;
    }

    _searchDebounceTimer = Timer(searchDebounce, () => _runSearch(val));
  }

  Future<void> _runSearch(String val) async {
    final seq = ++_searchSeq;

    _isLoading = true;
    _errorMessage = '';
    _hasMore = false;
    notifyListeners();

    try {
      final results = await _repository.searchOrders(val);

      // A newer search (or a clear) started while this one was running. Its
      // results are the ones the user is waiting for, so drop these - otherwise
      // a slow query for "004" lands after a fast one for "0042" and the list
      // shows the wrong orders with the right text in the box.
      if (seq != _searchSeq) return;

      _orders = results.map((o) => OrderHistory.fromOrder(o)).toList();
      _ordersVersion++;
    } catch (e) {
      if (seq != _searchSeq) return;
      _errorMessage = e.toString();
      debugPrint('Error searching orders: $e');
    } finally {
      if (seq == _searchSeq) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    // Without this a pending search fires after the screen is gone and calls
    // notifyListeners() on a disposed ChangeNotifier, which throws.
    _searchDebounceTimer?.cancel();
    _reloadDebounceTimer?.cancel();
    super.dispose();
  }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    _scheduleReload();
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
          _ordersVersion++;
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