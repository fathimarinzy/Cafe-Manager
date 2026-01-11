
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/logo_provider.dart';
import '../services/logo_service.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class DashboardModernDark extends StatefulWidget {
  final VoidCallback onDiningTap;
  final VoidCallback onDeliveryTap;
  final VoidCallback onTakeoutTap;
  final VoidCallback onDriveThroughTap;
  final VoidCallback onCateringTap;
  final VoidCallback onDelivery2Tap;
  final VoidCallback onOrdersTap;

  const DashboardModernDark({
    super.key,
    required this.onDiningTap,
    required this.onDeliveryTap,
    required this.onTakeoutTap,
    required this.onDriveThroughTap,
    required this.onCateringTap,
    required this.onDelivery2Tap,
    required this.onOrdersTap,
  });

  @override
  State<DashboardModernDark> createState() => _DashboardModernDarkState();
}

class _DashboardModernDarkState extends State<DashboardModernDark> {
  String _timeString = "";
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timeString = _formatTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());
  }

  void _getTime() {
    final String formattedDateTime = _formatTime();
    if (mounted) {
      setState(() {
        _timeString = formattedDateTime;
      });
    }
  }

  String _formatTime() {
    return DateFormat('hh:mm:ss a').format(DateTime.now());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF16161d), // Deep dark background
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              // HEADER (Time & Icons)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _timeString,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.wifi, color: Color(0xFFC6A87C).withAlpha(204), size: 20),
                      SizedBox(width: 24),
                      Icon(Icons.settings_outlined, color: Color(0xFFC6A87C).withAlpha(204), size: 20),
                      SizedBox(width: 24),
                      Icon(Icons.power_settings_new, color: Color(0xFFC6A87C).withAlpha(204), size: 20),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 40),

              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT FLOATING SIDEBAR
                    Container(
                      width: 320, // Slightly narrower
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF224e5e), // Lighter Teal Top-Left (Highlight)
                            Color(0xFF1a3b47), // Base Teal
                            Color(0xFF0e121b), // Dark Shadow Bottom-Right
                          ],
                          stops: [0.0, 0.4, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          // Deep drop shadow
                          BoxShadow(
                            color: Colors.black.withAlpha(153),
                            blurRadius: 30,
                            offset: const Offset(15, 15),
                          ),
                          // White slight reflection sidebar
                          BoxShadow(
                            color: Colors.white.withAlpha(25),
                            blurRadius: 5,
                            offset: const Offset(-2, -2),
                          ),
                        ],
                        border: Border.all(color: Colors.white.withAlpha(25), width: 1.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                      child: Column(
                        children: [
                          // Logo
                          Consumer<LogoProvider>(
                            builder: (context, logoProvider, child) {
                              return FutureBuilder<Widget?>(
                                future: LogoService.getLogoWidget(height: 80, width: 80),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data != null) {
                                    return Container(
                                      height: 80, width: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                           BoxShadow(color: Colors.black.withAlpha(128), blurRadius: 15, offset: Offset(0, 5))
                                        ]
                                      ),
                                      child: ClipOval(child: snapshot.data!),
                                    );
                                  }
                                  return Icon(Icons.coffee, size: 60, color: Color(0xFFd4af37));
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "SIMS CAFE",
                            style: TextStyle(
                              fontFamily: 'Serif', // Fallback
                              fontSize: 28,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w500,
                              shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))]
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Cafe Management",
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFd4af37), // Gold
                              letterSpacing: 1,
                              fontWeight: FontWeight.w300,
                              shadows: [Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1))]
                            ),
                          ),
                          const SizedBox(height: 40),



                          _buildInfoBox(Icons.location_on_outlined, "Location: Kochi"),
                          const SizedBox(height: 16),
                          _buildInfoBox(Icons.phone_outlined, "Contact: 9876677889"),
                          const SizedBox(height: 16),
                          _buildInfoBox(Icons.email_outlined, "Email: simscafe@gmail.com"),
                        ],
                      ),
                    ),

                    const SizedBox(width: 40),

                    // RIGHT GRID CONTENT
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: GridView.count(
                        crossAxisCount: 3, // Increased column count to make widgets smaller
                        crossAxisSpacing: 30, 
                        mainAxisSpacing: 30,
                        childAspectRatio: 1.5, // Increased aspect ratio to make widgets shorter (smaller)
                        children: [
                          _buildGradientButton(
                            "Dining",
                            Icons.restaurant_outlined, 
                            const LinearGradient(
                              colors: [Color(0xFFe69a6b), Color(0xFF8c4a2a)], 
                              begin: Alignment.topLeft, end: Alignment.bottomRight
                            ),
                            widget.onDiningTap,
                          ),
                          _buildGradientButton(
                            "Delivery",
                            Icons.delivery_dining_outlined, 
                            const LinearGradient(
                              colors: [Color(0xFF5e636b), Color(0xFF2b2e35)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight
                            ),
                            widget.onDelivery2Tap,
                          ),
                          _buildGradientButton(
                            "Delivery",
                            Icons.shopping_bag_outlined,
                            const LinearGradient(
                              colors: [Color(0xFF8bcce3), Color(0xFF3b697b)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight
                            ),
                            widget.onDeliveryTap,
                          ),
                          _buildGradientButton(
                            "Takeout",
                            Icons.local_mall_outlined,
                            const LinearGradient(
                              colors: [Color(0xFF96aa71), Color(0xFF4b5832)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight
                            ),
                            widget.onTakeoutTap,
                          ),
                          _buildGradientButton(
                            "Drive Through",
                            Icons.assignment_outlined,
                            const LinearGradient(
                              colors: [Color(0xFFc98693), Color(0xFF6e3c44)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight
                            ),
                            widget.onDriveThroughTap,
                          ),
                          _buildGradientButton(
                            "Catering",
                            Icons.cake_outlined,
                            const LinearGradient(
                              colors: [Color(0xFFf5ca5c), Color(0xFF917224)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight
                            ),
                            widget.onCateringTap,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Material(
                       color: Colors.transparent,
                       child: InkWell(
                         onTap: widget.onOrdersTap,
                         borderRadius: BorderRadius.circular(12),
                         child: Container(
                           width: double.infinity,
                           padding: const EdgeInsets.symmetric(vertical: 32), // Greatly increased padding for size
                           decoration: BoxDecoration(
                             gradient: const LinearGradient(colors: [Color(0xFFd4af37), Color(0xFF8B732D)]),
                             borderRadius: BorderRadius.circular(12),
                             boxShadow: [BoxShadow(color: Colors.black.withAlpha(76), blurRadius: 8, offset: Offset(0,4))]
                           ),
                           alignment: Alignment.center,
                           child: const Text("ORDER LIST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 2.0)), // Larger Text
                         ),
                       ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
              
              const SizedBox(height: 20),
              // FOOTER
              Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  "POWERED BY SMS AI",
                  style: TextStyle(
                    color: Colors.white.withAlpha(102),
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced vertical padding
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(51), // Slight dark tint
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFd4af37).withAlpha(102), width: 1),
        boxShadow: [
           BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 4, offset: Offset(2,2))
        ]
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFd4af37), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton(String title, IconData icon, Gradient gradient, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // Deep heavy shadow for pop effect
          BoxShadow(
            color: Colors.black.withAlpha(128),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(10, 10),
          ),
          // Top light reflection (Bevel)
          BoxShadow(
            color: Colors.white.withAlpha(64),
            blurRadius: 2,
            offset: const Offset(-2, -2),
          ),
           // Bottom dark groove (Bevel)
          BoxShadow(
            color: Colors.black.withAlpha(102),
            blurRadius: 2,
            offset: const Offset(2, 2),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.white.withAlpha(38),
          width: 1.0,
        )
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withAlpha(26),
          highlightColor: Colors.white.withAlpha(13),
          child: Container( // Inner container for subtle convex effect
             decoration: BoxDecoration(
               borderRadius: BorderRadius.circular(20),
               gradient: LinearGradient(
                 colors: [Colors.white.withAlpha(38), Colors.transparent, Colors.black.withAlpha(26)],
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
               )
             ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 42, color: const Color(0xFFF3D576)), // Smaller Icon
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15, // Smaller Text
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      )
                    ]
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
