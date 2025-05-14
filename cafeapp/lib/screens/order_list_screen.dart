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
  
  // Track if pending filter is active
  bool _isPendingFilterActive = false;

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
                  Row(
                    children: [
                // Filter chips for time periods
                _buildFilterChip(OrderTimeFilter.today),
                _buildFilterChip(OrderTimeFilter.weekly),
                _buildFilterChip(OrderTimeFilter.monthly),
                _buildFilterChip(OrderTimeFilter.yearly),
                _buildFilterChip(OrderTimeFilter.all),
                 ],
               ),
             
              const SizedBox(width: 150),    
              // Pending filter button - right after All Orders
              _buildPendingFilterButton(),
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
            
            // If pending filter is active, maintain it when changing time filter
            if (_isPendingFilterActive) {
              Provider.of<OrderHistoryProvider>(context, listen: false).setStatusFilter('pending');
            } else {
              Provider.of<OrderHistoryProvider>(context, listen: false).setStatusFilter(null);
            }
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

  // New method for the Pending filter button
  Widget _buildPendingFilterButton() {
    return ElevatedButton.icon(
      icon: Icon(
        Icons.timer,
        color: _isPendingFilterActive ? Colors.white : Colors.orange,
        size: 18,
      ),
      label: Text(
        'Pending',
        style: TextStyle(
          color: _isPendingFilterActive ? Colors.white : Colors.orange,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: () {
        setState(() {
          _isPendingFilterActive = !_isPendingFilterActive;
        });
        
        final historyProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
        
        // Toggle pending filter
        if (_isPendingFilterActive) {
          historyProvider.setStatusFilter('pending');
        } else {
          historyProvider.setStatusFilter(null);
        }
        
        // Reload orders with the new filter
        if (widget.serviceType != null) {
          historyProvider.loadOrdersByServiceType(widget.serviceType!);
        } else {
          historyProvider.loadOrders();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _isPendingFilterActive ? Colors.orange : Colors.orange.withOpacity(0.1),
        foregroundColor: _isPendingFilterActive ? Colors.white : Colors.orange,
        elevation: _isPendingFilterActive ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.orange,
            width: 1,
          ),
        ),
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
                      : (_isPendingFilterActive
                          ? 'No pending orders found'
                          : 'No orders found'),
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

        // Card Grid View implementation
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,  // 6 columns
              childAspectRatio: 1.1,  // More square aspect ratio for shorter cards
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              return _buildOrderCard(orders[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(OrderHistory order) {
  // Format currency
  final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
  
  // Get service type icon and color
  IconData serviceIcon = _getServiceTypeIcon(order.serviceType);
  Color serviceColor = _getServiceTypeColor(order.serviceType);
  
  // Determine status color
  Color statusColor = Colors.green;
  if (order.status.toLowerCase() == 'pending') {
    statusColor = Colors.orange;
  } else if (order.status.toLowerCase() == 'cancelled') {
    statusColor = Colors.red;
  }
  
  // Choose text color based on background brightness
  bool isDarkBackground = _isDarkColor(serviceColor);
  Color textColor = isDarkBackground ? Colors.white : Colors.black;
  Color secondaryTextColor = isDarkBackground ? Colors.white.withAlpha(200) : Colors.black87;
  
  return Card(
    elevation: 1,  // Minimal elevation
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),  // Smaller radius
    ),
    // Use the full service type color as the card background
    color: serviceColor,
    child: InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailsScreen(orderId: order.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(6),  // Smaller radius
      child: Padding(
        padding: const EdgeInsets.all(4.0),  // Minimal padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with centered bill number and status
            Column(
              children: [
                // Centered bill number
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '#${order.orderNumber}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,  // Smaller font
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Status indicator below bill number
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDarkBackground 
                          ? Colors.white.withAlpha(40) 
                          : statusColor.withAlpha(51),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(
                        color: isDarkBackground ? Colors.white : statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            Divider(
              height: 12,
              color: isDarkBackground ? Colors.white.withAlpha(50) : Colors.black.withAlpha(20),
            ),
            
            // Service type
            Row(
              children: [
                Icon(
                  serviceIcon,
                  size: 14,  // Reduced icon size
                  color: isDarkBackground ? Colors.white : Colors.black87,
                ),
                const SizedBox(width: 4),  // Reduced spacing
                Expanded(
                  child: Text(
                    order.serviceType,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12,  // Smaller font size
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 6),  // Reduced spacing
            
            // Order date and time
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: secondaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.formattedDate,
                          style: TextStyle(
                            fontSize: 10,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: secondaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.formattedTime,
                          style: TextStyle(
                            fontSize: 10,
                            color: secondaryTextColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            
            const Spacer(),
            
            // Amount - removed View button
            Container(
              width: double.infinity,
              alignment: Alignment.centerRight,
              child: Text(
                currencyFormat.format(order.total),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Add this helper method to determine if a color is dark
bool _isDarkColor(Color color) {
  // Calculate perceived brightness using the formula: (299*R + 587*G + 114*B) / 1000
  // Where R, G, B values are between 0 and 255
  double brightness = (299 * color.red + 587 * color.green + 114 * color.blue) / 1000;
  return brightness < 128; // If brightness is less than 128, consider it dark
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
  // Add this helper method to get color based on service type
Color _getServiceTypeColor(String serviceType) {
  if (serviceType.contains('Dining')) {
    return const Color.fromARGB(255, 83, 153, 232); // Dark blue for dining
  } else if (serviceType.contains('Takeout')) {
    return const Color.fromARGB(255, 121, 221, 124); // Green for takeout
  } else if (serviceType.contains('Delivery')) {
    return const Color.fromARGB(255, 255, 152, 0); // Orange for delivery
  } else if (serviceType.contains('Drive')) {
    return const Color.fromARGB(255, 219, 128, 128); // Light red for drive through
  } else if (serviceType.contains('Catering')) {
    return const Color.fromARGB(255, 232, 216, 65); // Yellow for catering
  } else {
    return const Color(0xFF607D8B); // Light charcoal for other order types
  }
}
}