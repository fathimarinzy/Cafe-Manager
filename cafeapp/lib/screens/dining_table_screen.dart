import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'menu_screen.dart';
import 'table_management_screen.dart'; // Add this import
import '../providers/order_provider.dart';
import '../providers/table_provider.dart'; // Add this import

class DiningTableScreen extends StatefulWidget {
  const DiningTableScreen({super.key});

  @override
  State<DiningTableScreen> createState() => _DiningTableScreenState();
}

class _DiningTableScreenState extends State<DiningTableScreen> {
  late Timer _timer;
  late String _currentTime;
  
  @override
  void initState() {
    super.initState();
    _updateTime();
    // Update time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
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
        title: const Text(
          'Dining Tables',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          // Add Tables management button
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Expanded(
              child: tables.isEmpty 
                ? const Center(child: Text('No tables available. Add tables from the Tables menu.'))
                : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: tables.length,
                  itemBuilder: (context, index) {
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
                ),
            ),
          ],
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
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: isOccupied ? Colors.grey.shade200 : Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_restaurant,
              size: 36,
              color: isOccupied ? Colors.grey : Colors.blue[900],
            ),
            const SizedBox(height: 8),
            Text(
              'Table $tableNumber',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isOccupied ? Colors.grey : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isOccupied ? 'Occupied' : 'Available',
              style: TextStyle(
                fontSize: 14,
                color: isOccupied ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}