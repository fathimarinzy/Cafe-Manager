// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
// import '../models/order_history.dart';
// import '../providers/order_history_provider.dart';
// import '../providers/table_provider.dart';
// import '../models/table_model.dart';
// import 'order_details_screen.dart';
// import 'dart:async';

// class TableOrderHistoryScreen extends StatefulWidget {
//   final String? tableInfo;

//   const TableOrderHistoryScreen({super.key, this.tableInfo});


//   @override
//   State<TableOrderHistoryScreen> createState() => _TableOrderHistoryScreenState();
// }

// class _TableOrderHistoryScreenState extends State<TableOrderHistoryScreen> {
//   TableModel? _selectedTable;
//   OrderTimeFilter _selectedFilter = OrderTimeFilter.all;
//   String _currentTime = '';
//   Timer? _timer;
  
//   @override
//   void initState() {
//     super.initState();
//     _updateTime();
    
//     // Start timer to update time every second
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       _updateTime();
//     });
    
//     // Load orders for specific table if provided
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (widget.tableInfo != null) {
//         Provider.of<OrderHistoryProvider>(context, listen: false)
//           .loadOrdersByTable(widget.tableInfo!);
//       } else {
//         // If no table specified, load all tables and select the first one
//         final tableProvider = Provider.of<TableProvider>(context, listen: false);
//         final tables = tableProvider.tables;
        
//         if (tables.isNotEmpty) {
//           setState(() {
//             _selectedTable = tables.first;
//           });
          
//           // Load orders for this table
//           final tableInfo = 'Dining - Table ${tables.first.number}';
//           Provider.of<OrderHistoryProvider>(context, listen: false)
//             .loadOrdersByTable(tableInfo);
//         }
//       }
//     });
//   }
  
//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }
  
//   void _updateTime() {
//     final now = DateTime.now();
//     final formatter = DateFormat('hh:mm a');
//     setState(() {
//       _currentTime = formatter.format(now);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final tableProvider = Provider.of<TableProvider>(context);
//     final tables = tableProvider.tables;
    
//     String title = 'Table Order History';
//     if (widget.tableInfo != null) {
//       title = widget.tableInfo!;
//     } else if (_selectedTable != null) {
//       title = 'Table ${_selectedTable!.number} History';
//     }
    
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         foregroundColor: Colors.black,
//         title: Text(title),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         actions: [
//           // Time display
//           Padding(
//             padding: const EdgeInsets.only(right: 16.0),
//             child: Row(
//               children: [
//                 const Icon(Icons.access_time, color: Colors.black, size: 20),
//                 const SizedBox(width: 4),
//                 Text(
//                   _currentTime,
//                   style: const TextStyle(color: Colors.black),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Table selection dropdown (only show if tableInfo was not provided)
//           if (widget.tableInfo == null)
//             Container(
//               padding: const EdgeInsets.all(16),
//               color: Colors.white,
//               child: Row(
//                 children: [
//                   const Text(
//                     'Select Table:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(width: 16),
//                   Expanded(
//                     child: DropdownButtonFormField<TableModel>(
//                       decoration: InputDecoration(
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                       ),
//                       value: _selectedTable,
//                       items: tables.map((table) {
//                         return DropdownMenuItem<TableModel>(
//                           value: table,
//                           child: Text('Table ${table.number}'),
//                         );
//                       }).toList(),
//                       onChanged: (table) {
//                         if (table != null) {
//                           setState(() {
//                             _selectedTable = table;
//                           });
                          
//                           // Load orders for this table
//                           final tableInfo = 'Dining - Table ${table.number}';
//                           Provider.of<OrderHistoryProvider>(context, listen: false)
//                             .loadOrdersByTable(tableInfo);
//                         }
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             ),
          
