import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'menu_screen.dart';
import 'table_orders_screen.dart'; 
import '../providers/order_provider.dart';
import '../providers/table_provider.dart';
import '../providers/order_history_provider.dart'; 
import '../utils/app_localization.dart';

class DiningTableScreen extends StatefulWidget {
  const DiningTableScreen({super.key});

  @override
  State<DiningTableScreen> createState() => _DiningTableScreenState();
}

class _DiningTableScreenState extends State<DiningTableScreen> {
  late Timer _timer;
  late String _currentTime;
  
  // Table layout configuration
  int _columns = 4; // Default columns
  int _rows = 4;    // Default rows
  
  @override
  void initState() {
    super.initState();
    _updateTime();
    // Update time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
    
    // Load saved layout configuration
    _loadSavedLayout();
    
    // Ensure table status is up to date on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final tableProvider = Provider.of<TableProvider>(context, listen: false);
        tableProvider.refreshTables();
      }
    });
  }
  
  // Load layout configuration from SharedPreferences
  Future<void> _loadSavedLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load values with defaults if not found
      final savedRows = prefs.getInt('dining_table_rows') ?? 4;
      final savedColumns = prefs.getInt('dining_table_columns') ?? 4;
      
      // Only update state if mounted to prevent errors
      if (mounted) {
        setState(() {
          _rows = savedRows;
          _columns = savedColumns;
        });
      }
    } catch (e) {
      // If loading fails, keep default values
      debugPrint('Error loading layout settings: $e');
    }
  }
  
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
  
  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : now.hour == 0 ? 12 : now.hour;
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
  
    setState(() {
      _currentTime = '${hour.toString()}:${now.minute.toString().padLeft(2, '0')} $amPm';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tableProvider = Provider.of<TableProvider>(context);
    final tables = tableProvider.tables;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Dining Tables'.tr(),
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          const SizedBox(width: 10),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade300,
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0), // Reduced padding
          child: Column(
            children: [
              const SizedBox(height: 8), // Reduced spacing
              Expanded(
                child: tables.isEmpty 
                  ? Center(child: Text('No tables available. Add tables from the Tables menu.'.tr()))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate the size for each table card based on available space
                        final double maxWidth = constraints.maxWidth;
                        final double maxHeight = constraints.maxHeight;
                        
                        // Calculate card width and height with spacing considered
                        final cardWidth = (maxWidth - ((_columns - 1) * 8)) / _columns;
                        final cardHeight = (maxHeight - ((_rows - 1) * 8)) / _rows;
                        
                        // Use a fixed aspect ratio
                        final aspectRatio = cardWidth / cardHeight;
                                          
                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _columns,
                            crossAxisSpacing: 8, // Reduced spacing
                            mainAxisSpacing: 8, // Reduced spacing
                            childAspectRatio: aspectRatio > 0 ? aspectRatio : 1.0,
                          ),
                          itemCount: tables.length,
                          itemBuilder: (context, index) {
                            if (index >= tables.length) {
                              return const SizedBox.shrink(); // Empty space for extra cells
                            }
                            
                            final table = tables[index];
                            
                            // Get the OrderProvider
                            final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                            // IMPORTANT: Always use English for internal service type
                            // This ensures consistency with payment processing logic
                            final String serviceType = 'Dining - Table ${table.number}';

                            return _buildTableCard(
                              table.number,
                              table.isOccupied,
                              orderProvider,
                              serviceType,
                            );
                          },
                        );
                      }
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigate to Menu Screen and handle return
  Future<void> _navigateToMenuScreen(String serviceType, OrderProvider orderProvider) async {
    orderProvider.setCurrentServiceType(serviceType);
    // Clear any previous order ID when creating a new order
    orderProvider.setCurrentOrderId(null);
    
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => MenuScreen(
          serviceType: serviceType,
        ),
      ),
    );

    // Check if widget is still mounted before continuing
    if (mounted) {
      // Refresh the table status when returning
      final tableProvider = Provider.of<TableProvider>(context, listen: false);
      tableProvider.refreshTables();
      
      // Extract table number from service type
      final tableNumberStr = serviceType.split('Table ').last;
      final tableNumber = int.tryParse(tableNumberStr);
      
      if (tableNumber != null) {
        // Check if there are any active orders for this table
        debugPrint('Checking table $tableNumber status after returning from menu');
      }
      
      // Force UI update after returning
      setState(() {});
    }
  }

  // Navigate to TableOrdersScreen to view orders for a specific table
  Future<void> _navigateToTableOrders(int tableNumber) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TableOrdersScreen(tableNumber: tableNumber),
      ),
    );

    // Refresh the table state when returning
    if (mounted) {
      final tableProvider = Provider.of<TableProvider>(context, listen: false);
      tableProvider.refreshTables();
      setState(() {});
    }
  }

  // Check if there's an active (pending) order for a table
  Future<void> _checkForActiveOrder(int tableNumber, String serviceType, OrderProvider orderProvider) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
    
    try {
      // Get the order history provider
      final historyProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
      
      // Load orders for this table
      await historyProvider.loadOrdersByTable(serviceType);
      
      // Look for a pending order
      final orders = historyProvider.orders;
      final pendingOrders = orders.where((order) => 
        order.status.toLowerCase() == 'pending').toList();
      
      if (pendingOrders.isNotEmpty) {
        // Found at least one active order - close the loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
          
          // Use the first pending order
          final activeOrder = pendingOrders.first;
          
          orderProvider.setCurrentOrderId(activeOrder.id);
          orderProvider.setCurrentServiceType(serviceType);
          // Load existing items into the cart
          await orderProvider.loadExistingOrderItems(activeOrder.id);
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MenuScreen(
                serviceType: serviceType,
                existingOrderId: activeOrder.id,
              ),
            ),
          );
          return;
        }
      }
      
      // No active order found - close the loading dialog and proceed with new order
      if (context.mounted) {
        Navigator.of(context).pop();
        _navigateToMenuScreen(serviceType, orderProvider);
      }
    } catch (e) {
      // Error occurred - close the loading dialog and proceed with new order
      if (context.mounted) {
        Navigator.of(context).pop();
        debugPrint('Error checking for active orders: $e');
        _navigateToMenuScreen(serviceType, orderProvider);
      }
    }
  }
  
  // Show dialog for occupied tables
  void _showOccupiedTableDialog(int tableNumber, String serviceType, OrderProvider orderProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${'Table'.tr()} $tableNumber'),
        content: Text('Table is currently occupied. You can start a new order or view current orders.'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Navigate to view orders for this table
              _navigateToTableOrders(tableNumber);
            },
            child: Text('View Orders'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Check for active orders before creating a new one
              _checkForActiveOrder(tableNumber, serviceType, orderProvider);
            },
            child: Text('New Order'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(
    int tableNumber,
    bool isOccupied,
    OrderProvider orderProvider,
    String serviceType,
  ) {
    // Calculate appropriate font size based on columns
    final double fontSize = _columns > 6 ? 14.0 : 18.0;
    final double iconSize = _columns > 6 ? 24.0 : 36.0;
    
    return InkWell(
      onTap: () {
        if (!isOccupied) {
          _navigateToMenuScreen(serviceType, orderProvider);
        } else {
          _showOccupiedTableDialog(tableNumber, serviceType, orderProvider);
        }
      },
      child: Card(
        elevation: 2, // Reduced elevation
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Reduced border radius
        ),
        color: isOccupied ? Colors.grey.shade200 : Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_restaurant,
              size: iconSize,
              color: isOccupied ? Colors.red : Colors.blue[900],
            ),
            const SizedBox(height: 4), // Reduced spacing
            Text(
              '${'Table'.tr()} $tableNumber',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: isOccupied ? Colors.grey.shade800 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2), // Reduced spacing
            Text(
              isOccupied ? 'Occupied'.tr() : 'Available'.tr(),
              style: TextStyle(
                fontSize: fontSize - 4, // Smaller text for status
                color: isOccupied ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}