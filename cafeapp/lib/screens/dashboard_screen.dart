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
  int _currentUIMode = 0; // 0: Modern, 1: Classic, 2: Sidebar
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // System uptime tracking
  DateTime? _systemStartTime;
  Timer? _uptimeTimer;
  Duration _systemUptime = Duration.zero;

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
    _loadSystemStartTime();
    _startUptimeTimer();
    _checkDemoStatus();
    _checkLicenseStatus();
    _animationController.forward();
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabAnimationController.dispose();
    _uptimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSystemStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final startTimeMillis = prefs.getInt('system_start_time');
    
    if (startTimeMillis == null) {
      _systemStartTime = DateTime.now();
      await prefs.setInt('system_start_time', _systemStartTime!.millisecondsSinceEpoch);
    } else {
      _systemStartTime = DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
    }
    
    _calculateUptime();
  }

  void _calculateUptime() {
    if (_systemStartTime != null) {
      setState(() {
        _systemUptime = DateTime.now().difference(_systemStartTime!);
      });
    }
  }

  void _startUptimeTimer() {
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateUptime();
    });
  }

  String _formatUptime() {
    final days = _systemUptime.inDays;
    final hours = _systemUptime.inHours % 24;
    final minutes = _systemUptime.inMinutes % 60;
    final seconds = _systemUptime.inSeconds % 60;
    
    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else {
      return '${minutes}m ${seconds}s';
    }
  }

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
    final newUIMode = (_currentUIMode + 1) % 3;
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
                    FutureBuilder<Widget?>(
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
                            'Location',
                            businessAddress.isNotEmpty ? businessAddress : '',
                            Colors.blue.shade50,
                            isTablet,
                          ),
                          SizedBox(height: isTablet ? 16 : 12),
                          _buildInfoCard(
                            Icons.phone,
                            'Contact',
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
                          _formatUptime(),
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
      SidebarServiceItem('dining', Icons.restaurant, const Color(0xFFE63946),  'Manage dine-in orders', true),
      SidebarServiceItem('delivery', Icons.delivery_dining, const Color(0xFF1D9BF0),  'Track delivery orders'),
      SidebarServiceItem('driveThrough', Icons.drive_eta, const Color(0xFF9333EA),  'Quick drive-through service'),
      SidebarServiceItem('catering', Icons.cake, const Color(0xFFF97316),  'Large event orders'),
      SidebarServiceItem('takeout', Icons.takeout_dining, const Color(0xFF10B981),  'Pickup orders ready'),
      SidebarServiceItem('orderList', Icons.list_alt, const Color(0xFF4B5563),  'View all orders'),
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
          color: Colors.white,
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
                      child: Icon(
                        Icons.lock,
                        color: Colors.white,
                        size: 30,
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