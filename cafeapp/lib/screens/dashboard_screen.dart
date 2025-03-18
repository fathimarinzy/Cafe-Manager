import 'package:flutter/material.dart';
import 'menu_screen.dart';
import 'dining_table_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key}); // ✅ Added key parameter

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          ' Dashboard',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87, // Dark text color
          ),
        ),
        backgroundColor: Colors.white, // White background
        elevation: 0, // Remove shadow
        iconTheme: const IconThemeData(color: Colors.black87), // Dark icons
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              // Implement logout
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // const Text(
              //   'Select Service Type',
              //   style: TextStyle(
              //     fontSize: 24,
              //     fontWeight: FontWeight.bold,
              //     color: Colors.black87,
              //   ),
              // ),
              const SizedBox(height: 8),
              // const Text(
              //   'Choose the type of service to manage orders',
              //   style: TextStyle(
              //     fontSize: 16,
              //     color: Colors.black54,
              //   ),
              // ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: screenSize.width > 600 ? 2 : 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildServiceCard(
                      context,
                      'Dining',
                      Icons.restaurant,
                      isDining: true, // New parameter to identify Dining option
                    ),
                    _buildServiceCard(
                      context,
                      'Takeout',
                      Icons.takeout_dining,
                    ),
                    _buildServiceCard(
                      context,
                      'Delivery',
                      Icons.delivery_dining,
                    ),
                    _buildServiceCard(
                      context,
                      'Drive Through',
                      Icons.drive_eta,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context,
    String title,
    IconData icon,
    {bool isDining = false} // New parameter with default value
  ) {
    return InkWell(
      onTap: () {
       if (isDining) {
          // If Dining is selected, navigate to DiningTableScreen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => DiningTableScreen(),
            ),
          );
        } else {
          // For all other service types, navigate directly to MenuScreen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => MenuScreen(serviceType: title),
            ),
          );
        }
        },
        child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Slightly rounded corners
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white, // White background for the card
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 64,
                color: Colors.blue[900], // Blue icon color
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87, // Standard dark text color
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}