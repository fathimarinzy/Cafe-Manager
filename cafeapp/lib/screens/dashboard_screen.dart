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
import 'package:shared_preferences/shared_preferences.dart'; // Add this import


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
  bool _isModernUI = true; // Toggle between modern and classic UI
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    
    _loadUIPreference(); // Load UI preference first
    _checkDemoStatus();
    _checkLicenseStatus();
    _animationController.forward();
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }
    // Add method to load UI preference from SharedPreferences
  Future<void> _loadUIPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUIMode = prefs.getBool('is_modern_ui') ?? true; // Default to modern UI if not set
      
      if (mounted) {
        setState(() {
          _isModernUI = savedUIMode;
        });
      }
    } catch (e) {
      debugPrint('Error loading UI preference: $e');
      // Keep default value if there's an error
    }
  }

  // Add method to save UI preference to SharedPreferences
  Future<void> _saveUIPreference(bool isModern) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_modern_ui', isModern);
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
      final newUIMode = !_isModernUI;

    setState(() {
      _isModernUI = newUIMode;
    });
    // Save the preference
    _saveUIPreference(newUIMode);
    // Restart animation when switching UI modes
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return _isModernUI ? _buildModernUI() : _buildClassicUI();
  }

  Widget _buildModernUI() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final String businessName = settingsProvider.businessName;
    final String appTitle = businessName.isNotEmpty ? businessName : 'appTitle'.tr();

    return Scaffold(
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

  Widget _buildClassicUI() {
    const Color primaryColor = Color(0xFF2E3B4E);
    const Color backgroundColor = Color(0xFFF5F7FA);

    final settingsProvider = Provider.of<SettingsProvider>(context);
    final String businessName = settingsProvider.businessName;
    final String appTitle = businessName.isNotEmpty ? businessName : 'appTitle'.tr();

    return Scaffold(
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
          // UI Toggle Icon
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return RotationTransition(
                    turns: animation,
                    child: child,
                  );
                },
                child: Icon(
                  _isModernUI ? Icons.dashboard_outlined : Icons.dashboard,
                  key: ValueKey<bool>(_isModernUI),
                  color: Colors.white,
                ),
              ),
              tooltip: 'Toggle UI Style',
              onPressed: _toggleUIMode,
            ),
          ),
          // Settings Icon
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
          // UI Toggle Icon
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(15),
            ),
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return RotationTransition(
                    turns: animation,
                    child: child,
                  );
                },
                child: Icon(
                  _isModernUI ? Icons.dashboard_outlined : Icons.dashboard,
                  key: ValueKey<bool>(_isModernUI),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              onPressed: _toggleUIMode,
            ),
          ),
          // Settings Icon
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
                              // ignore: unnecessary_null_comparison
                              child: _animationController != null
                                  ? AnimatedBuilder(
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
                                    )
                                  : _buildModernServiceCard(services[serviceIndex], serviceIndex),
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

    Provider.of<OrderProvider>(context, listen: false);
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