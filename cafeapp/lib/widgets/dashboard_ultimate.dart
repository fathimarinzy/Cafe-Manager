import 'package:cafeapp/utils/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io'; // Import for Platform check


import '../providers/logo_provider.dart';
import '../services/logo_service.dart';
import '../providers/order_provider.dart';
import '../providers/table_provider.dart';
import '../models/order.dart';
import '../screens/quotations_list_screen.dart';


class DashboardUltimate extends StatefulWidget {
  final VoidCallback onDiningTap;
  final VoidCallback onDeliveryTap;
  final VoidCallback onTakeoutTap;
  final VoidCallback onDriveThroughTap;
  final VoidCallback onCateringTap;
  final VoidCallback onDelivery2Tap; // Online Order
  final VoidCallback onOrdersTap;
  final VoidCallback? onUISwitch;
  final VoidCallback? onReportsTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onExpensesTap; // Callback for Expenses
  final VoidCallback? onLogoutTap;
  final String businessName;
  final bool forceSquareLayout; // New parameter to force 7th UI

  const DashboardUltimate({
    super.key,
    required this.onDiningTap,
    required this.onDeliveryTap,
    required this.onTakeoutTap,
    required this.onDriveThroughTap,
    required this.onCateringTap,
    required this.onDelivery2Tap,
    required this.onOrdersTap,
    this.onUISwitch,
    this.onReportsTap,
    this.onSettingsTap,
    this.onSearchTap,
    this.onExpensesTap,
    this.onLogoutTap,
    this.businessName = "SIMS CAFE",
    this.forceSquareLayout = false, // Default false
  });

  @override
  State<DashboardUltimate> createState() => _DashboardUltimateState();
}

class _DashboardUltimateState extends State<DashboardUltimate> with TickerProviderStateMixin {
  String _timeString = "";
  late Timer _timer;
  late AnimationController _bgController;

  // Animation Controller for Logo Pulse
//   late final AnimationController _logoPulseController;
//   late final Animation<double> _logoScaleAnimation;

  @override
  void initState() {
    super.initState();
    _timeString = _formatTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
    
    _bgController = AnimationController(
       vsync: this,
       // Slow down animation on Android to save resources, or keep normal on Desktop
       duration: Duration(seconds: Platform.isAndroid ? 20 : 10),
    )..repeat(reverse: true);


    // Initialize Logo Pulse
    // _logoPulseController = AnimationController(
    //   duration: const Duration(seconds: 2),
    //   vsync: this,
    // )..repeat(reverse: true);

    // _logoScaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
    //   CurvedAnimation(parent: _logoPulseController, curve: Curves.easeInOut),
    // );
  }

  void _updateTime() {
    final String formattedDateTime = _formatTime();
    if (mounted) {
      setState(() {
        _timeString = formattedDateTime;
      });
    }
  }

  String _formatTime() {
    return DateFormat('hh:mm a').format(DateTime.now());
  }

  @override
  void dispose() {
    _timer.cancel();
    _bgController.dispose();
    // _logoPulseController.dispose(); // Dispose pulse controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // Enable dynamic blobs on Non-Android OR Android Tablets (>600 width)
    final showBlobs = !Platform.isAndroid || screenWidth > 600;

    final aspectRatio = screenWidth / screenHeight;
    // Square POS Detection: 
    // Typical Square POS is 1:1 or 4:3 (1.33). Standard Wide is 16:9 (1.77).
    // Let's define "Square-ish" as aspectRatio < 1.4 AND it's a "Desktop/Tablet" width (> 600)
    // Add override from widget param
    final isSquarePOS = widget.forceSquareLayout || (screenWidth > 600 && aspectRatio < 1.4);

    return Scaffold(
      // Mobile Bottom Bar (Replaces Sidebar)
      bottomNavigationBar: null,
      extendBody: true, // Allow body to extend behind bottom bar
      body: Stack(
        children: [
          // 1. Background (Glacial Frost - Deep Cool Tech)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF0F172A), // Slate 900
                  Color(0xFF1E293B), // Slate 800
                  Color(0xFF0F172A), // Slate 900
                ],
              ),
            ),
          ),
          
