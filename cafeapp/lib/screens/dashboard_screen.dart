import 'dart:io';
import 'package:cafeapp/models/order.dart';
import 'package:cafeapp/providers/auth_provider.dart';
import 'package:cafeapp/providers/logo_provider.dart';
import 'package:cafeapp/screens/login_screen.dart';
import 'package:cafeapp/screens/report_screen.dart';
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
import 'renewal_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/logo_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  bool _isDemoExpired = false;
  bool _isLicenseExpired = false;
  bool _isRegularUser = false;
  int _currentUIMode = 0; // 0: Modern, 1: Classic, 2: Sidebar , 3: Card Style
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Live clock for sidebar (replaces system uptime)
  DateTime _currentTime = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _loadUIPreference();
    _startClock();
    _checkDemoStatus();
    _checkLicenseStatus();
    _animationController.forward();
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabAnimationController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _startClock() {
    // initialize current time and update every second
    setState(() {
      _currentTime = DateTime.now();
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  String _formatTime() {
    // Format as hh:mm:ss AM/PM (12-hour)
    final hour24 = _currentTime.hour;
    final isPm = hour24 >= 12;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final h = _twoDigits(hour12);
    final m = _twoDigits(_currentTime.minute);
    final s = _twoDigits(_currentTime.second);
    final ampm = isPm ? 'PM' : 'AM';
    return '$h:$m:$s $ampm';
  }

  // Prefer a function declaration over assigning a closure to a variable
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  Future<void> _loadUIPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUIMode = prefs.getInt('ui_mode') ?? 0;
      
      if (mounted) {
        setState(() {
          _currentUIMode = savedUIMode;
        });
      }
    } catch (e) {
      debugPrint('Error loading UI preference: $e');
    }
  }

  Future<void> _saveUIPreference(int mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ui_mode', mode);
    } catch (e) {
      debugPrint('Error saving UI preference: $e');
    }
  }

  Future<void> _checkLicenseStatus() async {
    final licenseStatus = await LicenseService.getLicenseStatus();
    final isDemoMode = await DemoService.isDemoMode();

    setState(() {
      _isRegularUser = licenseStatus['isRegistered'] && !isDemoMode;
      _isLicenseExpired = licenseStatus['isExpired'];
    });

    if (_isLicenseExpired && _isRegularUser && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLicenseExpiredDialog();
      });
    }
  }

  void _showLicenseExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.access_time, color: Colors.red.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'License Expired'.tr(),
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your 1-year license has expired.\nTo continue using all features, please contact support for license renewal.'
                    .tr(),
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact Support:'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildContactRow(Icons.phone, '+968 7184 0022'),
                    _buildContactRow(Icons.phone, '+968 9906 2181'),
                    _buildContactRow(Icons.phone, '+968 7989 5704'),
                    _buildContactRow(Icons.email, 'AI@simsai.tech'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        const RenewalScreen(renewalType: RenewalType.license),
                  ),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Renew License'.tr()),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Later'.tr()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: Colors.blue.shade700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _checkDemoStatus() async {
    final isDemoExpired = await DemoService.isDemoExpired();

    setState(() {
      _isDemoExpired = isDemoExpired;
    });

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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.access_time, color: Colors.red.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Demo Expired'.tr(),
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your 30-day demo period has expired.\nTo continue using all features, upgrade your plan.'
                    .tr(),
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact Support:'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildContactRow(Icons.phone, '+968 7184 0022'),
                    _buildContactRow(Icons.phone, '+968 9906 2181'),
                    _buildContactRow(Icons.phone, '+968 7989 5704'),
                    _buildContactRow(Icons.email, 'AI@simsai.tech'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('OK'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _toggleUIMode() {
    final newUIMode = (_currentUIMode + 1) % 4;
    setState(() {
      _currentUIMode = newUIMode;
    });
    _saveUIPreference(newUIMode);
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentUIMode) {
      case 1:
        return _buildClassicUI();
      case 2:
        return _buildSidebarUI();
      case 3:
        return _buildCardStyleUI();
      default:
        return _buildModernUI();
    }
  }

  Widget _buildSidebarUI() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final String businessName = settingsProvider.businessName;
    final String secondBusinessName = settingsProvider.secondBusinessName;
    final String businessAddress = settingsProvider.businessAddress;
    final String businessPhone = settingsProvider.businessPhone;
    final orderProvider = Provider.of<OrderProvider>(context);
    
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final sidebarWidth = isTablet ? 320.0 : 280.0;

    return Scaffold(
      resizeToAvoidBottomInset: false, // This prevents keyboard from resizing the UI
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: sidebarWidth,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF667eea),
                  const Color(0xFFF5F7FA),
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: screenHeight * 0.05),
                    // Logo/Icon                
                    Consumer<LogoProvider>(
                      builder: (context, logoProvider, child) {
                        return FutureBuilder<Widget?>(
                          future: LogoService.getLogoWidget(
                            height: isTablet ? 100 : 80,
                            width: isTablet ? 100 : 80,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Container(
                                width: isTablet ? 100 : 80,
                                height: isTablet ? 100 : 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(26),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: snapshot.data!,
                                ),
                              );
                            } else {
                              return Container(
                                width: isTablet ? 100 : 80,
                                height: isTablet ? 100 : 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(26),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.local_cafe,
                                  size: isTablet ? 50 : 40,
                                  color: const Color(0xFF667eea),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                    SizedBox(height: screenHeight * 0.025),
                    // Business Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        businessName.isNotEmpty ? businessName : 'SIMS CAFE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 28 : 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        secondBusinessName.isNotEmpty ? secondBusinessName : '',
                        style: TextStyle(
                          color: Colors.white.withAlpha(204),
                          fontSize: isTablet ? 14 : 12,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),
                    // Info Cards
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
                      child: Column(
                        children: [
                          _buildInfoCard(
                            Icons.location_on,
                            'Location'.tr(),
                            businessAddress.isNotEmpty ? businessAddress : '',
                            Colors.blue.shade50,
                            isTablet,
                          ),
                          SizedBox(height: isTablet ? 16 : 12),
                          _buildInfoCard(
                            Icons.phone,
                            'Contact'.tr(),
                            businessPhone.isNotEmpty ? businessPhone : '',
                            Colors.green.shade50,
                            isTablet,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                  ],
                ),
              ),
            ),
          ),
          // Main Content Area
          Expanded(
            child: Container(
              color: const Color(0xFFF5F7FA),
              child: Column(
                children: [
                  // Top Bar with System Uptime
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 32 : 16, 
                      vertical: isTablet ? 20 : 16
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: const Color(0xFF667eea),
                          size: isTablet ? 24 : 20,
                        ),
                        SizedBox(width: isTablet ? 12 : 8),
                        Text(
                          _formatTime(),
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2D3748),
                          ),
                        ),
                        const Spacer(),
                        // UI Toggle
                        IconButton(
                          icon: Icon(
                            Icons.dashboard_customize,
                            color: const Color(0xFF667eea),
                            size: isTablet ? 24 : 20,
                          ),
                          onPressed: _toggleUIMode,
                          tooltip: 'Toggle UI Style',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF5F7FA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(width: isTablet ? 12 : 8),
                        IconButton(
                          icon: Icon(
                            Icons.logout,
                            color: const Color(0xFF667eea),
                            size: isTablet ? 24 : 20,
                          ),
                          onPressed: () {
                            _showLogoutDialogWithReport();
                           
                          },
                          tooltip: 'Logout',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF5F7FA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(width: isTablet ? 12 : 8),
                        // Settings
                        IconButton(
                          icon: Icon(
                            Icons.settings,
                            color: const Color(0xFF667eea),
                            size: isTablet ? 24 : 20,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const SettingsPasswordDialog(),
                            );
                          },
                          tooltip: 'Settings',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF5F7FA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Service Cards Grid
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(isTablet ? 32 : 16),
                      child: _buildSidebarServiceCards(orderProvider, screenWidth, screenHeight, isTablet),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String subtitle, Color bgColor, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 12 : 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF667eea),
              size: isTablet ? 20 : 18,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarServiceCards(OrderProvider orderProvider, double screenWidth, double screenHeight, bool isTablet) {
    final services = [
      SidebarServiceItem('dining', Icons.restaurant, const Color(0xFFE63946),  'Manage dine-in orders'.tr(), true),
      SidebarServiceItem('delivery', Icons.delivery_dining, const Color(0xFF1D9BF0),  'Track delivery orders'.tr()),
      SidebarServiceItem('driveThrough', Icons.drive_eta, const Color(0xFF9333EA),  'Quick drive-through service'.tr()),
      SidebarServiceItem('catering', Icons.cake, const Color(0xFFF97316),  'Large event orders'.tr()),
      SidebarServiceItem('takeout', Icons.takeout_dining, const Color(0xFF10B981),  'Pickup orders ready'.tr()),
      SidebarServiceItem('orderList', Icons.list_alt, const Color(0xFF4B5563),  'View all orders'.tr()),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate card dimensions similar to modern UI
        const int crossAxisCount = 3;
        const int mainAxisCount = 2;
        const double horizontalSpacing = 24.0;
        const double verticalSpacing = 24.0;
        
        return Column(
          children: List.generate(mainAxisCount, (rowIndex) {
            return Expanded(
              child: Row(
                children: List.generate(crossAxisCount, (colIndex) {
                  final serviceIndex = (rowIndex * crossAxisCount) + colIndex;
                  if (serviceIndex >= services.length) {
                    return Expanded(child: Container());
                  }
                  
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        right: colIndex < crossAxisCount - 1 ? horizontalSpacing : 0,
                        bottom: rowIndex < mainAxisCount - 1 ? verticalSpacing : 0,
                      ),
                      child: _buildSidebarServiceCard(services[serviceIndex], orderProvider, isTablet),
                    ),
                  );
                }),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSidebarServiceCard(SidebarServiceItem service, OrderProvider orderProvider, bool isTablet) {
    final bool shouldDisable = _isDemoExpired || (_isRegularUser && _isLicenseExpired);

    return InkWell(
      onTap: shouldDisable ? _showDisabledMessage : () => _navigateToServiceFromSidebar(service, orderProvider),
      borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
      child: Container(
        decoration: BoxDecoration(
          // color: Colors.white,
          color: shouldDisable ? Colors.grey.shade300 : Colors.white,
          borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: EdgeInsets.all(isTablet ? 24 : 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isTablet ? 12 : 10),
                        decoration: BoxDecoration(
                          color: service.color.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          service.icon,
                          color: service.color,
                          size: isTablet ? 24 : 20,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    service.title.tr(),
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isTablet ? 4 : 2),
                  Flexible(
                    child: Text(
                      service.subtitle,
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: isTablet ? 12 : 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 8 : 6),
                      decoration: BoxDecoration(
                        // color: Colors.grey.shade900,
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        // color: Colors.white,
                        color: Colors.black,
                        size: isTablet ? 16 : 14,
                      ),
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

  void _navigateToServiceFromSidebar(SidebarServiceItem service, OrderProvider orderProvider) {
    if (service.isDining) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const DiningTableScreen()),
      );
    } else if (service.title == 'orderList') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const OrderListScreen()),
      );
    } else {
      orderProvider.setCurrentServiceType(service.title.tr());
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MenuScreen(serviceType: service.title.tr(), serviceColor: service.color),
        ),
      );
    }
  }

  Widget _buildModernUI() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final String businessName = settingsProvider.businessName;
    final String appTitle = businessName.isNotEmpty ? businessName : 'appTitle'.tr();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
              Colors.deepPurple.shade300,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(appTitle),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _buildServiceGrid(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar(String appTitle) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  appTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(15),
            ),
            child: IconButton(
              icon: const Icon(Icons.dashboard_customize, color: Colors.white, size: 24),
              onPressed: _toggleUIMode,
            ),
          ),
           Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(15),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white, size: 24),
              onPressed: () {
                _showLogoutDialogWithReport();
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(15),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white, size: 24),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const SettingsPasswordDialog(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceGrid() {
    final services = [
      ServiceItem('dining', Icons.restaurant, const Color(0xFF1565C0), true),
      ServiceItem('takeout', Icons.takeout_dining, const Color(0xFF4CAF50)),
      ServiceItem('delivery', Icons.delivery_dining, const Color(0xFFFF9800)),
      ServiceItem('driveThrough', Icons.drive_eta, const Color(0xFFE57373)),
      ServiceItem('catering', Icons.cake, const Color(0xFFFFEB3B)),
      ServiceItem('orderList', Icons.list_alt, const Color(0xFF607D8B)),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = MediaQuery.of(context).size.width;
                final screenHeight = MediaQuery.of(context).size.height;
                final isTablet = screenWidth > 600;
                final isPortrait = screenHeight > screenWidth;
                
                int crossAxisCount;
                int mainAxisCount;
                
                if (isTablet) {
                  if (isPortrait) {
                    crossAxisCount = 2;
                    mainAxisCount = 3;
                  } else {
                    crossAxisCount = 3;
                    mainAxisCount = 2;
                  }
                } else {
                  crossAxisCount = 2;
                  mainAxisCount = 3;
                }
                
                const horizontalPadding = 16.0;
                const verticalPadding = 16.0;
                
                return Column(
                  children: List.generate(mainAxisCount, (rowIndex) {
                    return Expanded(
                      child: Row(
                        children: List.generate(crossAxisCount, (colIndex) {
                          final serviceIndex = (rowIndex * crossAxisCount) + colIndex;
                          if (serviceIndex >= services.length) {
                            return Expanded(child: Container());
                          }
                          
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                right: colIndex < crossAxisCount - 1 ? horizontalPadding : 0,
                                bottom: rowIndex < mainAxisCount - 1 ? verticalPadding : 0,
                              ),
                              child: AnimatedBuilder(
                                animation: _animationController,
                                builder: (context, child) {
                                  final animationValue = Curves.easeOutCubic.transform(
                                    (_animationController.value - (serviceIndex * 0.1)).clamp(0.0, 1.0),
                                  );
                                  return Transform.translate(
                                    offset: Offset(0, 30 * (1 - animationValue)),
                                    child: Opacity(
                                      opacity: animationValue,
                                      child: _buildModernServiceCard(services[serviceIndex], serviceIndex),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernServiceCard(ServiceItem service, int index) {
    final bool shouldDisable = _isDemoExpired || (_isRegularUser && _isLicenseExpired);

    return Hero(
      tag: 'service_${service.title}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: shouldDisable ? _showDisabledMessage : () => _navigateToService(service),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: shouldDisable
                  ? LinearGradient(
                      colors: [Colors.grey.shade300, Colors.grey.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        service.color.withAlpha(204),
                        service.color,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              boxShadow: shouldDisable
                  ? []
                  : [
                      BoxShadow(
                        color: service.color.withAlpha(77),
                        spreadRadius: 0,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(26),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          service.icon,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        service.title.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                if (shouldDisable)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.black.withAlpha(77),
                    ),
                    child: const Center(
                      // child: Icon(
                      //   Icons.lock,
                      //   color: Colors.white,
                      //   size: 30,
                      // ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassicUI() {
    const Color primaryColor = Color(0xFF2E3B4E);
    const Color backgroundColor = Color(0xFFF5F7FA);

    final settingsProvider = Provider.of<SettingsProvider>(context);
    final String businessName = settingsProvider.businessName;
    final String appTitle = businessName.isNotEmpty ? businessName : 'appTitle'.tr();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          appTitle,
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
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.dashboard_customize, color: Colors.white),
              tooltip: 'Toggle UI Style'.tr(),
              onPressed: _toggleUIMode,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout'.tr(),
            onPressed: () async {
              _showLogoutDialogWithReport();
            },
          ),
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
        child: _buildClassicGrid(),
      ),
    );
  }

  Widget _buildClassicGrid() {
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

    return LayoutBuilder(
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
                    _buildClassicServiceCard(
                      context: context,
                      title: 'dining',
                      icon: Icons.restaurant,
                      color: diningColor,
                      isDining: true,
                      screenSize: screenSize,
                      isDisabled: _isDemoExpired,
                    ),
                    _buildClassicServiceCard(
                      context: context,
                      title: 'takeout',
                      icon: Icons.takeout_dining,
                      color: takeoutColor,
                      screenSize: screenSize,
                      isDisabled: _isDemoExpired,
                    ),
                    _buildClassicServiceCard(
                      context: context,
                      title: 'delivery',
                      icon: Icons.delivery_dining,
                      color: deliveryColor,
                      screenSize: screenSize,
                      isDisabled: _isDemoExpired,
                    ),
                    _buildClassicServiceCard(
                      context: context,
                      title: 'driveThrough',
                      icon: Icons.drive_eta,
                      color: driveThroughColor,
                      screenSize: screenSize,
                      isDisabled: _isDemoExpired,
                    ),
                    _buildClassicServiceCard(
                      context: context,
                      title: 'catering',
                      icon: Icons.cake,
                      color: cateringColor,
                      screenSize: screenSize,
                      isDisabled: _isDemoExpired,
                    ),
                    _buildClassicServiceCard(
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
    );
  }

  Widget _buildClassicServiceCard({
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

    final bool shouldDisable = _isDemoExpired || (_isRegularUser && _isLicenseExpired);

    return Opacity(
      opacity: shouldDisable ? 0.3 : 1.0,
      child: InkWell(
        onTap: shouldDisable ? _showDisabledMessage : () => _navigateToServiceClassic(title, color, isDining),
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: shouldDisable ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              // color: Colors.white,
              color: shouldDisable ? Colors.grey.shade300 : Colors.white,
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
  // New Card Style UI (4th UI Mode)
Widget _buildCardStyleUI() {
  final settingsProvider = Provider.of<SettingsProvider>(context);
  final String businessName = settingsProvider.businessName;
  final String appTitle = businessName.isNotEmpty ? businessName : 'SIMS CAFE';

  return Scaffold(
    resizeToAvoidBottomInset: false,
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: Text(
        appTitle,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          letterSpacing: 2,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.dashboard_customize, color: Colors.black87),
          onPressed: _toggleUIMode,
          tooltip: 'Toggle UI Style',
        ),
        IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: _showLogoutDialogWithReport,
            tooltip: 'Logout',
          ),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.black87),
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => const SettingsPasswordDialog(),
            );
          },
          tooltip: 'Settings',
        ),
      ],
    ),
    body: SafeArea(
     child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isTablet = screenWidth > 600;
          final logoSize = isTablet ? 80.0 : 70.0; 
        return Stack(
          children: [
            // Main Content
            _buildCardStyleContent(),
            // Business Logo in top left corner
           Positioned(
            top: isTablet ? 5 : 9,
            left: isTablet ? 55 : 45,
            child: Consumer<LogoProvider>(
              builder: (context, logoProvider, child) {
                return Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: logoProvider.hasLogo && logoProvider.logoPath != null
                        ? Image.file(
                            File(logoProvider.logoPath!),
                            // CRITICAL: ValueKey with timestamp to force rebuild
                            key: ValueKey('dashboard_logo_${logoProvider.lastUpdateTimestamp}'),
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback to default icon on error
                              return Icon(
                                Icons.business,
                                size: logoSize * 0.5,
                                color: Colors.blue[700],
                              );
                            },
                          )
                        : Icon(
                            Icons.local_cafe,
                            size: logoSize * 0.5,
                            color: Colors.blue[700],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              ],
            );
          },
        ),
      ),
    );
  }

void _showLogoutDialogWithReport() {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 450,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // X Close Button at top right
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 24,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
              Icon(
                Icons.logout,
                size: 35,
                color: Colors.blue.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                'Logout'.tr(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Are you sure you want to logout?'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                'Do you want to see the report before logging out?'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // View Report Button
                  Flexible(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ReportScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text('Report'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Logout Button
                  Flexible(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        authProvider.logout();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
    ),
  );
}
Widget _buildCardStyleContent() {
  return LayoutBuilder(
    builder: (context, constraints) {
      
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top row with Dining, Delivery, and Pie Chart
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardStyleButton(
                    'dining',
                    Icons.restaurant,
                    const Color(0xFFFF8C42),
                    200,
                    200,
                    true,
                  ),
                  const SizedBox(width: 20),
                  _buildCardStyleButton(
                    'delivery',
                    Icons.moped,
                    const Color(0xFF4A6FA5),
                    200,
                    200,
                    false,
                  ),
                  const SizedBox(width: 20),
                  _buildPieChart(),
                ],
              ),
              const SizedBox(height: 20),
              // Second row with Takeout and Drive Through
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardStyleButton(
                    'takeout',
                    Icons.shopping_bag,
                    const Color(0xFF4CAF50),
                    200,
                    200,
                    false,
                  ),
                  const SizedBox(width: 20),
                  _buildCardStyleButton(
                    'driveThrough',
                    Icons.drive_eta,
                    const Color(0xFF757575),
                    200,
                    200,
                    false,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Third row with Order List and Catering
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCardStyleButton(
                    'orderList',
                    Icons.list_alt,
                   const Color(0xFF9E9E9E),
                    420,
                    120,
                    false,
                  ),
                  const SizedBox(width: 20),
                  _buildCardStyleButton(
                    'catering',
                    Icons.cake,
                    const Color(0xFFFFA726),
                    200,
                    120,
                    false,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildCardStyleButton(
  String title,
  IconData icon,
  Color color,
  double width,
  double height,
  bool isDining,
) {
  final bool shouldDisable = _isDemoExpired || (_isRegularUser && _isLicenseExpired);
   // Adjust padding and icon size based on height
    final isShortCard = height <= 120;
    final iconSize = isShortCard ? 40.0 : 50.0;
    final padding = isShortCard ? 16.0 : 24.0;
    final fontSize = isShortCard ? 20.0 : 24.0;
    final spacing = isShortCard ? 8.0 : 12.0;

  return InkWell(
    onTap: shouldDisable ? _showDisabledMessage : () => _navigateToServiceCardStyle(title, color, isDining),
    borderRadius: BorderRadius.circular(20),
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: shouldDisable ? Colors.grey.shade300 : color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shouldDisable ? [] : [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: Colors.white,
                ),
                SizedBox(height: spacing),
               
                Flexible(
                 child: Text(
                  title.tr(),
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                 ),
                ),
              ],
            ),
          ),
          if (shouldDisable)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black.withAlpha(77),
              ),
              child: const Center(
                // child: Icon(
                //   Icons.lock,
                //   color: Colors.white,
                //   size: 40,
                // ),
              ),
            ),
        ],
      ),
    ),
  );
}

Widget _buildPieChart() {
  return FutureBuilder<List<Order>>(
      future: Provider.of<OrderProvider>(context, listen: false).fetchOrders(),
      builder: (context, snapshot) {
        int diningCount = 0;
        int takeoutCount = 0;
        int deliveryCount = 0;
        int cateringCount = 0;
        int driveThroughCount = 0;
        
        if (snapshot.hasData && snapshot.data != null) {
          // Calculate order counts for each service type
          for (var order in snapshot.data!) {
            final serviceType = order.serviceType.toLowerCase();
            if (serviceType.contains('dining')) {
              diningCount++;
            } else if (serviceType.contains('takeout')) {
              takeoutCount++;
            } else if (serviceType.contains('delivery')) {
              deliveryCount++;
            } else if (serviceType.contains('catering')) {
              cateringCount++;
            } else if (serviceType.contains('drive') || serviceType.contains('through')) {
              driveThroughCount++;
            }
          }
        }
        
        final totalOrders = diningCount + takeoutCount + deliveryCount + cateringCount + driveThroughCount;
        
  return Container(
    width: 200,
    height: 200,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(51),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: CustomPaint(
      painter: PieChartPainter(
         diningCount: diningCount,
        takeoutCount: takeoutCount,
        deliveryCount: deliveryCount,
        cateringCount: cateringCount,
        driveThroughCount: driveThroughCount,
        totalOrders: totalOrders,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(const Color(0xFFFF8C42), 'Dining', diningCount),
                  const SizedBox(height: 4),
                  _buildLegendItem(const Color(0xFF4CAF50), 'Takeout', takeoutCount),
                  const SizedBox(height: 4),
                  _buildLegendItem(const Color(0xFF4A6FA5), 'Delivery', deliveryCount),
                  const SizedBox(height: 4),
                  _buildLegendItem(const Color(0xFFFFA726), 'Catering', cateringCount),
                  const SizedBox(height: 4),
                  _buildLegendItem(const Color(0xFF757575), 'Drive', driveThroughCount),
          ],
        ),
      ),
    ),
  );
},
);
}
  Widget _buildLegendItem(Color color, String label, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
void _navigateToServiceCardStyle(String title, Color color, bool isDining) {
  final orderProvider = Provider.of<OrderProvider>(context, listen: false);

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
}

  void _showDisabledMessage() {
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
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _navigateToService(ServiceItem service) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    if (service.isDining) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const DiningTableScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeInOutCubic)),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } else if (service.title == 'orderList') {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const OrderListScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeInOutCubic)),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } else {
      orderProvider.setCurrentServiceType(service.title.tr());
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              MenuScreen(serviceType: service.title.tr(), serviceColor: service.color),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeInOutCubic)),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  void _navigateToServiceClassic(String title, Color color, bool isDining) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

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
  }
}
// Custom Painter for Pie Chart (ADD THIS OUTSIDE THE CLASS)
class PieChartPainter extends CustomPainter {
  final int diningCount;
  final int takeoutCount;
  final int deliveryCount;
  final int cateringCount;
  final int driveThroughCount;
  final int totalOrders;

  PieChartPainter({
    required this.diningCount,
    required this.takeoutCount,
    required this.deliveryCount,
    required this.cateringCount,
    required this.driveThroughCount,
    required this.totalOrders,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalOrders == 0) {
      // Draw a gray circle if no orders
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.grey.shade300;
      final center = Offset(size.width / 2, size.height / 2);
      final radius = size.width / 2;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    double startAngle = -3.14159 / 2; // Start from top

    // Define colors for each service type
    final colors = [
      const Color(0xFFFF8C42), // Dining - Orange
      const Color(0xFF4CAF50), // Takeout - Green
      const Color(0xFF4A6FA5), // Delivery - Blue
      const Color(0xFFFFA726), // Catering - Light Orange
      const Color(0xFF757575), // Drive Through - Gray
    ];

    final counts = [
      diningCount,
      takeoutCount,
      deliveryCount,
      cateringCount,
      driveThroughCount,
    ];

    // Draw each segment
    for (int i = 0; i < counts.length; i++) {
      if (counts[i] > 0) {
        paint.color = colors[i];
        final sweepAngle = (counts[i] / totalOrders) * 2 * 3.14159;
        
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          true,
          paint,
        );
        
        startAngle += sweepAngle;
      }
    }
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return oldDelegate.diningCount != diningCount ||
        oldDelegate.takeoutCount != takeoutCount ||
        oldDelegate.deliveryCount != deliveryCount ||
        oldDelegate.cateringCount != cateringCount ||
        oldDelegate.driveThroughCount != driveThroughCount ||
        oldDelegate.totalOrders != totalOrders;
  }
}
class ServiceItem {
  final String title;
  final IconData icon;
  final Color color;
  final bool isDining;

  ServiceItem(this.title, this.icon, this.color, [this.isDining = false]);
}

class SidebarServiceItem {
  final String title;
  final IconData icon;
  final Color color;
  final String subtitle;
  final bool isDining;

  SidebarServiceItem(
    this.title,
    this.icon,
    this.color,
    this.subtitle, [
    this.isDining = false,
  ]);
}