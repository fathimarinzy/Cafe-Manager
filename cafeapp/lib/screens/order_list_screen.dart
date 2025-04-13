import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/order_history.dart';
import '../providers/order_history_provider.dart';
import 'order_details_screen.dart';
import 'dart:async';

class OrderListScreen extends StatefulWidget {
  final String? serviceType;

  const OrderListScreen({super.key, this.serviceType});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  OrderTimeFilter _selectedFilter = OrderTimeFilter.today;
  String _currentTime = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateTime();
    
    // Start timer to update time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
    
    // Load orders on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final historyProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
      // Set the time filter to Today by default for both cases
      historyProvider.setTimeFilter(OrderTimeFilter.today);
      
      if (widget.serviceType != null) {
        historyProvider.loadOrdersByServiceType(widget.serviceType!);
      } else {
        historyProvider.loadOrders();
      }
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _timer?.cancel();
    super.dispose();
  }
  
  void _updateTime() {
    final now = DateTime.now();
    final formatter = DateFormat('hh:mm a');
    setState(() {
      _currentTime = formatter.format(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(widget.serviceType != null 
          ? '${widget.serviceType} Orders' 
          : 'All Orders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Time display
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.black, size: 20),
                const SizedBox(width: 4),
                Text(
                  _currentTime,
                  style: const TextStyle(color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          Expanded(
            child: _buildOrderList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search order number...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching ? 
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _isSearching = false;
                    });
                    Provider.of<OrderHistoryProvider>(context, listen: false)
                      .searchOrdersByBillNumber('');
                  },
                ) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _isSearching = value.isNotEmpty;
              });
              if (value.isEmpty) {
                Provider.of<OrderHistoryProvider>(context, listen: false)
                  .searchOrdersByBillNumber('');
              }
            },
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                Provider.of<OrderHistoryProvider>(context, listen: false)
                  .searchOrdersByBillNumber(value);
              }
            },
          ),
          
          const SizedBox(height: 16),
          
          // Time filter buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(OrderTimeFilter.today),
                _buildFilterChip(OrderTimeFilter.weekly),
                _buildFilterChip(OrderTimeFilter.monthly),
                _buildFilterChip(OrderTimeFilter.yearly),
                _buildFilterChip(OrderTimeFilter.all),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(OrderTimeFilter filter) {
    final isSelected = _selectedFilter == filter;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(filter.displayName),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = filter;
          });
          Provider.of<OrderHistoryProvider>(context, listen: false)
            .setTimeFilter(filter);
        },
        backgroundColor: Colors.grey.shade200,
        selectedColor: Colors.blue.shade100,
        checkmarkColor: Colors.blue.shade800,
      ),
    );
  }

  Widget _buildOrderList() {
    return Consumer<OrderHistoryProvider>(
      builder: (context, historyProvider, child) {
        if (historyProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (historyProvider.errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error: ${historyProvider.errorMessage}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (widget.serviceType != null) {
                      historyProvider.loadOrdersByServiceType(widget.serviceType!);
                    } else {
                      historyProvider.loadOrders();
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        final orders = historyProvider.orders;
        
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  _isSearching 
                      ? 'No orders found with that number' 
                      : 'No orders found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (!_isSearching) const SizedBox(height: 8),
                if (!_isSearching)
                  Text(
                    'Orders will appear here once they are placed',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(order);
          },
        );
      },
    );
  }
  
  Widget _buildOrderCard(OrderHistory order) {
    // Format currency
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailsScreen(orderId: order.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bill #${order.orderNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Service type icon and name
                  Row(
                    children: [
                      Icon(
                        _getServiceTypeIcon(order.serviceType),
                        size: 16,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.serviceType,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  // Total amount
                  Text(
                    currencyFormat.format(order.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Date and time
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.formattedTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  // View details button
                  Row(
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.blue.shade700,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  IconData _getServiceTypeIcon(String serviceType) {
    if (serviceType.contains('Dining')) {
      return Icons.restaurant;
    } else if (serviceType.contains('Takeout')) {
      return Icons.takeout_dining;
    } else if (serviceType.contains('Delivery')) {
      return Icons.delivery_dining;
    } else if (serviceType.contains('Drive')) {
      return Icons.drive_eta;
    } else if (serviceType.contains('Catering')) {
      return Icons.cake;
    } else {
      return Icons.receipt;
    }
  }
}