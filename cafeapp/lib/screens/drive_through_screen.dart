import 'package:cafeapp/utils/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import 'menu_screen.dart';


class DriveThroughScreen extends StatefulWidget {
  const DriveThroughScreen({super.key});

  @override
  State<DriveThroughScreen> createState() => _DriveThroughScreenState();
}

class _DriveThroughScreenState extends State<DriveThroughScreen> {
  // Temporary local state for the queue (could be moved to a Provider later)
  final List<Map<String, dynamic>> _vehicles = [];
  
  final TextEditingController _numberController = TextEditingController();
  String _selectedType = 'Car'; // Default

  final List<Map<String, dynamic>> _vehicleTypes = [
    {'label': 'Car', 'icon': Icons.directions_car_rounded, 'color': Colors.blue},
    {'label': 'Bike', 'icon': Icons.two_wheeler_rounded, 'color': Colors.orange},
    {'label': 'Truck', 'icon': Icons.local_shipping_rounded, 'color': Colors.green},
    {'label': 'Other', 'icon': Icons.category_rounded, 'color': Colors.grey},
  ];

  void _addVehicle() {
    if (_numberController.text.trim().isEmpty) return;

    setState(() {
      _vehicles.add({
        'number': _numberController.text.trim().toUpperCase(),
        'type': _selectedType,
        'time': DateTime.now(),
        // Get icon data for display
        'icon': _vehicleTypes.firstWhere((t) => t['label'] == _selectedType)['icon'],
        'color': _vehicleTypes.firstWhere((t) => t['label'] == _selectedType)['color'],
      });
      _numberController.clear();
      // Keep type as is or reset? Keep as is for batch entry.
    });
  }

  void _navigateToMenu(Map<String, dynamic> vehicle) {
    final title = 'Drive Through - ${vehicle['type']} - ${vehicle['number']}';
    
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    orderProvider.setCurrentServiceType(title);
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => MenuScreen(
          serviceType: title, 
          // Pass a color based on vehicle type
          serviceColor: vehicle['color'] as Color, 
        ),
      ),
    );
  }

  void _removeVehicle(int index) {
    setState(() {
      _vehicles.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title:  Text(
          'Drive Through Management'.tr(),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(
               color: const Color(0xFFF3F4F6),
               borderRadius: BorderRadius.circular(20),
             ),
             child: Row(
               children: [
                 const Icon(Icons.queue_rounded, color: Colors.black54, size: 18),
                 const SizedBox(width: 8),
                 Text(
                   '${'Length: '.tr()}${_vehicles.length}',
                   style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                 ),
               ],
             )
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          
          if (isWide) {
            // Desktop/Tablet Landscape Layout (Original Row)
            return Row(
              children: [
                // Left Side: Input Form
                Container(
                  width: 400,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: _buildInputForm(),
                ),

                // Right Side: Queue List
                Expanded(
                  child: Container(
                    color: const Color(0xFFF9FAFB),
                    padding: const EdgeInsets.all(24),
                    child: _buildQueueList(),
                  ),
                ),
              ],
            );
          } else {
            // Mobile/Tablet Portrait Layout (Column)
            return Column(
              children: [
                // Top: Input Form (Collapsible or just standard)
                Container(
                   decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: _buildInputForm(isMobile: true),
                ),
                
                // Bottom: Queue List
                Expanded(
                  child: Container(
                    color: const Color(0xFFF9FAFB),
                    padding: const EdgeInsets.all(16),
                    child: _buildQueueList(),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildInputForm({bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Important for mobile column
      children: [
        if (!isMobile) ...[
          Text(
            "New Vehicle Entry".tr(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter vehicle details to add to queue".tr(),
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),
        ],
        
        // Vehicle Number Input
        Text("Vehicle Number".tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _numberController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: "e.g. KL-01-AB-1234".tr(),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
            ),
            prefixIcon: const Icon(Icons.tag_rounded, color: Colors.grey),
          ),
          onSubmitted: (_) => _addVehicle(),
        ),

        SizedBox(height: isMobile ? 16 : 24),
        
        // Vehicle Type Selector
        Text("Vehicle Type".tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox( // Constrain height/width for horizontal scrolling if needed, or wrap
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
             child: Row( // Use Row instead of Wrap for single line scrolling on mobile
              children: _vehicleTypes.map((type) {
                final isSelected = _selectedType == type['label'];
                final color = type['color'] as Color;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: InkWell(
                    onTap: () => setState(() => _selectedType = type['label']),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withAlpha(25) : Colors.white,
                        border: Border.all(
                          color: isSelected ? color : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row( // Horizontal layout for chips
                        children: [
                          Icon(type['icon'], color: isSelected ? color : Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            type['label'].toString().tr(),
                            style: TextStyle(
                              color: isSelected ? color : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 13
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        if (!isMobile) const Spacer(),
        if (isMobile) const SizedBox(height: 16),
        
        // Add Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _addVehicle,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text("Add to Queue".tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildQueueList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(
          "Active Queue".tr(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        
        if (_vehicles.isEmpty) ...[
           Expanded(
             child: Center(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(Icons.drive_eta_rounded, size: 60, color: Colors.grey.shade300),
                   const SizedBox(height: 16),
                   Text(
                      "No vehicles in queue".tr(),
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                   ),
                 ],
               ),
             ),
           )
        ] else ...[
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
              ),
              itemCount: _vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = _vehicles[index];
                final color = vehicle['color'] as Color;
                
                return InkWell(
                  onTap: () => _navigateToMenu(vehicle),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: color.withAlpha(25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(vehicle['icon'], color: color, size: 24),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "#${index + 1}",
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicle['number'],
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    vehicle['type'],
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Remove Button
                        Positioned(
                          top: 8,
                          right: 48, // offset to left of index badge
                          child: IconButton(
                            icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade400),
                            onPressed: () => _removeVehicle(index),
                            splashRadius: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );

  }
}