          // Animated Blobs - 1 (Icy Cyan) - Optimized for Android
          if (showBlobs) // Disable dynamic blobs on Android Phones to save GPU
            AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) {
                 return Positioned(
                  top: -150 + (_bgController.value * 60),
                  right: -100 - (_bgController.value * 30),
                  child: Container(
                    width: 700,
                    height: 700,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF06B6D4).withAlpha(51), // Cyan
                          Colors.transparent,
                        ],
                        radius: 0.6,
                      ),
                    ),
                  ),
                );
              }
            )
          else 
             // Static simplified background for Android
             Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF06B6D4).withAlpha(25), // Lower opacity static
                      Colors.transparent,
                    ],
                    radius: 0.6,
                  ),
                ),
              ),
            ),

          
          // Animated Blobs - 2 (Deep Blue)
          if (showBlobs)
            AnimatedBuilder(
               animation: _bgController,
               builder: (context, child) {
                 return Positioned(
                  bottom: -200 - (_bgController.value * 40),
                  left: -200 - (_bgController.value * 50),
                  child: Container(
                    width: 900,
                    height: 900,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF3B82F6).withAlpha(38), // Blue
                          Colors.transparent,
                        ],
                        radius: 0.6,
                      ),
                    ),
                  ),
                );
               }
            ),


          // Animated Blobs - 3 (Silver/White Glow)
          if (showBlobs)
            AnimatedBuilder(
               animation: _bgController,
               builder: (context, child) {
                 return Positioned(
                  top: 250,
                  left: 50 + (_bgController.value * 20),
                  child: Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFE2E8F0).withAlpha(25), // Slate 200 (Silver)
                          Colors.transparent,
                        ],
                        radius: 0.6,
                      ),
                    ),
                  ),
                );
               }
            ),

          
          // 2. Main Layout (Responsive)
          if (screenWidth < 600)
             _buildPhoneLayout(context)
          else if (isSquarePOS)
             _buildSquarePOSLayout(context) // New Specific Square POS Layout
          else if (screenWidth < 1100)
             _buildTabletLayout(context)
          else
            Row(
            children: [
              _buildSidebar(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
                  child: Column(
                    children: [
                      _buildHeader(isMobile: false),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main Content (Stats + Services)
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  _buildStatsRow(context, isMobile: false),
                                  const SizedBox(height: 24),
                                  Expanded(child: _buildServicesGrid(isPhone: false)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Right Panel (Recent Activity)
                            Expanded(
                              flex: 1,
                              child: _buildRightPanel(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Mobile Specific Layouts ---



  // --- Layouts ---

  /// 1. Phone Layout (< 600dp)
  /// Fixed layout, no scrolling (performance optimized), 2-column grid.
  Widget _buildPhoneLayout(BuildContext context) {
    return SafeArea(
      bottom: false, 
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  _buildHeader(isMobile: true),
                  const SizedBox(height: 16),
                  _buildStatsRow(context, isMobile: true),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildServicesGrid(isMobile: true, isPhone: true), // 2-Col Grid
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: _AnimatedOrderListButton(onTap: widget.onOrdersTap),
          ),
        ],
      ),
    );
  }

  /// 2. Square POS Layout (Similar to Tablet but optimized for 1:1)
  /// Uses a vertical stack approach because Sidebar takes too much space
  /// 2. Square POS Layout (1:1 Aspect Ratio)
  /// Uses standard Sidebar + Main Content, but HIDDEN Right Panel to fit square screen.
  /// 2. Square POS Layout (1:1 Aspect Ratio)
  /// Uses standard Sidebar + Main Content + Right Panel
  /// Optimized with Flex factors to fit narrow width (1024px)
  Widget _buildSquarePOSLayout(BuildContext context) {
    return Row(
      children: [
        _buildSidebar(context),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
            child: Column(
              children: [
                _buildHeader(isMobile: false),
                const SizedBox(height: 24),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main Content (Stats + Services) - Flex 2
                      Expanded(
                        flex: 2, 
                        child: Column(
                          children: [
                            // Stats Row (Horizontal)
                            _buildStatsRow(context, isMobile: false),
                            const SizedBox(height: 24),
                            // Services Grid takes full remaining space
                            Expanded(child: _buildServicesGrid(isPhone: false, isMobile: false)), 
                          ],
                        ),
                      ),
                      const SizedBox(width: 16), // Tighter gap
                      // Right Panel (Recent Activity) - Flex 1
                      Expanded(
                        flex: 1,
                        child: _buildRightPanel(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 2. Tablet Layout (600dp - 1100dp)
  /// Scrollable layout, larger fonts, 3-column grid.
  Widget _buildTabletLayout(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildHeader(isMobile: true), // Re-use mobile header for compactness
              const SizedBox(height: 24),
              _buildStatsRow(context, isMobile: true), // Horizontal scroll stats
              const SizedBox(height: 24),
              // Tablet uses 3 columns (isPhone: false -> shrinks to fit)
              _buildServicesGrid(isMobile: true, isPhone: false),
              const SizedBox(height: 32),
              _AnimatedOrderListButton(onTap: widget.onOrdersTap),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // --- Components ---

  Widget _buildSidebar(BuildContext context) {
    return _GlassContainer( // Static Sidebar (No Slide Animation)
        width: 100,
        margin: const EdgeInsets.all(24),
        borderRadius: 24,
        intensity: 0.1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
          // Logo (Highlighted)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Consumer<LogoProvider>(
              builder: (context, logoProvider, child) {
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () async {
                      // Trigger logo selection
                      final success = await LogoService.pickAndSaveLogo(context);
                      if (success) {
                        if (context.mounted) {
                          await Provider.of<LogoProvider>(context, listen: false).updateLogo();
                        }
                      }
                    },
                    child: Tooltip(
                      message: "Tap to change logo".tr(),
                      child: Container(
                        padding: const EdgeInsets.all(4), 
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withAlpha(127),
                            width: 2,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withAlpha(25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: FutureBuilder<Widget?>(
                          future: LogoService.getLogoWidget(height: 60, width: 60),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return ClipOval(child: snapshot.data!);
                            }
                            return const SizedBox(); // No icon
                          },
                        ),
                      ),
                  ),
                ),
                );
              },
            ),
          ),
          
          // Navigation Icons
          Column(
            children: [
              _buildNavIcon(Icons.dashboard_rounded, true, onTap: () {}), // Dashboard is current
              const SizedBox(height: 32),
              _buildNavIcon(Icons.attach_money_rounded, false, onTap: widget.onExpensesTap), // Expenses
              const SizedBox(height: 32),
              _buildNavIcon(Icons.bar_chart_rounded, false, onTap: widget.onReportsTap),
              const SizedBox(height: 32),
              _buildNavIcon(Icons.description_rounded, false, onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QuotationsListScreen()),
                );
              }),
              const SizedBox(height: 32),
              _buildNavIcon(Icons.settings_rounded, false, onTap: widget.onSettingsTap),
            ],
          ),

          // Logout
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: _buildNavIcon(Icons.logout_rounded, false, color: Colors.redAccent.withAlpha(204), onTap: widget.onLogoutTap),
          ),
                  ], // Column children
                ), // Column
              ), // IntrinsicHeight
            ), // ConstrainedBox
          ); // SingleChildScrollView
        },
      ), // LayoutBuilder
    );
  }

  Widget _buildNavIcon(IconData icon, bool isSelected, {Color? color, VoidCallback? onTap}) {
    return _HoverNavIcon(icon, isSelected, color: color, onTap: onTap);
  }




  Widget _buildLogo({required double size, required BuildContext context}) {
    return Consumer<LogoProvider>(
      builder: (context, logoProvider, child) {
        return GestureDetector(
          onTap: () async {
            final success = await LogoService.pickAndSaveLogo(context);
            if (success && context.mounted) {
              await Provider.of<LogoProvider>(context, listen: false).updateLogo();
            }
          },
          child: Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(1.5), // Thinner Ring (Subtle)
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Colors.blue,
                  Colors.orange,
                  Colors.cyan,
                  Colors.green,
                  Colors.pink,
                  Colors.yellow,
                  Colors.blue,
                ],
              ),
            ),
            child: ClipOval(
              child: Container(
                color: Colors.black, // Background behind transparent logo parts
                child: (logoProvider.logoPath != null && File(logoProvider.logoPath!).existsSync())
                    ? Image.file(
                        File(logoProvider.logoPath!),
                        width: size,
                        height: size,
                        fit: BoxFit.contain, // Contain to avoid cropping if not square
                      )
                    : const SizedBox(), 
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader({bool isMobile = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [

        Row(
          children: [
            if (isMobile) ...[
              _buildLogo(size: 65, context: context), // Increased Size
              const SizedBox(width: 12),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text(
                   "Welcome Back,".tr(),
                   style: TextStyle(
                     color: Colors.white.withAlpha(153),
                     fontSize: isMobile ? 14 : 16,
                   ),
                 ),
                const SizedBox(height: 4),
                Text(
                  widget.businessName.isNotEmpty ? widget.businessName : "SIMS CAFE", 
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        
        Row(
          children: [
            if (!isMobile) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onSearchTap,
                  borderRadius: BorderRadius.circular(16),
                  child: _GlassContainer(
                    width: 300,
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    borderRadius: 16,
                    intensity: 0.05,
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.white.withAlpha(102)),
                        const SizedBox(width: 12),
                        Text("Search...".tr(), style: TextStyle(color: Colors.white.withAlpha(102), fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              _buildStatusIcon(Icons.wifi, "Connected".tr()),
              const SizedBox(width: 16),
              _GlassContainer(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 borderRadius: 12,
                 color: const Color(0xFF76FF03).withAlpha(25), // Electric Lime
                 borderOpacity: 0.2,
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     const Icon(Icons.access_time_rounded, color: Color(0xFF76FF03), size: 18),
                     const SizedBox(width: 8),
                     Text(_timeString, style: const TextStyle(color: Color(0xFF76FF03), fontWeight: FontWeight.bold)),
                   ],
                 ),
              ),
            ] else ...[
               // Mobile: Settings Icon Only
              IconButton(
                onPressed: widget.onSettingsTap,
                icon: _GlassContainer(
                   padding: const EdgeInsets.all(8),
                   borderRadius: 12,
                   child: const Icon(Icons.settings_rounded, color: Colors.white),
                )
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStatusIcon(IconData icon, String tooltip) {
    return _GlassContainer(
      padding: const EdgeInsets.all(10),
      borderRadius: 50, // Circle
      intensity: 0.05,
      child: Icon(icon, color: Colors.white.withAlpha(179), size: 20),
    );
  }

  Widget _buildStatsRow(BuildContext context, {bool isMobile = false}) {
    return Consumer2<OrderProvider, TableProvider>(
      builder: (context, orderProvider, tableProvider, child) {
        return FutureBuilder<List<Order>>(
          // We can remove FetchOrders here if we want to rely on provider state, 
          // but fetchOrders ensures fresh data. 
          future: orderProvider.fetchOrders(),
          builder: (context, snapshot) {
             // double revenue = 0;
             int pending = 0;
             int todayOrders = 0;

             if (snapshot.hasData) {
               final now = DateTime.now();
               // Create date bounds for "today"
               final todayStr = DateFormat('yyyy-MM-dd').format(now);
               
               for (var order in snapshot.data!) {
                 // Check if order is from today
                 if (order.createdAt != null) {
                   // Simple string check since we likely store as ISO8601
                   // Or clearer parsing:
                   final orderDate = DateTime.tryParse(order.createdAt!);
                   if (orderDate != null) {
                     final orderDateStr = DateFormat('yyyy-MM-dd').format(orderDate);
                     if (orderDateStr == todayStr) {
                       todayOrders++;
                     }
                   }
                 }
                 
                 // revenue += order.total;
                 if (order.status == 'pending') pending++;
               }
             }

             final occupiedTables = tableProvider.tables.where((t) => t.isOccupied).length;
             
             // Helper to build card wrapper based on platform
             Widget buildCardWrapper(Widget child) {
               if (isMobile) {
                   final isTabletPortrait = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;
                   if (isTabletPortrait) {
                     return Expanded(
                       child: Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 4.0), // Smaller gap to overflow
                         child: child,
                       ),
                     );
                   }
                   return Padding(
                   padding: const EdgeInsets.only(right: 12),
                   child: SizedBox(
                     width: 160,
                     child: child,
                   ),
                 );
               } 
               return Expanded(
                 child: child,
               );
             }

             final statsCards = [
                   buildCardWrapper(
                      _buildStatCard(
                        "Orders Today".tr(),
                        _AnimatedCounter(
                           end: todayOrders.toDouble(),
                           style: TextStyle(color: Colors.white, fontSize: isMobile ? 22 : 26, fontWeight: FontWeight.bold),
                           formatter: (v) => v.toInt().toString(), // No currency, just number
                        ),
                        Icons.receipt_long_rounded, // Changed icon
                        const [Color(0xFF00F260), Color(0xFF0575E6)], // Keep same gradient
                        isMobile: isMobile,
                      ),
                   ),
                   if (!isMobile) const SizedBox(width: 20),
                   buildCardWrapper(
                      _buildStatCard(
                        "Pending Orders".tr(),
                        _AnimatedCounter(
                           end: pending,
                           style: TextStyle(color: Colors.white, fontSize: isMobile ? 22 : 26, fontWeight: FontWeight.bold),
                        ),
                        Icons.pending_actions_rounded,
                        const [Color(0xFFFF512F), Color(0xFFDD2476)], // Vibrant Orange -> Pink
                        isMobile: isMobile,
                      ),
                   ),
                   if (!isMobile) const SizedBox(width: 20),
                   buildCardWrapper(
                      _buildStatCard(
                        "Active Tables".tr(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            _AnimatedCounter(
                               end: occupiedTables,
                               style: TextStyle(color: Colors.white, fontSize: isMobile ? 22 : 26, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              " / ${tableProvider.tables.length}",
                              style: TextStyle(color: Colors.white.withAlpha(179), fontSize: isMobile ? 14 : 18, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Icons.table_restaurant_rounded,
                        const [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Vibrant Purple -> Deep Blue
                        isMobile: isMobile,
                      ),
                   ),
             ];

             if (isMobile) {
               final isTabletPortrait = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;
               if (isTabletPortrait) {
                  return Row(children: statsCards); // Return Static Row
               }
               return SingleChildScrollView(
                 scrollDirection: Axis.horizontal,
                 child: Row(children: statsCards),
               );
             }

             return Row(
               children: statsCards,
             );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, Widget content, IconData icon, List<Color> gradientColors, {bool isMobile = false}) {
    final isTabletPortrait = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;
    // Static Implementation (Optimized)
    return Container(
      height: isMobile ? (isTabletPortrait ? 120 : 85) : 120, // Tablet Portrait gets full height
      padding: EdgeInsets.all(isMobile ? 10 : 20),
      decoration: BoxDecoration(
         borderRadius: BorderRadius.circular(24),
         color: Colors.black.withAlpha(51), // Static semi-transparent
         border: Border.all(color: Colors.white.withAlpha(25), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded( 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(color: Colors.white.withAlpha(153), fontSize: isMobile ? 10 : 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                content,
              ],
            ),
          ),
          if (isMobile) const SizedBox(width: 8),
          // Icon Container
          Container(
            padding: EdgeInsets.all(isMobile ? 6 : 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withAlpha(51),
                width: 1,
              ),
              // No shadows for performance
            ),
            child: Icon(icon, color: Colors.white, size: isMobile ? 20 : 28),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid({bool isMobile = false, bool isPhone = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
        // Phone: 2 cols. 
        // Tablet Portrait: 2 cols (User Request).
        // Tablet Landscape / Desktop: 3 cols.
        final crossAxisCount = (isPhone || (isMobile && isPortrait)) ? 2 : 3;
        final spacing = isPhone ? 8.0 : 20.0;
        // Aspect Ratio: 
        // Phone: 1.3 (Standard)
        // Tablet Portrait: 1.8 (Shorter cards, per "Reduce widget size")
        // Tablet Landscape / Desktop: 1.3
        final aspectRatio = (isMobile && isPortrait && !isPhone) ? 1.8 : 1.3; 

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
 
          // If in a ScrollView (Tablet), shrinkWrap=true. 
          // If in Expanded (Phone/Desktop), shrinkWrap=false.
          // Note: On Tablet, we are in SingleChildScrollView -> Column -> _buildServicesGrid.
          // So we usually need shrinkWrap: true for Tablet.
          // On Phone, we are in Column -> Expanded -> _buildServicesGrid. shrinkWrap: false.
          // On Desktop, we are in Column -> Expanded -> _buildServicesGrid. shrinkWrap: false.
           
          // Simplified logic based on method signature usage:
          // _buildPhoneLayout passes isPhone: true.
          // _buildTabletLayout passes isPhone: false.
          // _buildDesktopLayout passes isPhone: false.
          // But Tablet needs shrinkWrap, Desktop does NOT.
          // Let's rely on the context or a new param if needed. 
          // For now, let's look at where it's used.
          // Phone: Expanded -> shrinkWrap: false.
          // Tablet: ScrollView -> shrinkWrap: true.
          // Desktop: Expanded -> shrinkWrap: false.
          
          // We can use the 'constraints' to guess? Or just add a param 'enableScrolling'.
          // Let's adhere to the existing `shrinkWrap: !isPhone` logic which worked for tablet revert,
          // BUT Desktop also passes isPhone=false and needs shrinkWrap=false.
          // So `!isPhone` forces shrinkWrap=true for Desktop, which breaks it (Expanded parent).
          
          // FIX:
          shrinkWrap: !isPhone && constraints.maxWidth < 1100, // Only shrinkWrap on Tablet (<1100)
          
          physics: const NeverScrollableScrollPhysics(), // External scroll view handles it
          children: [
            _buildServiceCard("Dining".tr(), "Table Service".tr(), Icons.restaurant_rounded, const Color(0xFF3B82F6), widget.onDiningTap),
            _buildServiceCard("Delivery".tr(), "Local Delivery".tr(), Icons.delivery_dining_rounded, const Color(0xFFFF7D29), widget.onDeliveryTap),
            _buildServiceCard("Online".tr(), "Web Orders".tr(), Icons.devices_rounded, const Color(0xFF00E5FF), widget.onDelivery2Tap),
            _buildServiceCard("Takeout".tr(), "Counter Pickup".tr(), Icons.local_mall_rounded, const Color(0xFF00E676), widget.onTakeoutTap),
            _buildServiceCard("Drive Thru".tr(), "Quick Service".tr(), Icons.drive_eta_rounded, const Color(0xFFFF2E63), widget.onDriveThroughTap),
            _buildServiceCard("Catering".tr(), "Large Events".tr(), Icons.room_service_rounded, const Color(0xFFFFD700), widget.onCateringTap),
          ],
        );
      },
    );
  }

  Widget _buildServiceCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    // Get index from grid to stagger animations
    final services = [
      {"title": "Dining", "icon": Icons.restaurant_rounded},
      {"title": "Delivery", "icon": Icons.delivery_dining_rounded},
      {"title": "Online", "icon": Icons.shopping_bag_rounded},
      {"title": "Takeout", "icon": Icons.local_mall_rounded},
      {"title": "Drive Thru", "icon": Icons.drive_eta_rounded},
      {"title": "Catering", "icon": Icons.room_service_rounded},
    ];
    services.indexWhere((s) => s["title"] == title);
    // final delay = index >= 0 ? index * 100 : 0;

    // Static Service Card (No Staggered Animation)
    return _AnimatedServiceCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }

  Widget _buildRightPanel(BuildContext context) {
    return _GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      intensity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Recent Activity".tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Icon(Icons.history_rounded, color: Colors.white.withAlpha(102), size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer<OrderProvider>(
              builder: (context, orderProvider, child) {
                return FutureBuilder<List<Order>>(
                  future: orderProvider.fetchOrders(),
                  builder: (context, snapshot) {
                     if (!snapshot.hasData || snapshot.data!.isEmpty) {
                       return Center(
                         child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Icon(Icons.inbox_outlined, color: Colors.white.withAlpha(51), size: 48),
                             const SizedBox(height: 12),
                             Text("No orders yet".tr(), style: TextStyle(color: Colors.white.withAlpha(102))),
                           ],
                         ),
                       );
                     }

                     final orders = snapshot.data!;
                     orders.sort((a, b) => (b.createdAt ?? "").compareTo(a.createdAt ?? ""));
                     final recentOrders = orders.take(7).toList();

                     return ListView.separated(
                       itemCount: recentOrders.length,
                       separatorBuilder: (_, __) => Divider(color: Colors.white.withAlpha(13), height: 16),
                       itemBuilder: (context, index) {
                         final order = recentOrders[index];
                         final date = DateTime.tryParse(order.createdAt ?? "") ?? DateTime.now();
                         final timeStr = DateFormat('h:mm a').format(date);
                         final delay = index * 100; // 100ms delay per item
                         
                         return TweenAnimationBuilder<double>(
                           duration: Duration(milliseconds: 600 + delay),
                           tween: Tween(begin: 0.0, end: 1.0),
                           curve: Curves.easeOutCubic,
                           builder: (context, animValue, child) {
                                     // Helper variables for styling
                                     Color serviceColor;
                                     IconData serviceIcon;
                                     
                                     // Match colors and icons with Dashboard buttons
                                     if (order.serviceType.contains('Dining')) {
                                       serviceColor = const Color(0xFF3B82F6); // Blue
                                       serviceIcon = Icons.restaurant_rounded;
                                     } else if (order.serviceType.contains('Delivery')) {
                                       serviceColor = const Color(0xFFFF7D29); // Orange
                                       serviceIcon = Icons.delivery_dining_rounded;
                                     } else if (order.serviceType.contains('Online')) {
                                       serviceColor = const Color(0xFF00E5FF); // Cyan
                                       serviceIcon = Icons.devices_rounded;
                                     } else if (order.serviceType.contains('Takeout') || order.serviceType.contains('Take Away')) {
                                       serviceColor = const Color(0xFF00E676); // Green
                                       serviceIcon = Icons.local_mall_rounded;
                                     } else if (order.serviceType.contains('Drive')) {
                                       serviceColor = const Color(0xFFFF2E63); // Pink/Red
                                       serviceIcon = Icons.drive_eta_rounded;
                                     } else if (order.serviceType.contains('Catering')) {
                                       serviceColor = const Color(0xFFFFD700); // Gold
                                       serviceIcon = Icons.room_service_rounded;
                                     } else {
                                       serviceColor = Colors.grey;
                                       serviceIcon = Icons.receipt_rounded;
                                     }
                                     
                                     return Opacity(
                                       opacity: animValue,
                                       child: Transform.translate(
                                         offset: Offset(20 * (1 - animValue), 0), // Slide in from right
                                         child: Row(
                                           children: [
                                             Container(
                                               padding: const EdgeInsets.all(8),
                                               decoration: BoxDecoration(
                                                 color: serviceColor.withAlpha(51),
                                                 borderRadius: BorderRadius.circular(8),
                                               ),
                                               child: Icon(
                                                 serviceIcon,
                                                 color: serviceColor,
                                                 size: 14,
                                               ),
                                             ),
                                     const SizedBox(width: 12),
                                     Expanded(
                                       child: Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           Text(
                                             order.serviceType.split('-')[0].trim().tr(),
                                             style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                           ),
                                           Text(
                                             "#${order.id} • $timeStr",
                                             style: TextStyle(color: Colors.white.withAlpha(128), fontSize: 11),
                                           ),
                                         ],
                                       ),
                                     ),
                                     Text(
                                       "₹${order.total.toStringAsFixed(0)}",
                                       style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                     ),
                                   ],
                                 ),
                               ),
                             );
                           },
                         );
                       },
                     );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _AnimatedOrderListButton(onTap: widget.onOrdersTap),
        ],
      ),
    );
  }
}

class _GlassContainer extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double intensity;
  final double borderOpacity;
  final Color? color;

  const _GlassContainer({
    required this.child,
    this.width,
    this.height,
    this.margin,
    this.padding,
    this.borderRadius = 0,
    this.intensity = 0.05,
    this.borderOpacity = 0.1,
    this.color,
  });

  @override
  State<_GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<_GlassContainer> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // OPTIMIZATION: Check platform once
    final isAndroid = Platform.isAndroid;
    // Fix for Windows POS crashing: Disable blur on Windows
    final isWindows = Platform.isWindows; 
    final disableBlur = isAndroid || isWindows;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        
        // Define decoration based on platform
        final decoration = BoxDecoration(
          // High-Gloss Gradient
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (widget.color ?? Colors.white).withAlpha(widget.color != null ? 51 : 38),
              (widget.color ?? Colors.white).withAlpha(widget.color != null ? 13 : 5),
            ],
          ),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            // Disable pulse on Android if strictly needed, but opacity change is usually fine.
            color: Colors.white.withAlpha((_pulseAnimation.value * 255).toInt()),
            width: 1.0,
          ),
          boxShadow: disableBlur ? [] : [ // Remove shadow on Android/Windows for performance/stability
             BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 20,
              spreadRadius: -2,
            ),
          ],
        );

        final content = Container(
             padding: widget.padding,
             decoration: decoration,
             child: widget.child,
        );

        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          // OPTIMIZATION: Remove BackdropFilter (Blur) on Android AND Windows
          child: disableBlur 
              ? Container(
                  decoration: BoxDecoration(
                     color: Colors.black.withAlpha(100), // Darker fallback for Windows/Android
                     borderRadius: BorderRadius.circular(widget.borderRadius),
                  ),
                  child: content
                ) 
              : ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: content,
                  ),
                ),
        );
      },
    );
  }
}

// Animated Service Card with Hover Effects
class _AnimatedServiceCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AnimatedServiceCard> createState() => _AnimatedServiceCardState();
}

class _AnimatedServiceCardState extends State<_AnimatedServiceCard> {
//   bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < 600;
    final isTabletPortrait = width >= 600 && width < 900;
    // final isMobile = width < 800; // Legacy check, can refine if needed

    // Sizes
    // Phone: 22
    // Tablet Portrait: 38 (Increased further per request)
    // Desktop/Landscape: 32
    final double iconSize = isPhone ? 22 : (isTabletPortrait ? 38 : 32);
    final double titleSize = isPhone ? 12 : (isTabletPortrait ? 11 : 18);
    final double subtitleSize = isPhone ? 9 : (isTabletPortrait ? 8 : 12);
    
    // Performance Optimization: STATIC Widget Tree (No Animations)
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.color.withAlpha(76),
              width: 1,
            ),
            // Semi-transparent dark background
            color: Colors.black.withAlpha(51),
            // 3D Effect (Static Shadows)
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(102),
                offset: const Offset(4, 4),
                blurRadius: 6,
              ),
              BoxShadow(
                color: Colors.white.withAlpha(13),
                offset: const Offset(-2, -2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Padding(

            padding: EdgeInsets.all(isPhone ? 8 : (isTabletPortrait ? 12 : 20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Container (Static)
                Container(
                  padding: EdgeInsets.all(isPhone ? 6 : (isTabletPortrait ? 8 : 16)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.color.withAlpha(76),
                        widget.color.withAlpha(26),
                      ],
                    ),
                    border: Border.all(
                      color: widget.color.withAlpha(128),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: iconSize),
                ),
                SizedBox(height: isPhone ? 8 : 16),
                Column(
                  children: [
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: isPhone ? 2 : 4),
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withAlpha(128),
                        fontSize: subtitleSize,
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
}

// Animated Order List Button with Hover Effects
class _AnimatedOrderListButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AnimatedOrderListButton({
    required this.onTap,
  });

  @override
  State<_AnimatedOrderListButton> createState() => _AnimatedOrderListButtonState();
}

class _AnimatedOrderListButtonState extends State<_AnimatedOrderListButton> {
//   bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Static Button Implementation (Optimization)
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          // Tablet Portrait: Increase size (Padding 32). Phone/Desktop: 14.
          padding: EdgeInsets.symmetric(vertical: (MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900) ? 32 : 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF2E63), Color(0xFFC2185B)],
            ),
            borderRadius: BorderRadius.circular(12), // Slightly more rounded
            border: Border.all(color: Colors.white.withAlpha(51), width: 1.5), // Subtle bevel
            // 3D Pop Effect (Static Shadow)
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC2185B).withAlpha(128),
                blurRadius: 12,
                offset: const Offset(0, 6), // Drop shadow to make it pop
              ),
            ],
          ),
          alignment: Alignment.center,
          child:  Text(
            "ORDER LIST".tr(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedCounter extends StatelessWidget {
  final num end;
  final TextStyle style;
  final String Function(num)? formatter;
//   final Duration duration;

  const _AnimatedCounter({
    required this.end,
    required this.style,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    // Optimization: Direct Text render (No Animation)
    final String text = formatter != null 
        ? formatter!(end) 
        : end.toInt().toString();
    return Text(text, style: style);
  }
}
class _HoverNavIcon extends StatefulWidget {
  final IconData icon;
  final bool isSelected;
  final Color? color;
  final VoidCallback? onTap;

  const _HoverNavIcon(this.icon, this.isSelected, {this.color, this.onTap});

  @override
  State<_HoverNavIcon> createState() => _HoverNavIconState();
}

class _HoverNavIconState extends State<_HoverNavIcon> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    // Electric Lime for active state
    const activeColor = Color(0xFF76FF03); 
    final isSelected = widget.isSelected;
    // Use passed color or default logic
    final iconColor = widget.color ?? (isSelected || _isHovering ? activeColor : Colors.white.withAlpha(102));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..scale(_isHovering ? 1.15 : 1.0), // Scale up on hover
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected 
                ? activeColor.withAlpha(51) 
                : (_isHovering ? activeColor.withAlpha(26) : Colors.transparent), // Subtle bg on hover
            borderRadius: BorderRadius.circular(16),
            boxShadow: (Platform.isAndroid) 
                ? []
                : ((isSelected || _isHovering) ? [
                    BoxShadow(
                      color: activeColor.withAlpha(_isHovering ? 153 : 26),
                      blurRadius: _isHovering ? 20 : 10,
                      spreadRadius: _isHovering ? 2 : 0,
                    ),
                  ] : []),
          ),
          child: Icon(
            widget.icon,
            color: iconColor,
            size: 28,
            shadows: (isSelected || _isHovering) ? [
               Shadow(
                 color: activeColor.withAlpha(153), 
                 blurRadius: _isHovering ? 15 : 10
               ),
            ] : [],
          ),
        ),
      ),
    );
  }
}