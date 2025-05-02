import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/auth_provider.dart';
import 'menu_screen.dart';
import 'dining_table_screen.dart';
import 'order_list_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'package:cafeapp/main.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Color palette
    const Color primaryColor = Color(0xFF2E3B4E); // Dark blue-gray for app bar
    const Color backgroundColor = Color(0xFFF5F7FA); // Light gray background
    
    // Service-specific colors as requested
    const Color diningColor = Color(0xFF1565C0); // Dark blue for dining
    const Color takeoutColor = Color(0xFF4CAF50); // Green for takeout
    const Color deliveryColor = Color(0xFFFF9800); // Orange for delivery
    const Color driveThroughColor = Color(0xFFE57373); // Light red for drive through
    const Color cateringColor = Color(0xFFFFEB3B); // Yellow for catering
    const Color orderListColor = Color(0xFF607D8B); // Light charcoal for order list

    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    final crossAxisCount = isLandscape ? 3 : 2;
    
    final double aspectRatio = isLandscape 
        ? (screenSize.width / crossAxisCount) / ((screenSize.height - 120) / 2) 
        : (screenSize.width / crossAxisCount) / ((screenSize.height - 120) / 3);
    
    final horizontalPadding = screenSize.width * 0.03;
    final verticalPadding = screenSize.height * 0.02;

    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.printerConfig);
            },
            tooltip: 'Printer Settings',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout', style: TextStyle(color: primaryColor)),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        authProvider.logout();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      child: const Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
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
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: aspectRatio,
                      crossAxisSpacing: horizontalPadding * 0.8,
                      mainAxisSpacing: verticalPadding * 0.8,
                      shrinkWrap: true,
                      children: [
                        _buildServiceCard(
                          context: context,
                          title: 'Dining',
                          icon: Icons.restaurant,
                          color: diningColor,
                          isDining: true,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'Takeout',
                          icon: Icons.takeout_dining,
                          color: takeoutColor,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'Delivery',
                          icon: Icons.delivery_dining,
                          color: deliveryColor,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'Drive Through',
                          icon: Icons.drive_eta,
                          color: driveThroughColor,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'Catering',
                          icon: Icons.cake,
                          color: cateringColor,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'Order List',
                          icon: Icons.list_alt,
                          color: orderListColor,
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

  Widget _buildServiceCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    bool isDining = false,
    required Size screenSize,
  }) {
    final isLandscape = screenSize.width > screenSize.height;
    final iconSize = isLandscape 
        ? screenSize.width * 0.04
        : screenSize.width * 0.06;
    final fontSize = isLandscape 
        ? screenSize.width * 0.016
        : screenSize.width * 0.03;

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
              builder: (ctx) => MenuScreen(serviceType: title,serviceColor: color,),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(20),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(40),
                ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: color,
                ),
              ),
              SizedBox(height: screenSize.height * 0.015),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
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