//           // Time filter
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               border: Border(
//                 top: widget.tableInfo == null 
//                   ? BorderSide(color: Colors.grey.shade300)
//                   : BorderSide.none,
//                 bottom: BorderSide(color: Colors.grey.shade300),
//               ),
//             ),
//             child: SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: Row(
//                 children: [
//                   _buildFilterChip(OrderTimeFilter.today),
//                   _buildFilterChip(OrderTimeFilter.weekly),
//                   _buildFilterChip(OrderTimeFilter.monthly),
//                   _buildFilterChip(OrderTimeFilter.yearly),
//                   _buildFilterChip(OrderTimeFilter.all),
//                 ],
//               ),
//             ),
//           ),
          
//           // Order list
//           Expanded(
//             child: _buildOrderList(),
//           ),
//         ],
//       ),
//     );
//   }
  
//   Widget _buildFilterChip(OrderTimeFilter filter) {
//     final isSelected = _selectedFilter == filter;
    
//     return Padding(
//       padding: const EdgeInsets.only(right: 8.0),
//       child: FilterChip(
//         label: Text(filter.displayName),
//         selected: isSelected,
//         onSelected: (selected) {
//           setState(() {
//             _selectedFilter = filter;
//           });
//           Provider.of<OrderHistoryProvider>(context, listen: false)
//             .setTimeFilter(filter);
//         },
//         backgroundColor: Colors.grey.shade200,
//         selectedColor: Colors.blue.shade100,
//         checkmarkColor: Colors.blue.shade800,
//       ),
//     );
//   }
  
//   Widget _buildOrderList() {
//     return Consumer<OrderHistoryProvider>(
//       builder: (context, historyProvider, child) {
//         if (historyProvider.isLoading) {
//           return const Center(child: CircularProgressIndicator());
//         }
        
//         if (historyProvider.errorMessage.isNotEmpty) {
//           return Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Icon(Icons.error_outline, size: 48, color: Colors.red),
//                 const SizedBox(height: 16),
//                 Text(
//                   'Error: ${historyProvider.errorMessage}',
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 16),
//                 ElevatedButton(
//                   onPressed: () {
//                     if (widget.tableInfo != null) {
//                       historyProvider.loadOrdersByTable(widget.tableInfo!);
//                     } else if (_selectedTable != null) {
//                       final tableInfo = 'Dining - Table ${_selectedTable!.number}';
//                       historyProvider.loadOrdersByTable(tableInfo);
//                     }
//                   },
//                   child: const Text('Retry'),
//                 ),
//               ],
//             ),
//           );
//         }
        
//         final orders = historyProvider.orders;
        
//         if (orders.isEmpty) {
//           return Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.restaurant, size: 64, color: Colors.grey.shade400),
//                 const SizedBox(height: 16),
//                 Text(
//                   'No order history for this table',
//                   style: TextStyle(
//                     fontSize: 18,
//                     color: Colors.grey.shade600,
//                   ),
//                 ),
//               ],
//             ),
//           );
//         }
        
//         // Order List
//         return ListView.builder(
//           padding: const EdgeInsets.all(16),
//           itemCount: orders.length,
//           itemBuilder: (context, index) {
//             final order = orders[index];
//             return _buildOrderCard(order);
//           },
//         );
//       },
//     );
//   }
  
//   Widget _buildOrderCard(OrderHistory order) {
//     // Format currency
//     final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
    
//     return Card(
//       margin: const EdgeInsets.only(bottom: 16),
//       elevation: 2,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: InkWell(
//         onTap: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => OrderDetailsScreen(orderId: order.id),
//             ),
//           );
//         },
//         borderRadius: BorderRadius.circular(12),
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'Bill #${order.orderNumber}',
//                     style: const TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 18,
//                     ),
//                   ),
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: _getStatusColor(order.status),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     // child: Text(
//                     //   order.status.toUpperCase(),
//                     //   style: TextStyle(
//                     //     color: _getStatusColor(order.status) == Colors.green.shade100 ? 
//                     //       Colors.green.shade800 : Colors.white,
//                     //     fontSize: 12,
//                     //     fontWeight: FontWeight.bold,
//                     //   ),
//                     // ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               // Total amount
//               Text(
//                 currencyFormat.format(order.total),
//                 style: const TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//               const SizedBox(height: 12),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   // Date and time
//                   Row(
//                     children: [
//                       Icon(
//                         Icons.calendar_today,
//                         size: 14,
//                         color: Colors.grey.shade600,
//                       ),
//                       const SizedBox(width: 4),
//                       Text(
//                         order.formattedDate,
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: Colors.grey.shade600,
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       Icon(
//                         Icons.access_time,
//                         size: 14,
//                         color: Colors.grey.shade600,
//                       ),
//                       const SizedBox(width: 4),
//                       Text(
//                         order.formattedTime,
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: Colors.grey.shade600,
//                         ),
//                       ),
//                     ],
//                   ),
//                   // View details button
//                   Row(
//                     children: [
//                       Text(
//                         'View Details',
//                         style: TextStyle(
//                           color: Colors.blue.shade700,
//                           fontSize: 12,
//                         ),
//                       ),
//                       Icon(
//                         Icons.arrow_forward_ios,
//                         size: 12,
//                         color: Colors.blue.shade700,
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
  
//   Color _getStatusColor(String status) {
//     switch (status.toLowerCase()) {
//       case 'completed':
//         return Colors.green.shade100;
//       case 'pending':
//         return Colors.orange;
//       case 'cancelled':
//         return Colors.red;
//       default:
//         return Colors.blue;
//     }
//   }
// }