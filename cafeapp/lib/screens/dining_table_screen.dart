import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'menu_screen.dart';
import 'table_management_screen.dart';
import '../providers/order_provider.dart';
import '../providers/table_provider.dart';

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
  
  // Predefined layout options
  final List<Map<String, dynamic>> _layoutOptions = [
    {'label': '3x4 Layout', 'rows': 3, 'columns': 4},
    {'label': '4x4 Layout', 'rows': 4, 'columns': 4},
    {'label': '4x5 Layout', 'rows': 4, 'columns': 5},
    {'label': '4x6 Layout', 'rows': 4, 'columns': 6},
    {'label': '4x8 Layout', 'rows': 4, 'columns': 8},
    {'label': '5x6 Layout', 'rows': 5, 'columns': 6},
  ];
  
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
  Future<void> _saveLayout(int rows, int columns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setInt('dining_table_rows', rows);
      await prefs.setInt('dining_table_columns', columns);
    } catch (e) {
      debugPrint('Error saving layout settings: $e');
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

  // Show layout selection dialog
  void _showLayoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Get screen width to calculate dialog width
        final screenWidth = MediaQuery.of(context).size.width;
        
        return AlertDialog(
          title: const Text(
            'Select Table Layout',
            style: TextStyle(
              fontSize: 18, // Smaller title font
              fontWeight: FontWeight.bold,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          // Make dialog narrower - only 65% of screen width
          content: SizedBox(
            width: screenWidth * 0.65,
            child: ListView(
              shrinkWrap: true,
              children: _layoutOptions.map((option) {
                return ListTile(
                  dense: true, // Makes the list tile more compact
                  title: Text(
                    option['label'],
                    style: const TextStyle(
                      fontSize: 14, // Smaller font for options
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _rows = option['rows'];
                      _columns = option['columns'];
                    });
                    // Save the selected layout to persist it
                    _saveLayout(option['rows'], option['columns']);
                    Navigator.pop(context);
                  },
                  trailing: (_rows == option['rows'] && _columns == option['columns']) 
                    ? const Icon(Icons.check, color: Colors.green, size: 18) // Smaller checkmark
                    : null,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 14), // Smaller font for button
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tableProvider = Provider.of<TableProvider>(context);
    final tables = tableProvider.tables;
    // final screenSize = MediaQuery.of(context).size;

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
          TextButton.icon(
            onPressed: _showLayoutDialog,
            icon: const Icon(Icons.grid_view, color: Colors.black),
            label: Text('$_rows x $_columns', style: const TextStyle(color: Colors.black)),

          ),
          const SizedBox(width: 10),
          // Tables management button
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TableManagementScreen(),
                ),
              ).then((_) {
                // This will refresh the screen when coming back
                setState(() {});
              });
            },
            icon: const Icon(Icons.table_bar, color: Colors.black),
            label: const Text('Tables', style: TextStyle(color: Colors.black)),
          ),
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
                              context,
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

  Widget _buildTableCard(
    BuildContext context,
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
          // Set the current service type in OrderProvider before navigation
          orderProvider.setCurrentServiceType(serviceType);
          
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => MenuScreen(
                serviceType: serviceType,
              ),
            ),
          );
        } else {
          // Show occupied message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Table $tableNumber is currently occupied'),
              backgroundColor: Colors.orange,
            ),
          );
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
              color: isOccupied ? Colors.grey : Colors.blue[900],
            ),
            const SizedBox(height: 4), // Reduced spacing
            Text(
              'Table $tableNumber',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: isOccupied ? Colors.grey : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2), // Reduced spacing
            Text(
              isOccupied ? 'Occupied' : 'Available',
              style: TextStyle(
                fontSize: fontSize - 4, // Smaller text for status
                color: isOccupied ? Colors.red : Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}