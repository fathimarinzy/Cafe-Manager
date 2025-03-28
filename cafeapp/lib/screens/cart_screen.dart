// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../providers/order_provider.dart';
// import 'dashboard_screen.dart';

// class CartScreen extends StatelessWidget {
//   final String serviceType;

//   const CartScreen({super.key, required this.serviceType});

//   @override
//   Widget build(BuildContext context) {
//     final orderProvider = Provider.of<OrderProvider>(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Cart - $serviceType'),
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: orderProvider.cartItems.isEmpty
//                 ? const Center(child: Text('No items in cart'))
//                 : ListView.builder(
//                     itemCount: orderProvider.cartItems.length,
//                     itemBuilder: (ctx, index) {
//                       final item = orderProvider.cartItems[index];
//                       return ListTile(
//                         title: Text(item.name),
//                         subtitle: Text('\$${item.price.toStringAsFixed(2)}'),
//                         trailing: IconButton(
//                           icon: const Icon(Icons.delete),
//                           onPressed: () {
//                             orderProvider.removeFromCart(item.id);
//                           },
//                         ),
//                       );
//                     },
//                   ),
//           ),
//           Card(
//             margin: const EdgeInsets.all(8),
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   _buildRow('Subtotal', '\$${orderProvider.subtotal.toStringAsFixed(2)}'),
//                   const SizedBox(height: 8),
//                   _buildRow('Tax', '\$${orderProvider.tax.toStringAsFixed(2)}'),
//                   const SizedBox(height: 8),
//                   _buildRow('Discount', '\$${orderProvider.discount.toStringAsFixed(2)}'),
//                   const Divider(),
//                   _buildRow(
//                     'Total',
//                     '\$${orderProvider.total.toStringAsFixed(2)}',
//                     bold: true,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: () {
//                       orderProvider.clearCart();
//                       Navigator.of(context).pop();
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red,
//                     ),
//                     child: const Text('Cancel'),
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: orderProvider.cartItems.isEmpty
//                         ? null
//                         : () async {
//                             final success = await orderProvider.placeOrder(serviceType);

//                             if (!context.mounted) return; // Fix for async context issue

//                             if (success) {
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 const SnackBar(content: Text('Order placed successfully!')),
//                               );
//                               Navigator.of(context).pushAndRemoveUntil(
//                                 MaterialPageRoute(
//                                   builder: (context) => const DashboardScreen(),
//                                 ),
//                                 (route) => false,
//                               );
//                             } else {
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 const SnackBar(content: Text('Failed to place order. Please try again.')),
//                               );
//                             }
//                           },
//                     child: const Text('Place Order'),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRow(String label, String value, {bool bold = false}) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
//         Text(value, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
//       ],
//     );
//   }
// }
