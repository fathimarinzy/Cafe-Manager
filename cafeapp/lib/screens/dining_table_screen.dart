import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'menu_screen.dart';
import 'table_orders_screen.dart'; 
import '../providers/order_provider.dart';
import '../providers/table_provider.dart';
import '../providers/settings_provider.dart'; // Add SettingsProvider
// import '../providers/order_history_provider.dart';   
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Dining Tables'.tr(),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.grid_view_rounded, color: Colors.black87, size: 20),
            ),
            onPressed: _showLayoutDialog,
            tooltip: 'Change Layout'.tr(),
          ),
          const SizedBox(width: 8),
          // Time display
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, color: Colors.black54, size: 16),
                const SizedBox(width: 6),
                Text(
                  _currentTime,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistics / Summary Row (Optional - keep simple for now)
              Row(
                children: [
                   _buildStatusChip('Total: ${tables.length}', Colors.blueGrey),
                   const SizedBox(width: 8),
                   _buildStatusChip('Occupied: ${tables.where((t) => t.isOccupied).length}', Colors.orange),
                   const SizedBox(width: 8),
                   _buildStatusChip('Available: ${tables.where((t) => !t.isOccupied).length}', Colors.green),
                ],
              ),
              const SizedBox(height: 16), 

              Expanded(
                child: tables.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.table_restaurant_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No tables available'.tr(),
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add tables from the Tables menu.'.tr(),
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate the size for each table card based on available space
                        final double maxWidth = constraints.maxWidth;
                        final double maxHeight = constraints.maxHeight;
                        
                        // Calculate card width and height with spacing considered
                        final cardWidth = (maxWidth - ((_columns - 1) * 12)) / _columns;
                        final cardHeight = (maxHeight - ((_rows - 1) * 12)) / _rows;
                        
                        // Use a fixed aspect ratio
                        final aspectRatio = cardWidth / cardHeight;
                                          
                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
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

  Widget _buildStatusChip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[100]!),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color[800],
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showLayoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Select Table Layout'.tr(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          content: SizedBox(
            width: screenWidth * 0.4,
            child: ListView(
              shrinkWrap: true,
              children: _layoutOptions.map((option) {
                final isSelected = _rows == option['rows'] && _columns == option['columns'];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue[50] : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.grid_view, 
                      color: isSelected ? Colors.blue[700] : Colors.grey[600],
                      size: 20,
                    ),
                    title: Text(
                      option['label'].toString().tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? Colors.blue[900] : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _rows = option['rows'];
                        _columns = option['columns'];
                      });
                      _saveLayout(option['rows'], option['columns']);
                      Navigator.pop(context);
                    },
                    trailing: isSelected 
                      ? const Icon(Icons.check_circle, color: Colors.blue, size: 20)
                      : null,
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel'.tr(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _saveLayout(int rows, int columns) async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.saveAllSettings(
        tableRows: rows,
        tableColumns: columns,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dining_table_rows', rows);
      await prefs.setInt('dining_table_columns', columns);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Table layout saved'.tr()),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving layout settings: $e');
    }
  }
  
  final List<Map<String, dynamic>> _layoutOptions = [
    {'label': '3x3 Layout', 'rows': 3, 'columns': 3},
    {'label': '4x4 Layout', 'rows': 4, 'columns': 4},
    {'label': '4x5 Layout', 'rows': 4, 'columns': 5},
    {'label': '4x6 Layout', 'rows': 4, 'columns': 6},
    {'label': '4x7 Layout', 'rows': 4, 'columns': 7},
    {'label': '5x8 Layout', 'rows': 5, 'columns': 8},
  ];

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
  // Future<void> _checkForActiveOrder(int tableNumber, String serviceType, OrderProvider orderProvider) async {
  //   // Show loading indicator
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext context) {
  //       return const Center(
  //         child: CircularProgressIndicator(),
  //       );
  //     },
  //   );
    
  //   try {
  //     // Get the order history provider
  //     final historyProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
      
  //     // Load orders for this table
  //     await historyProvider.loadOrdersByTable(serviceType);
      
  //     // Look for a pending order
  //     final orders = historyProvider.orders;
  //     final pendingOrders = orders.where((order) => 
  //       order.status.toLowerCase() == 'pending').toList();
      
  //     if (pendingOrders.isNotEmpty) {
  //       // Found at least one active order - close the loading dialog
  //       if (mounted) {
  //         Navigator.of(context).pop();
          
  //         // Use the first pending order
  //         final activeOrder = pendingOrders.first;
          
  //         orderProvider.setCurrentOrderId(activeOrder.id);
  //         orderProvider.setCurrentServiceType(serviceType);
  //         // Load existing items into the cart
  //         await orderProvider.loadExistingOrderItems(activeOrder.id);
        
  //       if (mounted) { 
  //         Navigator.push(
  //           context,
  //           MaterialPageRoute(
  //             builder: (context) => MenuScreen(
  //               serviceType: serviceType,
  //               existingOrderId: activeOrder.id,
  //             ),
  //           ),
  //         );
  //       }
  //         return;
  //       }
  //     }
      
  //     // No active order found - close the loading dialog and proceed with new order
  //     if (mounted) {
  //       Navigator.of(context).pop();
  //       _navigateToMenuScreen(serviceType, orderProvider);
  //     }
  //   } catch (e) {
  //     // Error occurred - close the loading dialog and proceed with new order
  //     if (mounted) {
  //       Navigator.of(context).pop();
  //       debugPrint('Error checking for active orders: $e');
  //       _navigateToMenuScreen(serviceType, orderProvider);
  //     }
  //   }
  // }
  
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
          // TextButton(
          //   onPressed: () {
          //     Navigator.of(ctx).pop();
          //     // Check for active orders before creating a new one
          //     _checkForActiveOrder(tableNumber, serviceType, orderProvider);
          //   },
          //   child: Text('New Order'.tr()),
          // ),
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
    // Determine card styling based on state
    final Color backgroundColor = isOccupied ? const Color(0xFFFFF0F0) : Colors.white;
    final Color borderColor = isOccupied ? const Color(0xFFFFCDD2) : const Color(0xFFE0E0E0);
    final Color iconColor = isOccupied ? const Color(0xFFE57373) : const Color(0xFF81C784);
    final Color textColor = isOccupied ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    final String statusText = isOccupied ? 'Occupied'.tr() : 'Available'.tr();
    
    // Scale sizes slightly based on column count
    final double titleSize = _columns > 6 ? 14.0 : 18.0;
    
    return InkWell(
      onTap: () {
        if (!isOccupied) {
          _navigateToMenuScreen(serviceType, orderProvider);
        } else {
          _showOccupiedTableDialog(tableNumber, serviceType, orderProvider);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: isOccupied 
                  ? Colors.red.withAlpha(13) 
                  : Colors.grey.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Table Icon with Circle Background
            Container(
              padding: EdgeInsets.all(_columns > 6 ? 8 : 12),
              decoration: BoxDecoration(
                color: isOccupied ? Colors.red[50] : Colors.green[50], // Lighter background for circle
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.table_restaurant_rounded,
                size: _columns > 6 ? 20.0 : 28.0,
                color: iconColor,
              ),
            ),
            
            SizedBox(height: _columns > 6 ? 6 : 10),
            
            // Table Number
            Text(
              '${'Table'.tr()} $tableNumber',
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: _columns > 6 ? 4 : 6),
            
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isOccupied ? Colors.red[100] : Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: _columns > 6 ? 10.0 : 12.0,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}