// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../providers/order_provider.dart';
// import '../models/order.dart';

// class OrdersScreen extends StatefulWidget {
//    const OrdersScreen({super.key});  // Added key parameter

//   @override
//   OrdersScreenState createState() => OrdersScreenState(); // Removed underscore
// }

// class OrdersScreenState extends State<OrdersScreen> { // Removed underscore to make it public
//   bool _isLoading = false;
//   List<Order> _orders = [];

//   @override
//   void initState() {
//     super.initState();
//     _fetchOrders();
//   }

//   Future<void> _fetchOrders() async {
//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       final orderProvider = Provider.of<OrderProvider>(context, listen: false);
//       final orders = await orderProvider.fetchOrders();
      
//       if (!mounted) return; // Ensuring context is safe to use

//       setState(() {
//         _orders = orders;
//       });
//     } catch (error) {
//       if (mounted) { // Ensuring context is safe to use
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to load orders. Please try again.')),
//         );
//       }
//     } finally {
//       if (mounted) { // Ensuring context is safe to use
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Order History'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: _fetchOrders,
//           ),
//         ],
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : _orders.isEmpty
//               ? Center(child: Text('No orders found'))
//               : ListView.builder(
//                   itemCount: _orders.length,
//                   itemBuilder: (ctx, index) {
//                     final order = _orders[index];
//                     return Card(
//                       margin: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
//                       child: ExpansionTile(
//                         title: Text('Order #${order.id}'),
//                         subtitle: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text('${order.serviceType} - ${order.status}'),
//                             Text('Total: \$${order.total.toStringAsFixed(2)}'),
//                           ],
//                         ),
//                         children: [
//                           Container(
//                             padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                             child: Column(
//                               children: [
//                                 ...order.items.map((item) => Padding(
//                                       padding: const EdgeInsets.symmetric(vertical: 4),
//                                       child: Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           Text('${item.quantity}x ${item.name}'),
//                                           Text('\$${(item.price * item.quantity).toStringAsFixed(2)}'),
//                                         ],
//                                       ),
//                                     )),
//                                 Divider(),
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Text('Subtotal:'),
//                                     Text('\$${order.subtotal.toStringAsFixed(2)}'),
//                                   ],
//                                 ),
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Text('Tax:'),
//                                     Text('\$${order.tax.toStringAsFixed(2)}'),
//                                   ],
//                                 ),
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Text('Discount:'),
//                                     Text('\$${order.discount.toStringAsFixed(2)}'),
//                                   ],
//                                 ),
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Text('Total:',
//                                         style: TextStyle(fontWeight: FontWeight.bold)),
//                                     Text('\$${order.total.toStringAsFixed(2)}',
//                                         style: TextStyle(fontWeight: FontWeight.bold)),
//                                   ],
//                                 ),
//                                 if (order.createdAt != null)
//                                   Padding(
//                                     padding: const EdgeInsets.only(top: 8.0),
//                                     child: Text(
//                                       'Created: ${order.createdAt}',
//                                       style: TextStyle(
//                                         fontSize: 12,
//                                         color: Colors.grey,
//                                       ),
//                                     ),
//                                   ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//     );
//   }
// }
