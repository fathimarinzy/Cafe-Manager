import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/order_provider.dart';
import 'dashboard_screen.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final String serviceType;

  const OrderConfirmationScreen({
    super.key,
    required this.serviceType,
  });

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final items = orderProvider.cartItems;
    
    // Format the current date and time
    final dateFormatter = DateFormat('dd-MM-yyyy');
    final timeFormatter = DateFormat('hh:mm a');
    final now = DateTime.now();
    final formattedDate = dateFormatter.format(now);
    final formattedTime = timeFormatter.format(now);
    
    // Generate order number (simple implementation)
    // final orderNumber = '${now.millisecondsSinceEpoch % 10000}';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Confirmation'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Header
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Order Summary',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // Text(
                            //   '#$orderNumber',
                            //   style: const TextStyle(
                            //     fontSize: 16,
                            //     fontWeight: FontWeight.bold,
                            //     color: Colors.blue,
                            //   ),
                            // ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Date: $formattedDate at $formattedTime',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Service Type: ${widget.serviceType}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500, 
                            color: Colors.grey[800]
                          ),
                        ),
                        if (orderProvider.selectedPerson != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Customer: ${orderProvider.selectedPerson!.name}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Order Items
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Items',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Item header
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  'Item',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Qty',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Price',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Total',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        
                        // Item list
                        ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Text(item.name),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${item.quantity}',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        item.price.toStringAsFixed(3),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        (item.price * item.quantity).toStringAsFixed(3),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Show kitchen note if it exists
                              if (item.kitchenNote.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                                  child: Row(
                                    children: [
                                      Icon(Icons.note, size: 14, color: Colors.blue.shade700),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          item.kitchenNote,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                                              
                        const Divider(thickness: 1.5),
                        
                        // Totals
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              const Expanded(
                                flex: 7,
                                child: Text(
                                  'Subtotal',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  orderProvider.subtotal.toStringAsFixed(3),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Expanded(
                              flex: 7,
                              child: Text(
                                'Tax',
                                textAlign: TextAlign.right,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                orderProvider.tax.toStringAsFixed(3),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        if (orderProvider.discount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Expanded(
                                flex: 7,
                                child: Text(
                                  'Discount',
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  orderProvider.discount.toStringAsFixed(3),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Expanded(
                              flex: 7,
                              child: Text(
                                'TOTAL',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                orderProvider.total.toStringAsFixed(3),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 100), // Space for the bottom buttons
              ],
            ),
          ),
          
          // Bottom action buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing 
                          ? null 
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isProcessing 
                          ? null 
                          : () => _processOrder(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[900],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isProcessing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.0,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('Processing...'),
                              ],
                            )
                          : const Text('Process Order'),
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

  Future<void> _processOrder() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    
    // Check if cart is empty
    if (orderProvider.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Process the order and generate bill - table status update happens inside this method
      final result = await orderProvider.processOrderWithBill(context);
      
      if (!mounted) return;
      
      if (result['success']) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
        
        // Navigate back to dashboard
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      } else {
        // Show error message but stay on page
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing order: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isProcessing = false;
      });
    }
  }
}