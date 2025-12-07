import 'package:cafeapp/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/order_provider.dart';
import 'dashboard_screen.dart';
import '../utils/app_localization.dart';
import '../utils/service_type_utils.dart';
import '../models/order.dart';
import '../repositories/local_order_repository.dart';


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
 
  @override
  void initState() {
    super.initState();
    
    // Make sure OrderProvider has the context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        orderProvider.setContext(context);
      }
    });
  }
 
  bool _isProcessing = false;

  // NEW: Calculate taxable amounts with tax-exempt handling
  Map<String, double> _calculateTaxableAmounts() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    
    double taxableTotal = 0.0;
    double taxExemptTotal = 0.0;
    
    for (var item in orderProvider.cartItems) {
      final itemTotal = item.price * item.quantity;
      if (item.taxExempt) {
        taxExemptTotal += itemTotal;
      } else {
        taxableTotal += itemTotal;
      }
    }
    
    double tax;
    double subtotal;
    double total;
    
    if (settingsProvider.isVatInclusive) {
      // Inclusive VAT: extract tax only from taxable items
      final taxableAmount = taxableTotal / (1 + (settingsProvider.taxRate / 100));
      tax = taxableTotal - taxableAmount;
      subtotal = taxableAmount + taxExemptTotal;
      total = taxableTotal + taxExemptTotal;
    } else {
      // Exclusive VAT: add tax on top of taxable items only
      subtotal = taxableTotal + taxExemptTotal;
      tax = taxableTotal * (settingsProvider.taxRate / 100);
      total = subtotal + tax;
    }
    
    return {
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'taxableTotal': taxableTotal,
      'taxExemptTotal': taxExemptTotal,
    };
  }

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
    
    // NEW: Get calculated amounts
    final amounts = _calculateTaxableAmounts();
    
    return Scaffold(
      appBar: AppBar(
        title:  Text('Order Confirmation'.tr()),
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
                           Text(
                              'Order Summary'.tr(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                       Text(
                        '${'Date'.tr()}: $formattedDate ${'at'.tr()} $formattedTime',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                        const SizedBox(height: 4),
                       Text(
                        ('${'Service Type'.tr()}: ${_getTranslatedServiceType(widget.serviceType)}'),
                        style: TextStyle(
                          fontWeight: FontWeight.w500, 
                          color: Colors.grey[800]   
                        ),
                      ),
                        if (orderProvider.selectedPerson != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Customer: ${orderProvider.selectedPerson!.name}'.tr(),
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
                         Text(
                          'Items'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Item header
                         Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  'Item'.tr(),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Qty'.tr(),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Price'.tr(),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Total'.tr(),
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
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(item.name)),
                                          // NEW: Show tax-exempt indicator
                                          if (item.taxExempt)
                                            Container(
                                              margin: const EdgeInsets.only(left: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange[100],
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.orange[300]!),
                                              ),
                                              child: Text(
                                                'Tax Free'.tr(),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange[800],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
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
                               Expanded(
                                flex: 7,
                                child: Text(
                                  'Subtotal'.tr(),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  amounts['subtotal']!.toStringAsFixed(3),
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
                             Expanded(
                              flex: 7,
                              child: Text(
                                'Tax'.tr(),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                amounts['tax']!.toStringAsFixed(3),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        // NEW: Show tax-exempt total if any
                        // if (amounts['taxExemptTotal']! > 0) ...[
                        //   const SizedBox(height: 4),
                        //   Row(
                        //     children: [
                        //       Expanded(
                        //         flex: 7,
                        //         child: Row(
                        //           mainAxisAlignment: MainAxisAlignment.end,
                        //           children: [
                        //             Text(
                        //               'Tax-Free Items'.tr(),
                        //               textAlign: TextAlign.right,
                        //               style: TextStyle(
                        //                 fontSize: 12,
                        //                 color: Colors.orange[700],
                        //               ),
                        //             ),
                        //           ],
                        //         ),
                        //       ),
                        //       Expanded(
                        //         flex: 3,
                        //         child: Text(
                        //           amounts['taxExemptTotal']!.toStringAsFixed(3),
                        //           textAlign: TextAlign.right,
                        //           style: TextStyle(
                        //             fontSize: 12,
                        //             color: Colors.orange[700],
                        //           ),
                        //         ),
                        //       ),
                        //     ],
                        //   ),
                        // ],
                        if (orderProvider.discount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                flex: 7,
                                child: Text(
                                  'Discount'.tr(),
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
                             Expanded(
                              flex: 7,
                              child: Text(
                                'TOTAL'.tr(),
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
                                (amounts['total']! - orderProvider.discount).toStringAsFixed(3),
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
                      child:  Text('Cancel'.tr()),
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
                          ?  Row(
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
                                Text('Processing...'.tr()),
                              ],
                            )
                          : Text('Process Order'.tr()),
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
  setState(() {
    _isProcessing = true;
  });

  try {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    final result = await orderProvider.processOrderWithBill(context);

    if (result['success']) {
      final Order? processedOrder = result['order'];
      
      // If we have a customer selected, update the order with customer info
      if (orderProvider.selectedPerson != null && processedOrder != null) {
        // Calculate tax and subtotal based on VAT type with tax-exempt handling
        double subtotal;
        double tax;
        double total;
        
        // Separate taxable and tax-exempt items
        double taxableTotal = 0.0;
        double taxExemptTotal = 0.0;
        
        for (var item in processedOrder.items) {
          final itemTotal = item.price * item.quantity;
          if (item.taxExempt) {
            taxExemptTotal += itemTotal;
          } else {
            taxableTotal += itemTotal;
          }
        }
        
        if (settingsProvider.isVatInclusive) {
          // Inclusive VAT: extract tax only from taxable items
          final taxableAmount = taxableTotal / (1 + (settingsProvider.taxRate / 100));
          tax = taxableTotal - taxableAmount;
          subtotal = taxableAmount + taxExemptTotal;
          total = (taxableTotal + taxExemptTotal) - processedOrder.discount;
        } else {
          // Exclusive VAT: add tax on top of taxable items only
          subtotal = (taxableTotal + taxExemptTotal) - processedOrder.discount;
          tax = taxableTotal * (settingsProvider.taxRate / 100);
          total = subtotal + tax;
        }
        
        // Create updated order with customer ID and correct tax calculation
        final updatedOrder = Order(
          id: processedOrder.id,
          staffDeviceId: processedOrder.staffDeviceId,
          serviceType: processedOrder.serviceType,
          items: processedOrder.items,
          subtotal: subtotal,
          tax: tax,
          discount: processedOrder.discount,
          total: total,
          status: processedOrder.status,
          createdAt: processedOrder.createdAt,
          customerId: orderProvider.selectedPerson!.id,
          paymentMethod: processedOrder.paymentMethod,
        );
        
        // Save the updated order
        final localOrderRepo = LocalOrderRepository();
        await localOrderRepo.saveOrder(updatedOrder);
        debugPrint('Updated order with customer ID and VAT type: ${orderProvider.selectedPerson!.id}');
        debugPrint('Inclusive VAT: ${settingsProvider.isVatInclusive}, Total: $total, Tax: $tax, Subtotal: $subtotal');
        debugPrint('Taxable: $taxableTotal, Tax-Exempt: $taxExemptTotal');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Order processed successfully'.tr()),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to process order'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing order: $e'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}
  // Add these helper methods if you need service type display:
String _getTranslatedServiceType(String serviceType) {
  return ServiceTypeUtils.getTranslated(serviceType);
}

// IconData _getServiceTypeIcon(String serviceType) {
//   return ServiceTypeUtils.getIcon(serviceType);
// }

// Color _getServiceTypeColor(String serviceType) {
//   return ServiceTypeUtils.getColor(serviceType);
// }

}