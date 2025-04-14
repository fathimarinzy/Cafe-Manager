import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/auth_provider.dart';
import 'menu_screen.dart';
import 'dining_table_screen.dart';
import 'order_list_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen size to determine layout
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    // Calculate best grid parameters based on screen size
    final crossAxisCount = isLandscape ? 3 : 2; // 3 cards per row in landscape, 2 in portrait
    
    // Calculate aspect ratio to ensure cards fit properly
    // For landscape, we need wider cards relative to height
    // For portrait, we need taller cards relative to width
    final double aspectRatio = isLandscape 
        ? (screenSize.width / crossAxisCount) / ((screenSize.height - 120) / 2) 
        : (screenSize.width / crossAxisCount) / ((screenSize.height - 120) / 3);
    
    // Set appropriate padding based on screen size
    final horizontalPadding = screenSize.width * 0.03; // 3% of screen width
    final verticalPadding = screenSize.height * 0.02; // 2% of screen height

    // Get the auth provider to handle logout
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              // Show logout confirmation dialog
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        // Perform logout action
                        authProvider.logout();
                        // Navigate to login screen after logout
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false, // Remove all previous routes
                        );
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        // Use SafeArea to avoid notches and system UI
        child: LayoutBuilder(
          // LayoutBuilder gives us the exact constraints within the parent
          builder: (context, constraints) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: GridView.count(
                      // Disable scrolling to ensure everything fits on screen
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: aspectRatio,
                      crossAxisSpacing: horizontalPadding * 0.8,
                      mainAxisSpacing: verticalPadding * 0.8,
                      shrinkWrap: true,
                      children: [
                        _buildServiceCard(
                          context,
                          'Dining',
                          Icons.restaurant,
                          isDining: true,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context,
                          'Takeout',
                          Icons.takeout_dining,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context,
                          'Delivery',
                          Icons.delivery_dining,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context,
                          'Drive Through',
                          Icons.drive_eta,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context,
                          'Catering',
                          Icons.cake,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context,
                          'Order List',
                          Icons.list_alt,
                          screenSize: screenSize,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context,
    String title,
    IconData icon, {
    bool isDining = false,
    required Size screenSize,
  }) {
    // Responsive design - scale based on screen dimensions
    final isLandscape = screenSize.width > screenSize.height;
    
    // Calculate icon size based on screen size
    final iconSize = isLandscape 
        ? screenSize.width * 0.04 // 5% of screen width in landscape
        : screenSize.width * 0.06; // 9% of screen width in portrait
    
    // Calculate font size based on screen size
    final fontSize = isLandscape 
        ? screenSize.width * 0.016 // 1.6% of screen width in landscape
        : screenSize.width * 0.03;  // 4% of screen width in portrait
    
    // Access OrderProvider to set the current service type when navigating
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    return InkWell(
      onTap: () {
        if (isDining) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => const DiningTableScreen(),
            ),
          );
        } else if (title == 'Order List') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => const OrderListScreen(),
            ),
          );
        } else {
          orderProvider.setCurrentServiceType(title);
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
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: Colors.blue[900],
              ),
              SizedBox(height: screenSize.height * 0.015), // 1.5% of screen height
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}