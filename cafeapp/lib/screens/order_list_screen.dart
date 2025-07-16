import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/order_history.dart';
import '../providers/order_history_provider.dart';
import 'order_details_screen.dart';
import '../screens/dashboard_screen.dart';
import 'dart:async';
import '../utils/app_localization.dart';

class OrderListScreen extends StatefulWidget {
  final String? serviceType;
  final bool fromMenuScreen;

  const OrderListScreen({super.key, this.serviceType, this.fromMenuScreen = false});

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
    return PopScope(
      // Handle back button press
      onPopInvoked: (didPop) async {
        // If opened from MenuScreen, just pop normally instead of navigating to dashboard
        if (widget.fromMenuScreen) {
          return;
        } else {
          // Navigate to dashboard screen instead of simply popping
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: Text(widget.serviceType != null 
            ? '${'Orders'.tr()} - ${widget.serviceType}' 
            : 'All Orders'.tr()),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Use the same navigation logic as PopScope
              if (widget.fromMenuScreen) {
                Navigator.of(context).pop(); // Simply go back
              } else {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  (route) => false,
                );
              }
            },
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
              hintText: 'Search order number...'.tr(),
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
        label: Text(_getFilterDisplayName(filter)),
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

  // Helper method to get translated filter names
  String _getFilterDisplayName(OrderTimeFilter filter) {
    switch (filter) {
      case OrderTimeFilter.today:
        return 'Today'.tr();
      case OrderTimeFilter.weekly:
        return 'This Week'.tr();
      case OrderTimeFilter.monthly:
        return 'This Month'.tr();
      case OrderTimeFilter.yearly:
        return 'This Year'.tr();
      case OrderTimeFilter.all:
        return 'All Time'.tr();
      default:
        return filter.displayName;
    }
  }

  Widget _buildPendingFilterButton() {
    return ElevatedButton.icon(
      icon: Icon(
        Icons.timer,
        color: _isPendingFilterActive ? Colors.white : Colors.orange,
        size: 18,
      ),
      label: Text(
        'Pending'.tr(),
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
        backgroundColor: _isPendingFilterActive ? Colors.orange : Colors.orange.withAlpha((0.1 * 255).round()),
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
                  '${'Error:'.tr()} ${historyProvider.errorMessage}',
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
                  child: Text('Retry'.tr()),
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
                      ? 'No orders found with that number'.tr() 
                      : (_isPendingFilterActive
                          ? 'No pending orders found'.tr()
                          : 'No orders found'.tr()),
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (!_isSearching) const SizedBox(height: 8),
                if (!_isSearching)
                  Text(
                    'Orders will appear here once they are placed'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          );
        }

        // Determine orientation and adjust grid accordingly
        final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
        
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isPortrait ? 3 : 6, // 3 columns in portrait, 6 in landscape
              childAspectRatio: isPortrait ? 1.2 : 1.1, // Adjust aspect ratio for portrait
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
    Color statusColor = Colors.white;
    String translatedStatus = _getTranslatedStatus(order.status);
    
    if (order.status.toLowerCase() == 'pending') {
      statusColor = Colors.white;
    } else if (order.status.toLowerCase() == 'cancelled') {
      statusColor = Colors.white;
    }
    
    // Override text colors to always be visible
    Color textColor = Colors.black;
    Color secondaryTextColor = Colors.black87;
    
    // Check orientation for compact layout
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
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
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with centered bill number and status
              Column(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '#${order.orderNumber}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isPortrait ? 12 : 14, // Smaller font in portrait
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(51),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        translatedStatus,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              Divider(
                height: isPortrait ? 8 : 12, // Shorter divider in portrait
                color: Colors.black.withAlpha(20),
              ),
              
              // Service type - translate display
              Row(
                children: [
                  Icon(
                    serviceIcon,
                    size: isPortrait ? 12 : 14, // Smaller icon in portrait
                    color: Colors.black87,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _getTranslatedServiceType(order.serviceType),
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: isPortrait ? 10 : 12, // Smaller font in portrait
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: isPortrait ? 4 : 6), // Less spacing in portrait
              
              // Order date and time - more compact in portrait
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: isPortrait ? 10 : 12,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.formattedDate,
                        style: TextStyle(
                          fontSize: isPortrait ? 9 : 10,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: isPortrait ? 10 : 12,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.formattedTime,
                        style: TextStyle(
                          fontSize: isPortrait ? 9 : 10,
                          color: secondaryTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Amount
              Container(
                width: double.infinity,
                alignment: Alignment.centerRight,
                child: Text(
                  currencyFormat.format(order.total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isPortrait ? 12 : 14,
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

  // Helper method to translate service type for display
  String _getTranslatedServiceType(String serviceType) {
    if (serviceType.contains('Dining')) {
      // Extract table number if it exists
      final tableMatch = RegExp(r'Table (\d+)').firstMatch(serviceType);
      if (tableMatch != null) {
        final tableNumber = tableMatch.group(1);
        return '${'Dining'.tr()} - ${'Table'.tr()} $tableNumber';
      }
      return 'Dining'.tr();
    } else if (serviceType.contains('Takeout')) {
      return 'Takeout'.tr();
    } else if (serviceType.contains('Delivery')) {
      return 'Delivery'.tr();
    } else if (serviceType.contains('Drive')) {
      return 'Drive Through'.tr();
    } else if (serviceType.contains('Catering')) {
      return 'Catering'.tr();
    } else {
      return serviceType; // Fallback to original
    }
  }

  // Helper method to translate status
  String _getTranslatedStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'pending'.tr();
      case 'completed':
        return 'completed'.tr();
      case 'cancelled':
        return 'cancelled'.tr();
      default:
        return status;
    }
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