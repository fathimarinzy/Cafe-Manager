// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/auth_provider.dart';
import 'menu_screen.dart';
import 'dining_table_screen.dart';
import 'order_list_screen.dart';
import 'login_screen.dart';
import '../utils/app_localization.dart'; // Import the localization utility
import 'package:cafeapp/main.dart';
import '../widgets/settings_password_dialog.dart';

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
        title: Text(
          'appTitle'.tr(), // Translated app title
          style: const TextStyle(
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
            tooltip: 'printerSettings'.tr(), // Translated tooltip
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'settings'.tr(), // Translated tooltip
            onPressed: () {
               // Show password dialog before navigating to settings
              showDialog(
                context: context,
                builder: (_) => const SettingsPasswordDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => Dialog(
                  // Add this to constrain and control the dialog size
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  // Control the dialog size with insets
                  insetPadding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.15, // 70% width
                    vertical: MediaQuery.of(context).size.height * 0.3   // 40% height
                  ),
                  child: Container(
                    // Explicit dimensions for the dialog content
                    width: 400,
                    padding: const EdgeInsets.all(24), // Increased padding for more space
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Logout'.tr(), 
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 22, // Increased font size
                            fontWeight: FontWeight.bold,
                          )
                        ),
                        const SizedBox(height: 20), // More space
                        Text(
                          'Are you sure you want to logout?'.tr(),
                          style: const TextStyle(
                            fontSize: 16, // Increased font size
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32), // More space
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Space buttons evenly
                          children: [
                            SizedBox(
                              width: 120, // Fixed width for buttons
                              height: 48, // Taller buttons
                              child: TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey,
                                  textStyle: const TextStyle(fontSize: 16), // Larger text
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                child: Text('Cancel'.tr()),
                              ),
                            ),
                            SizedBox(
                              width: 120, // Fixed width for buttons
                              height: 48, // Taller buttons
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  authProvider.logout();
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                    (route) => false,
                                  );
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.red.shade50, // Background color
                                  foregroundColor: Colors.red,
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Larger text
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: Colors.red.shade200),
                                  ),
                                ),
                                child: Text('Logout'.tr()),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
                          title: 'dining',
                          icon: Icons.restaurant,
                          color: diningColor,
                          isDining: true,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'takeout',
                          icon: Icons.takeout_dining,
                          color: takeoutColor,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'delivery',
                          icon: Icons.delivery_dining,
                          color: deliveryColor,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'driveThrough',
                          icon: Icons.drive_eta,
                          color: driveThroughColor,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'catering',
                          icon: Icons.cake,
                          color: cateringColor,
                          screenSize: screenSize,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'orderList',
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
        } else if (title == 'orderList') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => const OrderListScreen(),
            ),
          );
        } else {
          orderProvider.setCurrentServiceType(title.tr()); // Translate service type
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => MenuScreen(serviceType: title.tr(), serviceColor: color),
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
                  title.tr(), // Translate the service card title
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