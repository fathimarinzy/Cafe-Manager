import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../services/demo_service.dart';
import 'menu_screen.dart';
import 'dining_table_screen.dart';
import 'order_list_screen.dart';
import '../utils/app_localization.dart';
import '../widgets/settings_password_dialog.dart';
import '../providers/settings_provider.dart';
import '../services/license_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isDemoExpired = false;
  bool _isLicenseExpired = false; 
  bool _isRegularUser = false;   

  @override
  void initState() {
    super.initState();
    _checkDemoStatus();
    _checkLicenseStatus(); 
  }

  // Add this method
  Future<void> _checkLicenseStatus() async {
    final licenseStatus = await LicenseService.getLicenseStatus();
    final isDemoMode = await DemoService.isDemoMode();
    
    setState(() {
      _isRegularUser = licenseStatus['isRegistered'] && !isDemoMode;
      _isLicenseExpired = licenseStatus['isExpired'];
    });

    // Show expiration dialog if license is expired for regular users
    if (_isLicenseExpired && _isRegularUser && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLicenseExpiredDialog();
      });
    }
  }

  // Add this method (same as in settings screen)
  void _showLicenseExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.access_time, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text(
                'License Expired'.tr(),
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your 1-year license has expired.\nTo continue using all features, please contact support for license renewal.'.tr(),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact Support:'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.phone, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '+968 7184 0022',
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.phone, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '+968 9906 2181',
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.phone, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '+968 7989 5704',
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.email, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'AI@simsai.tech',
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('OK'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkDemoStatus() async {
    final isDemoExpired = await DemoService.isDemoExpired();
    
    setState(() {
      _isDemoExpired = isDemoExpired;
    });

    // Show expiration dialog if demo is expired
    if (isDemoExpired && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDemoExpiredDialog();
      });
    }
  }

  void _showDemoExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.access_time, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text(
                'Demo Expired'.tr(),
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your 30-day demo period has expired.\n To continue using all features, please contact support for full registration.'.tr(),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact Support:'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.phone, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '+968 7184 0022',
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.phone, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '+968 9906 2181',
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.phone, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '+968 7989 5704',
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.email, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'AI@simsai.tech',
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('OK'.tr()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Color palette
    const Color primaryColor = Color(0xFF2E3B4E);
    const Color backgroundColor = Color(0xFFF5F7FA);
    
    // Service-specific colors
    const Color diningColor = Color(0xFF1565C0);
    const Color takeoutColor = Color(0xFF4CAF50);
    const Color deliveryColor = Color(0xFFFF9800);
    const Color driveThroughColor = Color(0xFFE57373);
    const Color cateringColor = Color(0xFFFFEB3B);
    const Color orderListColor = Color(0xFF607D8B);

    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    final crossAxisCount = isLandscape ? 3 : 2;
    
    final double aspectRatio = isLandscape 
        ? (screenSize.width / crossAxisCount) / ((screenSize.height - 120) / 2) 
        : (screenSize.width / crossAxisCount) / ((screenSize.height - 120) / 3);
    
    final horizontalPadding = screenSize.width * 0.03;
    final verticalPadding = screenSize.height * 0.02;

    final settingsProvider = Provider.of<SettingsProvider>(context);
    
    final String businessName = settingsProvider.businessName;
    final String appTitle = businessName.isNotEmpty 
        ? businessName 
        : 'appTitle'.tr();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appTitle.tr(),
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
            icon: const Icon(Icons.settings),
            tooltip: 'settings'.tr(),
            onPressed: () async {
              showDialog(
                context: context,
                builder: (_) => const SettingsPasswordDialog(),
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
                          isDisabled: _isDemoExpired,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'takeout',
                          icon: Icons.takeout_dining,
                          color: takeoutColor,
                          screenSize: screenSize,
                          isDisabled: _isDemoExpired,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'delivery',
                          icon: Icons.delivery_dining,
                          color: deliveryColor,
                          screenSize: screenSize,
                          isDisabled: _isDemoExpired,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'driveThrough',
                          icon: Icons.drive_eta,
                          color: driveThroughColor,
                          screenSize: screenSize,
                          isDisabled: _isDemoExpired,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'catering',
                          icon: Icons.cake,
                          color: cateringColor,
                          screenSize: screenSize,
                          isDisabled: _isDemoExpired,
                        ),
                        _buildServiceCard(
                          context: context,
                          title: 'orderList',
                          icon: Icons.list_alt,
                          color: orderListColor,
                          screenSize: screenSize,
                          isDisabled: _isDemoExpired,
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
    bool isDisabled = false,
  }) {
    final isLandscape = screenSize.width > screenSize.height;
    final iconSize = isLandscape 
        ? screenSize.width * 0.04
        : screenSize.width * 0.06;
    final fontSize = isLandscape 
        ? screenSize.width * 0.016
        : screenSize.width * 0.03;

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final bool shouldDisable = _isDemoExpired || (_isRegularUser && _isLicenseExpired);

    return Opacity(
      opacity: shouldDisable ? 0.3 : 1.0,
      child: InkWell(
        onTap: shouldDisable ? () {
          // Show appropriate message based on expiry type
          String message;
          if (_isDemoExpired) {
            message = 'Demo expired. Please contact support to continue using this feature.'.tr();
          } else if (_isRegularUser && _isLicenseExpired) {
            message = 'License expired. Please contact support to renew your license.'.tr();
          } else {
            message = 'Feature not available.'.tr();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red[700],
            ),
          );
        } : () {
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
            orderProvider.setCurrentServiceType(title.tr());
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => MenuScreen(serviceType: title.tr(), serviceColor: color),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: shouldDisable ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              boxShadow: shouldDisable ? [] : [
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
                    title.tr(),
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
      ),
    );
  }
}