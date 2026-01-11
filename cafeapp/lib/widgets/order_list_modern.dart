
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/order_history.dart';
import '../providers/order_history_provider.dart';
import '../screens/order_details_screen.dart';
// import '../utils/app_localization.dart';
import '../utils/service_type_utils.dart';

class OrderListModern extends StatefulWidget {
  final String? serviceType;
  final VoidCallback? onBack;

  const OrderListModern({super.key, this.serviceType, this.onBack});

  @override
  State<OrderListModern> createState() => _OrderListModernState();
}

class _OrderListModernState extends State<OrderListModern> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  OrderTimeFilter _selectedFilter = OrderTimeFilter.today;
  Timer? _refreshTimer;
  bool _isPendingFilterActive = false;

  @override
  void initState() {
    super.initState();
    // Refresh logic
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        Provider.of<OrderHistoryProvider>(context, listen: false).loadOrders();
      }
    });
    
    // Initial Load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final historyProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
      historyProvider.setTimeFilter(OrderTimeFilter.today); // Default to today
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16161d), // Deep dark background
      body: SafeArea(
        child: Column(
          children: [
             _buildHeader(),
             const SizedBox(height: 20),
             _buildSearchAndFilters(),
             const SizedBox(height: 20),
             Expanded(child: _buildOrderGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        children: [
          _buildIconButton(Icons.arrow_back, onTap: widget.onBack ?? () => Navigator.of(context).pop()),
          const SizedBox(width: 16),
          Text(
            widget.serviceType != null ? '${widget.serviceType} Orders' : 'All Orders',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))]
            ),
          ),
          const Spacer(),
          _buildIconButton(Icons.receipt_long, color: const Color(0xFFd4af37), onTap: () {
            // Receipt logic placeholder
            debugPrint("Receipt tapped");
          }),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, {VoidCallback? onTap, Color? color}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(25)),
        boxShadow: [
           BoxShadow(color: Colors.black.withAlpha(76), blurRadius: 8, offset: const Offset(2, 4))
        ]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Icon(icon, color: color ?? Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 10, offset: const Offset(0, 5))
              ]
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search order number...',
                hintStyle: TextStyle(color: Colors.white.withAlpha(76)),
                filled: true,
                fillColor: const Color(0xFF1f242e),
                prefixIcon: Icon(Icons.search, color: Colors.white.withAlpha(128)),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _isSearching = false);
                          Provider.of<OrderHistoryProvider>(context, listen: false).searchOrdersByBillNumber('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.white.withAlpha(25)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.white.withAlpha(25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFd4af37), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onChanged: (val) {
                 setState(() => _isSearching = val.isNotEmpty);
                 if (val.isEmpty) Provider.of<OrderHistoryProvider>(context, listen: false).searchOrdersByBillNumber('');
              },
              onSubmitted: (val) {
                if (val.isNotEmpty) Provider.of<OrderHistoryProvider>(context, listen: false).searchOrdersByBillNumber(val);
              },
            ),
          ),
          const SizedBox(height: 24),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip("Today", OrderTimeFilter.today),
                _buildFilterChip("This Week", OrderTimeFilter.weekly),
                _buildFilterChip("This Month", OrderTimeFilter.monthly),
                _buildFilterChip("This Year", OrderTimeFilter.yearly),
                _buildFilterChip("All", OrderTimeFilter.all),
                const SizedBox(width: 24),
                Container(width: 1, height: 30, color: Colors.white.withAlpha(51)), // Separator
                const SizedBox(width: 24),
                _buildPendingFilter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, OrderTimeFilter filter) {
    final isSelected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = filter;
            if (_isPendingFilterActive) {
               Provider.of<OrderHistoryProvider>(context, listen: false).setStatusFilter('pending');
            } else {
               Provider.of<OrderHistoryProvider>(context, listen: false).setStatusFilter(null);
            }
          });
          Provider.of<OrderHistoryProvider>(context, listen: false).setTimeFilter(filter);
        },
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFd4af37) : Colors.white.withAlpha(13),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? const Color(0xFFd4af37) : Colors.white.withAlpha(25),
            ),
            boxShadow: isSelected ? [
              BoxShadow(color: const Color(0xFFd4af37).withAlpha(76), blurRadius: 10, offset: const Offset(0, 4))
            ] : []
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white.withAlpha(76),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingFilter() {
    return InkWell(
      onTap: () {
        setState(() => _isPendingFilterActive = !_isPendingFilterActive);
        final historyProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
        historyProvider.setStatusFilter(_isPendingFilterActive ? 'pending' : null);
        if (widget.serviceType != null) {
          historyProvider.loadOrdersByServiceType(widget.serviceType!);
        } else {
          historyProvider.loadOrders();
        }
      },
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _isPendingFilterActive ? const Color(0xFFff8a65) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _isPendingFilterActive ? const Color(0xFFff8a65) : const Color(0xFFff8a65).withAlpha(51)),
          boxShadow: _isPendingFilterActive ? [
             BoxShadow(color: const Color(0xFFff8a65).withAlpha(76), blurRadius: 10, offset: const Offset(0, 4))
          ] : [],
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, size: 18, color: _isPendingFilterActive ? Colors.white : const Color(0xFFff8a65)),
            const SizedBox(width: 8),
            Text(
              "Pending",
              style: TextStyle(
                color: _isPendingFilterActive ? Colors.white : const Color(0xFFff8a65),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderGrid() {
    return Consumer<OrderHistoryProvider>(
      builder: (context, historyProvider, child) {
        if (historyProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFd4af37)));
        }
        
        final orders = historyProvider.orders;
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 80, color: Colors.white.withAlpha(51)),
                const SizedBox(height: 16),
                Text(
                  _isSearching ? "No matching orders found" : "No orders yet",
                  style: TextStyle(color: Colors.white.withAlpha(76), fontSize: 18),
                ),
              ],
            ),
          );
        }

        // Adaptive Grid
        final width = MediaQuery.of(context).size.width;
        final crossAxisCount = width > 1100 ? 5 : (width > 800 ? 4 : (width > 600 ? 3 : 2)); // Adjusted breakpoints
        
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.8, // Taller cards
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: orders.length,
          itemBuilder: (context, index) => _buildOrderCard(orders[index]),
        );
      },
    );
  }

  Widget _buildOrderCard(OrderHistory order) {
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 2);
    
    // Determine Gradient based on Service Type
    LinearGradient cardGradient;
    Color accentColor;

    switch (order.serviceType.toLowerCase()) {
      case 'dining':
      case 'dining table':
        cardGradient = const LinearGradient(
          colors: [Color(0xFFe69a6b), Color(0xFF8c4a2a)], // Orange
          begin: Alignment.topLeft, end: Alignment.bottomRight
        );
        accentColor = const Color(0xFFe69a6b);
        break;
      case 'delivery':
        cardGradient = const LinearGradient(
          colors: [Color(0xFF8bcce3), Color(0xFF3b697b)], // Blue
          begin: Alignment.topLeft, end: Alignment.bottomRight
        );
        accentColor = const Color(0xFF8bcce3);
        break;
      case 'takeout':
      case 'take away':
        cardGradient = const LinearGradient(
           colors: [Color(0xFF96aa71), Color(0xFF4b5832)], // Green
           begin: Alignment.topLeft, end: Alignment.bottomRight
        );
        accentColor = const Color(0xFF96aa71);
        break;
       case 'drive through':
        cardGradient = const LinearGradient(
           colors: [Color(0xFFc98693), Color(0xFF6e3c44)], // Pink
           begin: Alignment.topLeft, end: Alignment.bottomRight
        );
        accentColor = const Color(0xFFc98693);
        break;
       case 'catering':
        cardGradient = const LinearGradient(
           colors: [Color(0xFFf5ca5c), Color(0xFF917224)], // Gold
           begin: Alignment.topLeft, end: Alignment.bottomRight
        );
        accentColor = const Color(0xFFf5ca5c);
        break;
      default:
        cardGradient = const LinearGradient(
          colors: [Color(0xFF5e636b), Color(0xFF2b2e35)], // Dark Grey
          begin: Alignment.topLeft, end: Alignment.bottomRight
        );
        accentColor = Colors.grey;
    }


    return Container(
      decoration: BoxDecoration(
        // We use a dark base with the gradient overlay
        color: const Color(0xFF252830),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(76),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Gradient Accent Header
          Positioned(
            top: 0, left: 0, right: 0,
            height: 90,
            child: Container(
              decoration: BoxDecoration(
                gradient: cardGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
          ),
          
          Material(
            color: Colors.transparent,
            child: InkWell(
               onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => OrderDetailsScreen(orderId: order.id)),
                );
              },
              borderRadius: BorderRadius.circular(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Content (Over Gradient)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${order.orderNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                             order.status.toUpperCase(),
                             style: TextStyle(
                               color: accentColor, // Text matches card theme
                               fontWeight: FontWeight.bold,
                               fontSize: 10,
                             ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20), // Spacing for visual overlap

                  // Body Content (Dark Area)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Center(
                             child: Text(
                              currencyFormat.format(order.total),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                             ),
                           ),
                           const SizedBox(height: 16),
                           Divider(color: Colors.white.withAlpha(25)),
                           const SizedBox(height: 8),

                           _buildOrderRow(Icons.restaurant_menu, _getServiceTypeDisplayName(order.serviceType)),
                           const SizedBox(height: 6),
                           _buildOrderRow(Icons.access_time, order.formattedTime),
                           const SizedBox(height: 6),
                           _buildOrderRow(Icons.calendar_today, order.formattedDate),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white.withAlpha(76)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.white.withAlpha(76), fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _getServiceTypeDisplayName(String serviceType) {
    return ServiceTypeUtils.getTranslated(serviceType);
  }
}
