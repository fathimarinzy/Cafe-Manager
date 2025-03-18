import 'package:flutter/material.dart';
import 'dart:async';
import 'menu_screen.dart';

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
            // const Text(
            //   'Select a Table',
            //   style: TextStyle(
            //     fontSize: 24,
            //     fontWeight: FontWeight.bold,
            //     color: Colors.black87,
            //   ),
            // ),
            // const SizedBox(height: 8),
            // const Text(
            //   'Tap on a table to place an order',
            //   style: TextStyle(
            //     fontSize: 16,
            //     color: Colors.black54,
            //   ),
            // ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                itemCount: 16, // 16 tables
                itemBuilder: (context, index) {
                  final tableNumber = index + 1;
                  final bool isOccupied = index % 3 == 0; // For demo: every 3rd table is occupied
                  
                  return _buildTableCard(
                    context,
                    tableNumber,
                    isOccupied,
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
  ) {
    return InkWell(
      onTap: () {
        if (!isOccupied) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => MenuScreen(
                serviceType: 'Dining - Table $tableNumber',
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