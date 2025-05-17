import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'menu_screen.dart';
// import 'table_management_screen.dart';
import 'table_orders_screen.dart'; // Import the new screen
import '../providers/order_provider.dart';
import '../providers/table_provider.dart';
import '../providers/order_history_provider.dart'; // Add this import

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
  
  // // Predefined layout options
  // final List<Map<String, dynamic>> _layoutOptions = [
  //   {'label': '3x4 Layout', 'rows': 3, 'columns': 4},
  //   {'label': '4x4 Layout', 'rows': 4, 'columns': 4},
  //   {'label': '4x5 Layout', 'rows': 4, 'columns': 5},
  //   {'label': '4x6 Layout', 'rows': 4, 'columns': 6},
  //   {'label': '4x8 Layout', 'rows': 4, 'columns': 8},
  //   {'label': '5x6 Layout', 'rows': 5, 'columns': 6},
  // ];
  
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
  
  // Save layout configuration to SharedPreferences
  // Future<void> _saveLayout(int rows, int columns) async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
      
  //     await prefs.setInt('dining_table_rows', rows);
  //     await prefs.setInt('dining_table_columns', columns);
  //   } catch (e) {
  //     debugPrint('Error saving layout settings: $e');
  //   }
  // }
  
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

  // Show layout selection dialog
  // void _showLayoutDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       // Get screen width to calculate dialog width
  //       final screenWidth = MediaQuery.of(context).size.width;
        
  //       return AlertDialog(
  //         title: const Text(
  //           'Select Table Layout',
  //           style: TextStyle(
  //             fontSize: 18, // Smaller title font
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
  //         // Make dialog narrower - only 65% of screen width
  //         content: SizedBox(
  //           width: screenWidth * 0.65,
  //           child: ListView(
  //             shrinkWrap: true,
  //             children: _layoutOptions.map((option) {
  //               return ListTile(
  //                 dense: true, // Makes the list tile more compact
  //                 title: Text(
  //                   option['label'],
  //                   style: const TextStyle(
  //                     fontSize: 14, // Smaller font for options
  //                   ),
  //                 ),
  //                 onTap: () {
  //                   setState(() {
  //                     _rows = option['rows'];
  //                     _columns = option['columns'];
  //                   });
  //                   // Save the selected layout to persist it
  //                   _saveLayout(option['rows'], option['columns']);
  //                   Navigator.pop(context);
  //                 },
  //                 trailing: (_rows == option['rows'] && _columns == option['columns']) 
  //                   ? const Icon(Icons.check, color: Colors.green, size: 18) // Smaller checkmark
  //                   : null,
  //               );
  //             }).toList(),
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: const Text(
  //               'Cancel',
  //               style: TextStyle(fontSize: 14), // Smaller font for button
  //             ),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // Method to handle table management navigation
  // Future<void> _navigateToTableManagement() async {
  //   await Navigator.of(context).push(
  //     MaterialPageRoute(
  //       builder: (context) => const TableManagementScreen(),
  //     ),
  //   );

  //   // Check if the widget is still mounted before using setState
  //   if (mounted) {
  //     // Refresh the table state when coming back from table management
  //     final tableProvider = Provider.of<TableProvider>(context, listen: false);
  //     tableProvider.refreshTables();
  //     // Force a rebuild of the current screen
  //     setState(() {});
  //   }
  // }

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
        title: const Text(
          'Dining Tables',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          // Layout selector button
          // TextButton.icon(
          //   onPressed: _showLayoutDialog,
          //   icon: const Icon(Icons.grid_view, color: Colors.black),
          //   label: Text('$_rows x $_columns', style: const TextStyle(color: Colors.black)),

          // ),
          const SizedBox(width: 10),
          // Tables management button
          // TextButton.icon(
          //   onPressed: _navigateToTableManagement,
          //   icon: const Icon(Icons.table_bar, color: Colors.black),
          //   label: const Text('Tables', style: TextStyle(color: Colors.black)),
          // ),
          const SizedBox(width: 10),
          // Refresh button to manually update table status
          // IconButton(
          //   onPressed: () {
          //     tableProvider.refreshTables();
          //     setState(() {});
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       const SnackBar(content: Text('Tables refreshed')),
          //     );
          //   },
          //   icon: const Icon(Icons.refresh, color: Colors.black),
          //   tooltip: 'Refresh tables',
          // ),
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
                  ? const Center(child: Text('No tables available. Add tables from the Tables menu.'))
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
    for (var order in orders) {
      if (order.status.toLowerCase() == 'pending') {
        // Found an active order - close the loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
          
          // Instead of showing a dialog, directly add to the existing order
          orderProvider.setCurrentOrderId(order.id);
          orderProvider.setCurrentServiceType(serviceType);
          // Load existing items into the cart
          await orderProvider.loadExistingOrderItems(order.id);
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MenuScreen(
                serviceType: serviceType,
                existingOrderId: order.id,
              ),
            ),
          );
          return;
        }
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

  // Dialog to ask if they want to add to an existing order
  // void _showAddToOrderDialog(dynamic order, int tableNumber, String serviceType, OrderProvider orderProvider) {
  //   showDialog(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       title: Text('Table $tableNumber'),
  //       content: const Text('There is an active order for this table. Would you like to add to the existing order or create a new one?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             Navigator.of(ctx).pop();
  //             _navigateToMenuScreen(serviceType, orderProvider);
  //           },
  //           child: const Text('New Order'),
  //         ),
  //         TextButton(
  //           onPressed: () {
  //             Navigator.of(ctx).pop();
  //             // Set current order ID and navigate to menu
  //             orderProvider.setCurrentOrderId(order.id);
  //             orderProvider.setCurrentServiceType(serviceType);
              
  //             Navigator.push(
  //               context,
  //               MaterialPageRoute(
  //                 builder: (context) => MenuScreen(
  //                   serviceType: serviceType,
  //                   existingOrderId: order.id,
  //                 ),
  //               ),
  //             );
  //           },
  //           child: const Text('Add to Existing'),
  //         ),
  //         TextButton(
  //           onPressed: () => Navigator.of(ctx).pop(),
  //           child: const Text('Cancel'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Show dialog for occupied tables
  void _showOccupiedTableDialog(int tableNumber, String serviceType, OrderProvider orderProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Table $tableNumber'),
        content: const Text('Table is currently occupied. You can start a new order or view current orders.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Navigate to view orders for this table
              _navigateToTableOrders(tableNumber);
            },
            child: const Text('View Orders'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Check for active orders before creating a new one
              _checkForActiveOrder(tableNumber, serviceType, orderProvider);
            },
            child: const Text('New Order'),
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
              'Table $tableNumber',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: isOccupied ? Colors.grey.shade800 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2), // Reduced spacing
            Text(
              isOccupied ? 'Occupied' : 'Available',
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