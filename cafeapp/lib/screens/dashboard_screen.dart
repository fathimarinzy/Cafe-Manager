import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import 'menu_screen.dart';
import 'dining_table_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get orientation to adjust layout
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // Calculate aspect ratio and grid parameters based on orientation
    // Lower aspect ratio in landscape makes cards wider relative to height
    final double aspectRatio = isLandscape ? 1.1 : 1.1;
    final int crossAxisCount = isLandscape ? 3 : 2; // 3 cards per row in landscape, 2 in portrait

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
          constraints: const BoxConstraints(maxWidth: 1000), // Increased max width for landscape
          padding: EdgeInsets.all(isLandscape ? 20 : 12), // More padding in landscape
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isLandscape ? 30 : 16), // More spacing in landscape
              Expanded(
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: aspectRatio,
                  crossAxisSpacing: isLandscape ? 24 : 12, // More spacing in landscape
                  mainAxisSpacing: isLandscape ? 24 : 12, // More spacing in landscape
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
                    _buildServiceCard(
                      context,
                      'Catering',
                      Icons.cake,  // Using cake icon for catering
                    ),
                    _buildServiceCard(
                      context,
                      'Order List',
                      Icons.list_alt,  // Using list icon for order list
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
    // Get current orientation to adjust icon size and padding
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final iconSize = isLandscape ? 50.0 : 45.0; // Larger icons in landscape
    final cardPadding = isLandscape ? 20.0 : 12.0; // More padding in landscape
    
    // Access OrderProvider to set the current service type when navigating
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    return InkWell(
      onTap: () {
        if (isDining) {
          // If Dining is selected, navigate to DiningTableScreen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => const DiningTableScreen(),
            ),
          );
        } else if (title == 'Order List') {
          // Handle Order List navigation
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order List functionality coming soon')),
          );
        } else {
          // For all other service types, set the service type in provider and navigate
          orderProvider.setCurrentServiceType(title);
          
          // Navigate to MenuScreen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => MenuScreen(serviceType: title),
            ),
          );
        }
      },
      
      child: Card(
        elevation: isLandscape ? 6 : 4, // Increased elevation for landscape
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isLandscape ? 18 : 12), // Larger radius in landscape
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isLandscape ? 18 : 12),
            color: Colors.white, // White background for the card
          ),
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: Colors.blue[900], // Blue icon color
              ),
              SizedBox(height: isLandscape ? 22 : 12), // More spacing in landscape
              Text(
                title,
                style: TextStyle(
                  fontSize: isLandscape ? 18 : 18, // Larger text in landscape
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