import 'package:cafeapp/utils/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../providers/order_provider.dart';
// import '../providers/table_provider.dart';
import '../models/order.dart';

class DashboardMobile extends StatefulWidget {
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
  final VoidCallback? onExpensesTap;
  final VoidCallback? onLogoutTap;
  final String businessName;
  final String secondbusinessName;

  const DashboardMobile({
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
    this.secondbusinessName = "",
  });

  @override
  State<DashboardMobile> createState() => _DashboardMobileState();
}

class _DashboardMobileState extends State<DashboardMobile> {
  String _timeString = "";
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timeString = _formatTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dark theme for premium but efficient look
    const backgroundColor = Color(0xFF1a1c1e);
    const cardColor = Color(0xFF2d3035);
    // const accentColor = Colors.blue;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.businessName.isNotEmpty ? widget.businessName : "SIMS CAFE",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            Text(
              _timeString,
              style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(178)),
            ),
          ],
        ),
        actions: [

          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: widget.onSearchTap,
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        backgroundColor: cardColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
             DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF232529),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.local_cafe, color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  Text(widget.businessName.isNotEmpty ? widget.businessName : 'SIMS CAFE', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(widget.secondbusinessName.isNotEmpty ? widget.secondbusinessName : '', style: TextStyle(color: Colors.white.withAlpha(127), fontSize: 12)),
                  // Text('Mobile Performance Mode'.tr(), style: TextStyle(color: Colors.white.withAlpha(127), fontSize: 12)),
                ],
              ),
            ),
            _buildDrawerItem(Icons.bar_chart, 'Reports'.tr(), widget.onReportsTap),
            _buildDrawerItem(Icons.attach_money, 'Expenses'.tr(), widget.onExpensesTap),
            _buildDrawerItem(Icons.settings, 'Settings'.tr(), widget.onSettingsTap),
            const Divider(color: Colors.grey),

            _buildDrawerItem(Icons.logout, 'Logout'.tr(), widget.onLogoutTap, isDestructive: true),
          ],
        ),
      ),

      body: Column(
        children: [
          // Stats Row
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF232529),
            child: Consumer<OrderProvider>(
              builder: (context, orderProvider, child) {
                  return FutureBuilder<List<Order>>(
                    future: orderProvider.fetchOrders(),
                    builder: (context, snapshot) {
                       int todayOrders = 0;
                       int pendingOrders = 0;
                       
                       if (snapshot.hasData) {
                         final now = DateTime.now();
                         final todayStr = DateFormat('yyyy-MM-dd').format(now);
                         for (var order in snapshot.data!) {
                           if (order.createdAt != null && order.createdAt!.startsWith(todayStr)) {
                             todayOrders++;
                             if (order.status == 'pending') pendingOrders++;
                           }
                         }
                       }
                       
                       return Row(
                         children: [
                           Expanded(
                             child: _buildStatItem('Today'.tr(), todayOrders.toString(), Colors.green),
                           ),
                           Container(width: 1, height: 40, color: Colors.white.withAlpha(25)),
                           Expanded(
                             child: _buildStatItem('Pending'.tr(), pendingOrders.toString(), Colors.orange),
                           ),
                         ],
                       );
                    }
                  );
              },
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Services'.tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
                // Services Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _buildServiceCard('Dining'.tr(), Icons.restaurant, const Color(0xFF3B82F6), widget.onDiningTap),
                    _buildServiceCard('Delivery'.tr(), Icons.delivery_dining, const Color(0xFFFF7D29), widget.onDeliveryTap),
                    _buildServiceCard('Takeout'.tr(), Icons.local_mall, const Color(0xFF00E676), widget.onTakeoutTap),
                    _buildServiceCard('Online'.tr(), Icons.devices, const Color(0xFF00E5FF), widget.onDelivery2Tap),
                    _buildServiceCard('Drive Thru'.tr(), Icons.drive_eta, const Color(0xFFFF2E63), widget.onDriveThroughTap),
                    _buildServiceCard('Catering'.tr(), Icons.room_service, const Color(0xFFFFD700), widget.onCateringTap),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Actions'.tr(), style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                     TextButton(onPressed: widget.onOrdersTap, child:  Text('View All'.tr()))
                  ],
                ),
                const SizedBox(height: 8),
                
                // Big Order List Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.0), // Adjusted padding to match original InkWell's lack of horizontal padding
                  child: SizedBox(
                     width: double.infinity,
                     height: 55,
                     child: ElevatedButton(
                       onPressed: widget.onOrdersTap,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: const Color(0xFF3B82F6),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(12),
                         ),
                         elevation: 4,
                       ),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children:  [
                           Icon(Icons.list_alt, size: 28, color: Colors.white),
                           SizedBox(width: 12),
                           Text('Order List'.tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                         ],
                       ),
                     ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback? onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.white70),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : Colors.white)),
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (onTap != null) onTap();
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withAlpha(127), fontSize: 12)),
      ],
    );
  }

  Widget _buildServiceCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: const Color(0xFF2d3035),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(13)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}