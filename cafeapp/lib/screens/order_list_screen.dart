import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/order_history.dart';
import '../providers/order_history_provider.dart';
import 'order_details_screen.dart';
import '../screens/dashboard_screen.dart';
import 'dart:async';
import '../utils/app_localization.dart';
import '../utils/service_type_utils.dart';
import 'search_person_screen.dart';
import '../models/person.dart';
import '../widgets/clock_widget.dart';
import '../screens/quotations_list_screen.dart';


class OrderListScreen extends StatefulWidget {
  final String? serviceType;
  final bool fromMenuScreen;
  final bool excludeCatering; // New parameter
  final bool isCateringOnly;  // New parameter
  final String? searchQuery;

  const OrderListScreen({
    super.key, 
    this.serviceType, 
    this.fromMenuScreen = false,
    this.excludeCatering = true, // Default to true to hide catering from main list
    this.isCateringOnly = false,
    this.searchQuery,
  });

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  OrderTimeFilter _selectedFilter = OrderTimeFilter.today;
  Timer? _refreshTimer;
  
  // Track if pending filter is active
  bool _isPendingFilterActive = false;

  @override
  void initState() {
    super.initState();
    
    // Handle initial search query if provided
    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      _searchController.text = widget.searchQuery!;
      _isSearching = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
         final historyProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
         historyProvider.setTimeFilter(OrderTimeFilter.all);
         historyProvider.searchOrdersByBillNumber(widget.searchQuery!);
         setState(() {
           _selectedFilter = OrderTimeFilter.all;
         });
      });
    }

    // Refresh every 30 seconds to catch synced orders
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        try {
          debugPrint('🔄 Auto-refreshing order history');
          Provider.of<OrderHistoryProvider>(context, listen: false).loadOrders();
        } catch (e) {
          debugPrint('⚠️ Error refreshing orders from timer: $e');
        }
      }
    });
    // _updateTime();
    
    // Start timer to update time every second
    // _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    //   _updateTime();
    // });
    
    // Load orders on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final historyProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
      
      // NEW: Reset invalid state from previous screens matches
      historyProvider.resetFilters();
      
      // Set the time filter to Today by default for both cases
      historyProvider.setTimeFilter(OrderTimeFilter.today);
      
      // Apply filters based on widget params
      if (widget.excludeCatering) {
        historyProvider.setExcludeCatering(true);
      } else if (widget.isCateringOnly) {
        historyProvider.setCateringOnly(true);
      } else {
        // Reset if normal view
        historyProvider.setExcludeCatering(false);
        historyProvider.setCateringOnly(false);
      }
      
      if (widget.serviceType != null) {
        historyProvider.loadOrdersByServiceType(widget.serviceType!);
      } else {
        historyProvider.loadOrders();
      }
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    // _timer?.cancel();
    super.dispose();
  }
  
  // void _updateTime() {
  //   final now = DateTime.now();
  //   final formatter = DateFormat('hh:mm a');
  //   setState(() {
  //     _currentTime = formatter.format(now);
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Handle back button press
      onPopInvokedWithResult: (didPop, result) async {
        // If opened from MenuScreen, just pop normally instead of navigating to dashboard
        if (widget.fromMenuScreen) {
          return;
        } else {
          // Navigate to dashboard screen instead of simply popping
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
               builder: (context) => const DashboardScreen(),
               settings: const RouteSettings(name: 'DashboardScreen'),
            ),
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
                  MaterialPageRoute(
                     builder: (context) => const DashboardScreen(),
                     settings: const RouteSettings(name: 'DashboardScreen'),
                  ),
                  (route) => false,
                );
              }
            },
          ),
          actions: [
            TextButton.icon(
                icon: const Icon(Icons.description_rounded),
                label: Text('Quotations List'.tr()),
                onPressed: () {
                 Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QuotationsListScreen()),
                );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.yellow[800],
                ),
              ),
            // Refresh Button
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh'.tr(),
              onPressed: () {
                final historyProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
                if (widget.serviceType != null) {
                  historyProvider.loadOrdersByServiceType(widget.serviceType!);
                } else {
                  historyProvider.loadOrders();
                }
              },
            ),
            
            TextButton.icon(
                icon: const Icon(Icons.receipt),
                label: Text('Receipt'.tr()),
                onPressed: _navigateToPersonSearchForReceipt,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green[800],
                ),
              ),
            
            // Time display
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.black, size: 20),
                  const SizedBox(width: 4),
                  const ClockWidget(
                    style: TextStyle(color: Colors.black),
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
                // Catering filter button
                _buildCateringFilterButton(),
                
                // Advanced filter button - Only show if Catering is active
                Consumer<OrderHistoryProvider>(
                  builder: (context, historyProvider, child) {
                    if (historyProvider.isCateringOnly) {
                      return Row(
                        children: [
                          const SizedBox(width: 8),
                          _buildAdvancedFilterButton(),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                
                const SizedBox(width: 8),
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
        return 'All Orders'.tr();
    }
  }

  Widget _buildCateringFilterButton() {
    return Consumer<OrderHistoryProvider>(
      builder: (context, historyProvider, child) {
        final isActive = historyProvider.isCateringOnly;
        return ElevatedButton.icon(
          icon: Icon(
            Icons.room_service_rounded,
            color: isActive ? Colors.white : Colors.amber,
            size: 18,
          ),
          label: Text(
            'Catering'.tr(),
            style: TextStyle(
              color: isActive ? Colors.white : Colors.amber,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () {
            historyProvider.toggleCateringOnly();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? Colors.amber : Colors.amber.withAlpha((0.1 * 255).round()),
            foregroundColor: isActive ? Colors.white : Colors.amber,
            elevation: isActive ? 2 : 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(
                color: Colors.amber,
                width: 1,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdvancedFilterButton() {
    return Consumer<OrderHistoryProvider>(
      builder: (context, historyProvider, child) {
        final isActive = historyProvider.isAdvancedOnly;
        return ElevatedButton.icon(
          icon: Icon(
            Icons.account_balance_wallet_rounded,
            color: isActive ? Colors.white : Colors.blueAccent,
            size: 18,
          ),
          label: Text(
            'Advanced'.tr(),
            style: TextStyle(
              color: isActive ? Colors.white : Colors.blueAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () {
            historyProvider.toggleAdvancedOnly();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? Colors.blueAccent : Colors.blueAccent.withAlpha((0.1 * 255).round()),
            foregroundColor: isActive ? Colors.white : Colors.blueAccent,
            elevation: isActive ? 2 : 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(
                color: Colors.blueAccent,
                width: 1,
              ),
            ),
          ),
        );
      },
    );
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

        // Determine orientation and layout based on screen width
        final screenWidth = MediaQuery.of(context).size.width;
        final isPhone = screenWidth < 600;
        final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
        
        // Responsive Grid Config
        // Phone: 2 Column Grid (Optimized for density)
        // Tablet Portrait: 3 Column Grid
        // Tablet Landscape / Desktop: 5 Column Grid
        final crossAxisCount = isPhone ? 2 : (isPortrait ? 5 : 7);
        
        // Aspect Ratio
        // Phone: Taller cards (~1.3) matching Dashboard Service Cards
        // Tablet: Standard aspect ratio (~0.85)
        final childAspectRatio = isPhone ? 1.3 : (isPortrait ? 0.85 : 0.95);

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount, 
              childAspectRatio: childAspectRatio,
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
    
    // Unified Grid Layout (Phone & Tablet)
    // Both Phone and Tablet now use the Column-based Card layout
    // Phone uses it in a 2-column grid. Tablet uses it in a 3+ column grid.

    // Tablet/Grid Layout (Column - Original)
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
              settings: const RouteSettings(name: 'OrderDetailsScreen'),
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
                        fontWeight: FontWeight.bold,
                        fontSize: isPortrait ? 10 : 12, // Smaller font in portrait
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              // Token Number
              if (order.tokenNumber != null && order.tokenNumber!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Center(
                    child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                       decoration: BoxDecoration(
                         color: Colors.black12,
                         borderRadius: BorderRadius.circular(4),
                       ),
                      child: Text(
                        '${'Token:'.tr()} ${order.tokenNumber}',
                        style: TextStyle(
                          fontSize: isPortrait ? 12 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                  
                  
              // Customer Name
              if (order.customerName != null && order.customerName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: isPortrait ? 10 : 12,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.customerName!,
                          style: TextStyle(
                            fontSize: isPortrait ? 10 : 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              
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

                ],
              ),
              
              const Spacer(),
              
              // Footer with Advance (left) and Total (right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if ((order.depositAmount ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2.0),
                      child: Text(
                        '${'Adv:'.tr()} ${currencyFormat.format(order.depositAmount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isPortrait ? 9 : 11,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    )
                  else
                    const SizedBox(),
                  
                  Text(
                    currencyFormat.format(order.total),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isPortrait ? 12 : 14,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _navigateToPersonSearchForReceipt() async {
  final selectedPerson = await Navigator.push<Person>(
    context,
    MaterialPageRoute(
      builder: (context) => const SearchPersonScreen(isForCreditReceipt: true),
      settings: const RouteSettings(name: 'SearchPersonScreen'),
    ),
  );
  
  if (selectedPerson != null) {
    // Handle the selected person if needed
    debugPrint('Selected person for credit receipt: ${selectedPerson.name}');
  }
}

 // Helper method to translate service type for display
  String _getTranslatedServiceType(String serviceType) {
    return ServiceTypeUtils.getTranslated(serviceType);
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
    return ServiceTypeUtils.getIcon(serviceType);
  }

  Color _getServiceTypeColor(String serviceType) {
    return ServiceTypeUtils.getColor(serviceType);
  }
}