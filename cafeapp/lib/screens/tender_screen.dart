import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../models/order_history.dart';
import '../services/bill_service.dart';
import '../utils/extensions.dart';
import '../providers/order_history_provider.dart';
import '../screens/order_list_screen.dart';
import 'dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../providers/table_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../providers/order_provider.dart';
import '../models/person.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../repositories/local_order_repository.dart';

class TenderScreen extends StatefulWidget {
  final OrderHistory order;
  final bool isEdited;
  final double taxRate;
  final String? preselectedPaymentMethod; 
  final bool showBankDialogOnLoad; 
  final Person? customer;

  const TenderScreen({
    super.key, 
    required this.order,
    this.isEdited = false, 
    this.taxRate = 5.0,
    this.preselectedPaymentMethod,
    this.showBankDialogOnLoad = false,
    this.customer,
  });

  @override
  State<TenderScreen> createState() => _TenderScreenState();
}

class _TenderScreenState extends State<TenderScreen> {
  String? _selectedPaymentMethod; // No default payment method
  String _amountInput = '0.000';
  double _balanceAmount = 0.0;
  double _paidAmount = 0.0; // Track the paid amount separately
  bool _isProcessing = false;
  bool _isCashSelected = false;
  final Map<String, Map<String, double>> _serviceTotals = {};
  final String _currentServiceType = '';

  String _orderStatus = 'pending'; // Track the current order status
  final LocalOrderRepository _localOrderRepo = LocalOrderRepository();
  final MethodChannel _channel = const MethodChannel('com.simsrestocafe/file_picker');

  // Credit card payment data
  String _selectedCardType = 'VISA'; // Default card type
  final TextEditingController _lastFourDigitsController = TextEditingController();
  final TextEditingController _approvalCodeController = TextEditingController();
  final TextEditingController _receivedAmountController = TextEditingController();
  
  // Focus nodes for text fields
  final FocusNode _lastFourFocusNode = FocusNode();
  final FocusNode _approvalFocusNode = FocusNode();
  final FocusNode _receivedFocusNode = FocusNode();
  
  // Available card types
  final List<Map<String, dynamic>> _cardTypes = [
    {'name': 'VISA', 'color': Colors.blue.shade100},
    {'name': 'Master Card', 'color': Colors.grey.shade200},
    {'name': 'American Express', 'color': Colors.grey.shade200},
    {'name': 'Discover', 'color': Colors.grey.shade200},
    {'name': 'Carte Blanche', 'color': Colors.grey.shade200},
    {'name': 'Diners Club', 'color': Colors.grey.shade200},
    {'name': 'JCB', 'color': Colors.grey.shade200},
  ];

  @override
  void initState() {
    super.initState();
    // Initialize the current service type from the widget
    // _currentServiceType = widget.serviceType;
    
    // Initialize balance amount based on order status
    _orderStatus = widget.order.status; // Initialize with current status
    
    // Set the preselected payment method if provided
    if (widget.preselectedPaymentMethod != null) {
      _selectedPaymentMethod = widget.preselectedPaymentMethod;
      _isCashSelected = _selectedPaymentMethod == 'Cash';
    }
     // Initialize service totals if needed
    if (!_serviceTotals.containsKey(_currentServiceType)) {
      _serviceTotals[_currentServiceType] = {
        'subtotal': 0.0,
        'tax': 0.0,
        'discount': 0.0,
        'total': widget.order.total,
      };
    }
    
    // If order is already completed, set balance to 0 and paid to total
    if (_orderStatus.toLowerCase() == 'completed') {
      _balanceAmount = 0.0;
      _paidAmount = widget.order.total;
    } else {
      // Normal initialization for pending orders
      _balanceAmount = widget.order.total;
      _paidAmount = 0.0;
    }
 
    debugPrint('Initial balance: $_balanceAmount, Initial paid: $_paidAmount, Status: $_orderStatus');
    if (widget.showBankDialogOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBankPaymentDialog(); // This will automatically show the bank payment dialog
      });
    }
  }
  
  @override
  void dispose() {
    _lastFourDigitsController.dispose();
    _approvalCodeController.dispose();
    _receivedAmountController.dispose();
    _lastFourFocusNode.dispose();
    _approvalFocusNode.dispose();
    _receivedFocusNode.dispose();
    super.dispose();
  }
  //  Create a helper method to get the discounted total amount
double _getDiscountedTotal() {
  // Get current discount amount
  double discount = 0.0;
  if (_serviceTotals.containsKey(_currentServiceType)) {
    discount = _serviceTotals[_currentServiceType]!['discount'] ?? 0.0;
  }
  
  // Calculate total with discount applied
  return widget.order.total - discount;
}

//  Create a helper method to get the current discount amount
double _getCurrentDiscount() {
  if (_serviceTotals.containsKey(_currentServiceType)) {
    return _serviceTotals[_currentServiceType]!['discount'] ?? 0.0;
  }
  return 0.0;
}
void _applyDiscount(double discountAmount) {
  if (discountAmount <= 0) return;
  
  // Make sure discount doesn't exceed the total amount
  final effectiveDiscount = discountAmount > widget.order.total ? widget.order.total : discountAmount;
  
  setState(() {
    // Update balance amount - this affects both cash and bank payments
    _balanceAmount = widget.order.total - effectiveDiscount;
    if (_balanceAmount < 0) _balanceAmount = 0.0;
    
    // For consistent experience, also update the service totals dictionary
    if (_serviceTotals.containsKey(_currentServiceType)) {
      // Get the current totals
      final totals = _serviceTotals[_currentServiceType]!;
      
      // Update the discount value
      totals['discount'] = effectiveDiscount;
      
      // Recalculate the total with the new discount
      totals['total'] = totals['subtotal']! + totals['tax']! - totals['discount']!;
      
      _serviceTotals[_currentServiceType] = totals;
    }
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Discount of ${effectiveDiscount.toStringAsFixed(3)} applied successfully'),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  });
}


  Future<void> _showBillPreviewDialog() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // Generate PDF
      final pdf = await _generateReceipt();
      
      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final pdfPath = '${tempDir.path}/bill_preview_${widget.order.id}.pdf';
      final file = File(pdfPath);
      await file.writeAsBytes(await pdf.save());
      
      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();
      
      // Show the preview in a fullscreen dialog
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: EdgeInsets.zero, // Full screen dialog
          child: Column(
            children: [
              // App bar with close button
              Container(
                color: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              // PDF Viewer
              Expanded(
                child: PDFView(
                  filePath: pdfPath,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: false,
                  pageFling: true,
                  fitPolicy: FitPolicy.BOTH,
                  fitEachPage: false,    
                  defaultPage: 0,
                  onError: (error) {
                    debugPrint('Error loading PDF: $error');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error loading PDF preview')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating bill preview: $e')),
        );
      }
    }
  }

  // Update order status in the local database
  Future<bool> _updateOrderStatus(String status) async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Get all orders from local database
      final orders = await _localOrderRepo.getAllOrders();
      final orderIndex = orders.indexWhere((o) => o.id == widget.order.id);
      
      if (orderIndex >= 0) {
        // Found the order, update its status
        final order = orders[orderIndex];
        
        // Create updated order with new status
        final updatedOrder = Order(
          id: order.id,
          serviceType: order.serviceType,
          items: order.items,
          subtotal: order.subtotal,
          tax: order.tax,
          discount: order.discount,
          total: order.total,
          status: status,
          createdAt: order.createdAt,
          customerId: order.customerId,
          paymentMethod: order.paymentMethod,
        );
        
        // Save the updated order
        await _localOrderRepo.saveOrder(updatedOrder);
        
        if (mounted) {
          setState(() {
            _orderStatus = status;
          });
        }
        
        // Refresh the order history list to show updated status
        if (mounted) {
          Provider.of<OrderHistoryProvider>(context, listen: false).loadOrders();
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Updated _processPayment method to handle change similar to cash payments
  Future<void> _processPayment(double amount) async {
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }
    
    if (amount <= 0) return;

    setState(() {
      _isProcessing = true;
    });

   // Get the discounted total amount
  final discountedTotal = _getDiscountedTotal();
  
      double change = 0.0;
  if (amount > discountedTotal) {
    change = amount - discountedTotal;
  }



    try {
      // Store the correct payment method
      final paymentMethod = _selectedPaymentMethod!.toLowerCase();
      Order? savedOrder;
       // Get the current discount amount from service totals
    double discountAmount = 0.0;
    if (_serviceTotals.containsKey(_currentServiceType)) {
      discountAmount = _serviceTotals[_currentServiceType]!['discount'] ?? 0.0;
    }
      
      // Check if we're updating an existing order or creating a new one
      if (widget.order.id != 0) {
        // Update existing order - Find in local database
        final orders = await _localOrderRepo.getAllOrders();
        final orderIndex = orders.indexWhere((o) => o.id == widget.order.id);
        
        if (orderIndex >= 0) {
          final existingOrder = orders[orderIndex];
          
          // Create updated order with completed status and payment method
          savedOrder = Order(
            id: existingOrder.id,
            serviceType: existingOrder.serviceType,
            items: existingOrder.items,
            subtotal: widget.order.total - (widget.order.total * (widget.taxRate / 100)),
            tax: widget.order.total * (widget.taxRate / 100),
            discount: discountAmount, // No discount
            total: widget.order.total- discountAmount,
            status: 'completed', // Mark as completed
            createdAt: existingOrder.createdAt,
            customerId: widget.customer?.id ?? existingOrder.customerId,
            paymentMethod: paymentMethod
          );
          
          // Save the updated order
          savedOrder = await _localOrderRepo.saveOrder(savedOrder);
        }
      } else {
        // Create a new order - should rarely happen from tender screen
        debugPrint('Creating new order in TenderScreen - unusual case');
        
        // Convert OrderHistory items to OrderItem objects
        final orderItems = widget.order.items.map((item) => 
          OrderItem(
            id: item.id,
            name: item.name,
            price: item.price,
            quantity: item.quantity,
            kitchenNote: item.kitchenNote,
          )
        ).toList();
        
        // Create a new order
        savedOrder = Order(
          serviceType: widget.order.serviceType,
          items: orderItems,
          subtotal: widget.order.total - (widget.order.total * (widget.taxRate / 100)),
          tax: widget.order.total * (widget.taxRate / 100),
          discount: discountAmount, // No discount
          total: widget.order.total - discountAmount,
          status: 'completed', // Mark as completed
          createdAt: DateTime.now().toIso8601String(),
          customerId: widget.customer?.id,
          paymentMethod: paymentMethod,
        );
        
        // Save the new order
        savedOrder = await _localOrderRepo.saveOrder(savedOrder);
      }
      
      if (savedOrder == null) {
        throw Exception('Failed to process order in the system');
      }
      
      // Update the widget order ID if it was a new order
      if (widget.order.id == 0) {
        widget.order.id = savedOrder.id ?? 0;
      }
      
      // Update the order status to completed
      final statusUpdated = await _updateOrderStatus('completed');
      
      if (!statusUpdated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update order status, but continuing with payment processing')),
          );
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      final savedPrinterName = prefs.getString('selected_printer');
      debugPrint('Selected printer: $savedPrinterName');
      
      final pdf = await _generateReceipt();

      bool printed = false;
      try {
        printed = await BillService.printThermalBill(widget.order, isEdited: widget.isEdited, taxRate: widget.taxRate);
      } catch (e) {
        debugPrint('Printing error: $e');
        debugPrint('Attempted to print using: $savedPrinterName');
      }
      
      bool? saveAsPdf = false;
      if (!printed) {
        if (mounted) {
          saveAsPdf = await _showSavePdfDialog();
        }
        
        if (saveAsPdf == true) {
          try {
            await _saveWithAndroidIntent(pdf);
          } catch (e) {
            debugPrint('Error saving PDF: $e');
          }
        }
      }
      
      // Check if this order is for a dining table
      if (widget.order.serviceType.contains('Dining - Table')) {
        // Extract table number from service type
        final tableNumberStr = widget.order.serviceType.split('Table ').last;
        final tableNumber = int.tryParse(tableNumberStr);
        
        if (tableNumber != null && mounted) {
          // Get table provider and update table status
          final tableProvider = Provider.of<TableProvider>(context, listen: false);
          
          // Find the table with this number and set it to available
          await tableProvider.setTableStatus(tableNumber, false);
          debugPrint('Table $tableNumber status set to available after payment');
        }
      }
      
      // Clear the cart items after successful payment
      if (mounted) {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        orderProvider.clearSelectedPerson(); 
        orderProvider.clearCart(); // This will clear all items from the current cart
      }
      
      if (mounted) {
        if (change > 0) {
          await _showBalanceMessageDialog(change);
        } else {
          await _showBalanceMessageDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing payment: $e')),
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
  // Method to show the discount dialog
void _showDiscountDialog() {
  // Current total for reference
  final currentTotal = widget.order.total;
  
  // Create a dialog that fits without scrolling
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      String discountInput = '0.000';
      double discountAmount = 0.0;
      
      // Get screen size to calculate appropriate dialog size
      final screenSize = MediaQuery.of(context).size;
      
      return StatefulBuilder(
        builder: (context, setState) {
          // Parse current input on each rebuild
          discountAmount = double.tryParse(discountInput) ?? 0.0;
          
          // Use Material directly with no size constraints
          return Material(
            type: MaterialType.transparency,
            child: Center(
              child: Container(
                width: screenSize.width * 0.7, // 70% of screen width
                height: screenSize.height * 0.9, // 90% of screen height
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(77),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.discount, color: Colors.purple.shade800, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Apply Discount',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Expanded(
                      child: SingleChildScrollView( // Make it scrollable as a fallback
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Current total and new total in one row
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Left side - current total
                                    Row(
                                      children: [
                                        const Text('Current Total : ', style: TextStyle(fontSize: 16)),
                                        Text(
                                          currentTotal.toStringAsFixed(3),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Divider
                                    Container(
                                      height: 24,
                                      width: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                    
                                    // Right side - new total
                                    Row(
                                      children: [
                                        const Text('New Total : ', style: TextStyle(fontSize: 16)),
                                        Text(
                                          (currentTotal - discountAmount).toStringAsFixed(3),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: discountAmount > 0 ? Colors.green.shade800 : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Quick select buttons in a row
                              // Text(
                              //   'Quick Select:',
                              //   style: TextStyle(
                              //     fontWeight: FontWeight.w500,
                              //     color: Colors.grey.shade700,
                              //     fontSize: 16,
                              //   ),
                              // ),
                              
                              const SizedBox(height: 12),
                              // Quick select buttons centered in the dialog
                              Container(
                                width: double.infinity,
                                alignment: Alignment.center, // Center the content horizontally
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center, // Center the row contents
                                    children: [
                                      _buildQuickAmountButton('5', () {
                                        setState(() {
                                          discountInput = '5.000';
                                        });
                                      }),
                                      const SizedBox(width: 8),
                                      _buildQuickAmountButton('10', () {
                                        setState(() {
                                          discountInput = '10.000';
                                        });
                                      }),
                                      const SizedBox(width: 8),
                                      _buildQuickAmountButton('15', () {
                                        setState(() {
                                          discountInput = '15.000';
                                        });
                                      }),
                                       const SizedBox(width: 8),
                                      _buildQuickAmountButton('25', () {
                                        setState(() {
                                          discountInput = '25.000';
                                        });
                                      }),
                                      const SizedBox(width: 8),
                                      _buildQuickAmountButton('50', () {
                                        setState(() {
                                          discountInput = '50.000';
                                        });
                                      }),
                                      const SizedBox(width: 8),
                                      _buildQuickAmountButton('100', () {
                                        setState(() {
                                          discountInput = '100.000';
                                        });
                                      }),
                                      const SizedBox(width: 8),
                  
                                    ],
                                  ),
                                ),
                              ),
                                                            
                              
                              const SizedBox(height: 20),
                              
                              // Discount input display with label
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Discount Amount : ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.grey.shade50,
                                    ),
                                    child: Text(
                                      discountInput,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 20),
                              // Numpad with calculator style layout
                              SizedBox(
                                height: 250, // Set a fixed height to make it more compact
                                child: Column(
                                  children: [
                                    // First row: 7, 8, 9
                                    Expanded(
                                      child: Row(
                                        children: [
                                          _buildDiscountNumpadButton('7', () {
                                            setState(() {
                                              if (discountInput == '0.000'|| discountInput == '0') {
                                                discountInput = '7';
                                              } else {
                                                discountInput += '7';
                                              }
                                            });
                                          }),
                                          _buildDiscountNumpadButton('8', () {
                                            setState(() {
                                              if (discountInput == '0.000'|| discountInput == '0') {
                                                discountInput = '8';
                                              } else {
                                                discountInput += '8';
                                              }
                                            });
                                          }),
                                          _buildDiscountNumpadButton('9', () {
                                            setState(() {
                                              if (discountInput == '0.000'|| discountInput == '0') {
                                                discountInput = '9';
                                              } else {
                                                discountInput += '9';
                                              }
                                            });
                                          }),
                                        ],
                                      ),
                                    ),
                                    // Second row: 4, 5, 6
                                    Expanded(
                                      child: Row(
                                        children: [
                                          _buildDiscountNumpadButton('4', () {
                                            setState(() {
                                              if (discountInput == '0.000'|| discountInput == '0') {
                                                discountInput = '4';
                                              } else {
                                                discountInput += '4';
                                              }
                                            });
                                          }),
                                          _buildDiscountNumpadButton('5', () {
                                            setState(() {
                                              if (discountInput == '0.000'|| discountInput == '0') {
                                                discountInput = '5';
                                              } else {
                                                discountInput += '5';
                                              }
                                            });
                                          }),
                                          _buildDiscountNumpadButton('6', () {
                                            setState(() {
                                              if (discountInput == '0.000'|| discountInput == '0') {
                                                discountInput = '6';
                                              } else {
                                                discountInput += '6';
                                              }
                                            });
                                          }),
                                        ],
                                      ),
                                    ),
                                    // Third row: 1, 2, 3
                                    Expanded(
                                      child: Row(
                                        children: [
                                          _buildDiscountNumpadButton('1', () {
                                            setState(() {
                                              if (discountInput == '0.000'|| discountInput == '0') {
                                                discountInput = '1';
                                              } else {
                                                discountInput += '1';
                                              }
                                            });
                                          }),
                                          _buildDiscountNumpadButton('2', () {
                                            setState(() {
                                              if (discountInput == '0.000'|| discountInput == '0') {
                                                discountInput = '2';
                                              } else {
                                                discountInput += '2';
                                              }
                                            });
                                          }),
                                          _buildDiscountNumpadButton('3', () {
                                            setState(() {
                                              if (discountInput == '0.000'|| discountInput == '0') {
                                                discountInput = '3';
                                              } else {
                                                discountInput += '3';
                                              }
                                            });
                                          }),
                                        ],
                                      ),
                                    ),
                                    // Fourth row: C, 0, ⌫
                                    Expanded(
                                      child: Row(
                                        children: [
                                           _buildDiscountNumpadButton('C', () {
                                            setState(() {
                                              discountInput = '0.000';
                                            });
                                          }, backgroundColor: Colors.red.shade50, textColor: Colors.red.shade800),
                                         
                                          _buildDiscountNumpadButton('0', () {
                                            setState(() {
                                              if (discountInput == '0.000') {
                                                discountInput = '0';
                                              } else if (discountInput == '0') {
                                                // If it's already just 0, keep it as 0
                                                discountInput = '0';
                                             } else {
                                                discountInput += '0';
                                              }
                                            });
                                          }),
                                          _buildDiscountNumpadButton('⌫', () {
                                            setState(() {
                                              if (discountInput.length > 1) {
                                                discountInput = discountInput.substring(0, discountInput.length - 1);
                                                if (discountInput.isEmpty) {
                                                  discountInput = '0.000';
                                                }
                                              } else {
                                                discountInput = '0.000';
                                              }
                                            });
                                          }, backgroundColor: Colors.grey.shade200, textColor: Colors.black87, isBackspace: true),
                                        ],
                                      ),
                                    ),
                                
                                  ],
                                ),
                              )
                             
                                                          
                             
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Footer with action buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              textStyle: const TextStyle(fontSize: 16),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              _applyDiscount(discountAmount);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              textStyle: const TextStyle(fontSize: 16),
                            ),
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// Helper method to build numpad buttons for discount dialog
Widget _buildDiscountNumpadButton(String text, VoidCallback onTap, {
  Color? backgroundColor, 
  Color? textColor,
  bool isBackspace = false,
}) {
  return Expanded(
    child: Container(
      margin: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.blue.shade100,
          foregroundColor: textColor ?? Colors.blue.shade800,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: isBackspace 
          ? const Icon(Icons.backspace, size: 22)
          : Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
      ),
    ),
  );
}

// Helper method to build quick amount buttons
Widget _buildQuickAmountButton(String amount, VoidCallback onTap) {
  return ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.purple.shade50,
      foregroundColor: Colors.purple.shade800,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.purple.shade200),
      ),
      elevation: 1,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    child: Text(
      amount,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
  );
}

// Helper to build quick discount selection buttons
// Widget _buildQuickDiscountButton(String amount, StateSetter setState, TextEditingController controller) {
//     final isSelected = controller.text == amount;
    
//     return InkWell(
//       onTap: () {
//         setState(() {
//           // When button is tapped, update the controller value
//           controller.text = amount;
//         });
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         decoration: BoxDecoration(
//           color: isSelected ? Colors.purple.shade100 : Colors.grey.shade200,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(
//             color: isSelected ? Colors.purple.shade400 : Colors.grey.shade300,
//             width: isSelected ? 2 : 1,
//           ),
//         ),
//         child: Text(
//           amount,
//           style: TextStyle(
//             fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//             color: isSelected ? Colors.purple.shade800 : Colors.black87,
//           ),
//         ),
//       ),
//     );
//   }

  // Cancel the order
  Future<void> _cancelOrder() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm) {
      setState(() {
        _isProcessing = true;
      });
      
      try {
        final success = await _updateOrderStatus('cancelled');
        
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order cancelled successfully')),
            );
            
            // Navigate back to dashboard
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
              (route) => false,
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to cancel order. Please try again.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error cancelling order: $e')),
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
  }
  
  // Process bank payment dialog with suppressed device keyboard
  void _showBankPaymentDialog() {
    // Reset controllers
    _lastFourDigitsController.clear();
    _approvalCodeController.clear();
    // Get the discounted total amount
    final discountedTotal = _getDiscountedTotal();
  
     // Set the received amount to the discounted total
  _receivedAmountController.text = discountedTotal.toStringAsFixed(3);
    // Reset selected card type
    _selectedCardType = 'VISA';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Title row with back button and adjacent title
                    Row(
                      children: [
                        // Back button
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 24,
                        ),
                        const SizedBox(width: 8),
                        // Title next to back button
                        Text(
                          'Terminal credit card',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        // Expanded to push everything to the left
                        Expanded(child: Container()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Main content
                    Expanded(
                      child: Row(
                        children: [
                          // Left side - Form fields
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Balance amount
                                Row(
                                  children: [
                                    const Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Balance amount',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 6,
                                      child: Text(
                                        NumberFormat.currency(symbol: '', decimalDigits: 3).format(discountedTotal),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Received amount - Now read-only to prevent keyboard
                                Row(
                                  children: [
                                    const Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Received',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 6,
                                      child: TextField(
                                        controller: _receivedAmountController,
                                        focusNode: _receivedFocusNode,
                                        readOnly: true, // Prevent keyboard from showing
                                        decoration: InputDecoration(
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(color: Colors.blue.shade100, width: 2),
                                          ),
                                          focusedBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Last 4 digits - Now read-only to prevent keyboard
                                Row(
                                  children: [
                                    const Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Last 4 digit',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 6,
                                      child: TextField(
                                        controller: _lastFourDigitsController,
                                        focusNode: _lastFourFocusNode,
                                        readOnly: true, // Prevent keyboard from showing
                                        decoration: const InputDecoration(
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(color: Colors.grey, width: 1),
                                          ),
                                          focusedBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(color: Colors.blue, width: 2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Approval code - Now read-only to prevent keyboard
                                Row(
                                  children: [
                                    const Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Approval code',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 6,
                                      child: TextField(
                                        controller: _approvalCodeController,
                                        focusNode: _approvalFocusNode,
                                        readOnly: true, // Prevent keyboard from showing
                                        decoration: const InputDecoration(
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(color: Colors.grey, width: 1),
                                          ),
                                          focusedBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(color: Colors.blue, width: 2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                
                                // Card options grid
                                Expanded(
                                  child: GridView.builder(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      childAspectRatio: 2.5,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                    itemCount: _cardTypes.length,
                                    itemBuilder: (context, index) {
                                      final card = _cardTypes[index];
                                      final bool isSelected = _selectedCardType == card['name'];
                                      
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedCardType = card['name'];
                                            
                                            // Update all card colors
                                            for (var i = 0; i < _cardTypes.length; i++) {
                                              if (i == index) {
                                                _cardTypes[i]['color'] = Colors.blue.shade100;
                                              } else {
                                                _cardTypes[i]['color'] = Colors.grey.shade200;
                                              }
                                            }
                                          });
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: card['color'],
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300,
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            card['name'],
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isSelected ? Colors.blue.shade800 : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Right side - Number pad with OK button
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.only(left: 16),
                              child: Column(
                                children: [
                                  // First row (7 8 9)
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(child: _buildNumberPadDialogButton('7', setState)),
                                        Expanded(child: _buildNumberPadDialogButton('8', setState)),
                                        Expanded(child: _buildNumberPadDialogButton('9', setState)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10), // Increased spacing
                                  
                                  // Second row (4 5 6)
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(child: _buildNumberPadDialogButton('4', setState)),
                                        Expanded(child: _buildNumberPadDialogButton('5', setState)),
                                        Expanded(child: _buildNumberPadDialogButton('6', setState)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8), // Increased spacing
                                  
                                  // Third row (1 2 3)
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(child: _buildNumberPadDialogButton('1', setState)),
                                        Expanded(child: _buildNumberPadDialogButton('2', setState)),
                                        Expanded(child: _buildNumberPadDialogButton('3', setState)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8), // Increased spacing
                                  
                                  // Fourth row (000 0 ⌫)
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(child: _buildNumberPadDialogButton('000', setState)),
                                        Expanded(child: _buildNumberPadDialogButton('0', setState)),
                                        Expanded(
                                          child: _buildNumberPadDialogButton('⌫', setState, isBackspace: true),
                                        ),
                                        
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8), // Increased spacing
                                  
                                  // Fifth row (C OK)
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(child: _buildNumberPadDialogButton('C', setState)),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              String receivedAmount = _receivedAmountController.text.trim();
                                              double amount = double.tryParse(receivedAmount) ?? 0.0;
                                              if (amount > 0) {
                                                _showPaymentConfirmationDialog(amount);
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Please enter a valid amount')),
                                                );
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                            ),
                                            child: const Text(
                                              'OK',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
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
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Modified _buildNumberPadDialogButton method to support backspace styling
  Widget _buildNumberPadDialogButton(String text, StateSetter setState, {bool isBackspace = false}) {
    return Container(
      margin: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: () {
          // Determine which controller to use based on focus
          TextEditingController controller;
          if (_lastFourFocusNode.hasFocus) {
            controller = _lastFourDigitsController;
          } else if (_approvalFocusNode.hasFocus) {
            controller = _approvalCodeController;
          } else if (_receivedFocusNode.hasFocus) {
            controller = _receivedAmountController;
          } else {
            // If nothing is focused, default to received amount and focus it
            controller = _receivedAmountController;
            FocusScope.of(context).requestFocus(_receivedFocusNode);
          }
          
          if (text == 'C') {
            setState(() {
              controller.clear();
            });
          } else if (text == '⌫') {
            // Backspace logic
            if (controller.text.isNotEmpty) {
              setState(() {
                controller.text = controller.text
                  .substring(0, controller.text.length - 1);
              });
            }
          } else {
            // Append text to current controller value
            setState(() {
              controller.text = controller.text + text;
            });
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isBackspace ? Colors.grey.shade200 : Colors.white,
          foregroundColor: isBackspace ? Colors.black87 : Colors.black87,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        child: isBackspace 
          ? const Icon(Icons.backspace, size: 22)
          : Text(
              text,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
      ),
    );
  }

  // Apply exact bill amount
  void _applyExactAmount() {
    // Check for payment method first
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    // Make sure we have a payment to process
    if (_balanceAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No remaining balance to pay')),
      );
      return;
    }

    // Use the exact balance amount
    double amount = _getDiscountedTotal();
    
    // Check if widget is still mounted before continuing
    if (!mounted) return;
    
    _showPaymentConfirmationDialog(amount);
  }
  // Updated _showPaymentConfirmationDialog method to handle both Cash and Bank payments consistently
  Future<void> _showPaymentConfirmationDialog(double amount) async {
    // Check for payment method first
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    // Make sure we have a payment to process
    if (_balanceAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No remaining balance to pay')),
      );
      return;
    }
    
    // Calculate the correct change amount
    // For bank payments, we compare with the total order amount, not the balance
    double change = 0.0;
    if (_selectedPaymentMethod == 'Bank') {
      // For bank payments, calculate against total order amount
      if (amount > widget.order.total) {
        change = amount - widget.order.total;
      }
    } else {
      // For cash payments, calculate against current balance
      if (amount > _balanceAmount) {
        change = amount - _balanceAmount;
      }
    }
    
    // Check if widget is still mounted before continuing
    if (!mounted) return;
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text('Do you want to print?'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop('cancel');
              },
            ),
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(dialogContext).pop('no');
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(dialogContext).pop('yes');
              },
            ),
          ],
        );
      },
    );

    // Check if widget is still mounted before continuing
    if (!mounted) return;

    if (result == 'cancel') {
      // User canceled the payment
      return;
    }

    // Process the payment
    if (result == 'yes' || result == 'no') {
      setState(() {
        if (_selectedPaymentMethod == 'Cash') {
          // For cash payments, we use the existing logic for partial payments
          double amountToDeduct = _balanceAmount < amount ? _balanceAmount : amount;
          
          // Update the balance amount (remaining balance)
          _balanceAmount -= amountToDeduct;
          if (_balanceAmount < 0) _balanceAmount = 0;
          
          // Update the paid amount
          _paidAmount += amountToDeduct;
        } else {
          // For bank payments, we always pay the full amount in one go
          _paidAmount = widget.order.total;
          _balanceAmount = 0;
        }
        
        debugPrint('Payment processed. Amount: $amount, Change: $change');
        debugPrint('New balance: $_balanceAmount, Total paid: $_paidAmount');
      });
      
      // Show success message with change information
      if (change > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment of ${NumberFormat.currency(symbol: '', decimalDigits: 3).format(amount)} accepted. Return change: ${NumberFormat.currency(symbol: '', decimalDigits: 3).format(change)}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment of ${NumberFormat.currency(symbol: '', decimalDigits: 3).format(amount)} accepted.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      
      // If user chose to print, generate receipt
      if (result == 'yes') {
        // For both Cash and Bank payment methods, process using their respective methods
        if (_selectedPaymentMethod == 'Cash') {
          _processCashPayment(amount, change);
        } else {
          _processPayment(amount);
        }
      } else if (_balanceAmount <= 0) {
        // If bill is fully paid but user chose not to print, just show a message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment complete!'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        // Update order status to completed
        _updateOrderStatus('completed');
        
        // Show the balance dialog with the change amount
        if (change > 0) {
          _showBalanceMessageDialog(change);
        } else {
          _showBalanceMessageDialog();
        }
      }
    }
  }
  // New method to process cash payment
  Future<void> _processCashPayment(double amount, double change) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Handle a cash payment completely locally
      Order? savedOrder;
        // Get the current discount amount from service totals
          // Get the current discount amount from service totals
    double discountAmount = 0.0;
    if (_serviceTotals.containsKey(_currentServiceType)) {
      discountAmount = _serviceTotals[_currentServiceType]!['discount'] ?? 0.0;
    }
   
      
      // Check if we're updating an existing order or creating a new one
      if (widget.order.id != 0) {
        // Find the order in local storage
        final orders = await _localOrderRepo.getAllOrders();
        final orderIndex = orders.indexWhere((o) => o.id == widget.order.id);
        
        if (orderIndex >= 0) {
          final existingOrder = orders[orderIndex];
          
          // Create updated order with completed status and cash payment method
          savedOrder = Order(
            id: existingOrder.id,
            serviceType: existingOrder.serviceType,
            items: existingOrder.items,
            subtotal: widget.order.total - (widget.order.total * (widget.taxRate / 100)),
            tax: widget.order.total * (widget.taxRate / 100),
            discount: discountAmount, // No discount
            total: widget.order.total - discountAmount,
            status: 'completed', // Mark as completed
            createdAt: existingOrder.createdAt,
            customerId: widget.customer?.id ?? existingOrder.customerId,
            paymentMethod: 'cash'
          );
          
          // Save the updated order directly to local database
          savedOrder = await _localOrderRepo.saveOrder(savedOrder);
          debugPrint('Updated order with cash payment method: ${savedOrder.id}');
        } else {
          throw Exception('Order not found in local database');
        }
      } else {
        // Create a new order in the local database
        debugPrint('Creating new order with cash payment');
        
        // Convert OrderHistory items to OrderItem objects
        final orderItems = widget.order.items.map((item) => 
          OrderItem(
            id: item.id,
            name: item.name,
            price: item.price,
            quantity: item.quantity,
            kitchenNote: item.kitchenNote,
          )
        ).toList();
        
        // Create a new order with completed status
        savedOrder = Order(
          serviceType: widget.order.serviceType,
          items: orderItems,
          subtotal: widget.order.total - (widget.order.total * (widget.taxRate / 100)),
          tax: widget.order.total * (widget.taxRate / 100),
          discount: discountAmount, // No discount
          total: widget.order.total - discountAmount,
          status: 'completed', // Mark as completed
          createdAt: DateTime.now().toIso8601String(),
          customerId: widget.customer?.id,
          paymentMethod: 'cash',
        );
        
        // Save the new order to local database
        savedOrder = await _localOrderRepo.saveOrder(savedOrder);
        debugPrint('Created new order with cash payment: ${savedOrder.id}');
      }
      
      if (savedOrder == null) {
        throw Exception('Failed to process order in the system');
      }
      
      // Update the widget order ID if it was a new order
      if (widget.order.id == 0) {
        widget.order.id = savedOrder.id ?? 0;
      }
      
      // Update the order status to completed in local database
      final statusUpdated = await _updateOrderStatus('completed');
      
      if (!statusUpdated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update order status, but continuing with payment processing')),
          );
        }
      }
      
      // Generate PDF receipt
      final pdf = await _generateReceipt();
      
      // Try to print the receipt
      bool printed = false;
      try {
        printed = await BillService.printThermalBill(widget.order, isEdited: widget.isEdited, taxRate: widget.taxRate);
      } catch (e) {
        debugPrint('Printing error: $e');
      }

      // If printing failed, offer to save as PDF
      bool? saveAsPdf = false;
      if (!printed) {
        if (mounted) {
          saveAsPdf = await _showSavePdfDialog();
        }
        
        if (saveAsPdf == true) {
          try {
            // Use Android's native file picker intent to save the file
            await _saveWithAndroidIntent(pdf);
          } catch (e) {
            debugPrint('Error saving PDF: $e');
          }
        }
      }
      
      // Update table status if this is a dining order
      if (widget.order.serviceType.contains('Dining - Table')) {
        // Extract table number from service type
        final tableNumberStr = widget.order.serviceType.split('Table ').last;
        final tableNumber = int.tryParse(tableNumberStr);
        
        if (tableNumber != null && mounted) {
          // Get table provider and update table status to available
          final tableProvider = Provider.of<TableProvider>(context, listen: false);
          
          // Set table status to available (false = not occupied)
          await tableProvider.setTableStatus(tableNumber, false);
          debugPrint('Table $tableNumber status set to available after cash payment');
        }
      }
      
      // Clear the cart after successful payment
      if (mounted) {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        orderProvider.clearSelectedPerson(); 
        orderProvider.clearCart();
      }
      
      // Refresh order history provider to update the UI
      if (mounted) {
        Provider.of<OrderHistoryProvider>(context, listen: false).refreshOrdersAndConnectivity();
      }
      
      // Show balance message dialog with change amount
      if (mounted) {
        await _showBalanceMessageDialog(change);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing payment: $e')),
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

 
  // Updated method with optional parameter
  Future<void> _showBalanceMessageDialog([double change = 0.0]) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.4,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.blue,
                  size: 50,
                ),
                const SizedBox(height: 16),
                Text(
                  change > 0 
                      ? 'Balance amount is ${NumberFormat.currency(symbol: '', decimalDigits: 3).format(change)}'
                      : 'Balance amount is 0.000',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      // Navigate to order list screen
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const OrderListScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Update amount input in the number pad
  void _updateAmount(String value) {
    // Don't update if no payment method is selected
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method first')),
      );
      return;
    }
    
    if (value == 'C') {
      setState(() {
        _amountInput = '0.000';
      });
      return;
    }

    if (value == 'Add') {
      // Parse amount carefully, ensuring we get a proper double
      String cleanInput = _amountInput.replaceAll(',', '.');
      double amount = double.tryParse(cleanInput) ?? 0.0;
      
      debugPrint('Add button pressed. Amount input: $_amountInput, Parsed amount: $amount');
      
      if (amount > 0) {
        // Check for payment method
        if (_selectedPaymentMethod == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a payment method')),
          );
          return;
        }
        // Check if it's a cash payment
      if (_selectedPaymentMethod == 'Cash') {
        // Calculate the amount to deduct and potential change
        double amountToDeduct = amount > _balanceAmount ? _balanceAmount : amount;
        double change = amount > _balanceAmount ? amount - _balanceAmount : 0.0;
        
        setState(() {
          // Update the balance amount
          _balanceAmount -= amountToDeduct;
          if (_balanceAmount < 0) _balanceAmount = 0;
          
          // Update the paid amount
          _paidAmount += amountToDeduct;
          
          // Clear input after adding
          _amountInput = '0.000';
        });
        
        // If fully paid, process the payment
        if (_balanceAmount <= 0) {
          _processCashPayment(amount, change);
        }
      } else {
        setState(() {
          // Debug output before calculation
          debugPrint('Before calculation - Current balance: $_balanceAmount, Amount to add: $amount');
          
          // Calculate the amount to deduct
          double amountToDeduct = amount > _balanceAmount ? _balanceAmount : amount;
          
          // Calculate the new balance
          double newBalance = _balanceAmount - amountToDeduct;
          
          // Debug output after calculation
          debugPrint('After calculation - New balance: $newBalance');
          
          // Update the balance amount
          _balanceAmount = newBalance;
          
          // Update the paid amount
          _paidAmount += amountToDeduct;
          
          // Debug final state
          debugPrint('Paid amount: $_paidAmount, Final balance: $_balanceAmount');
          
          // Clear input after adding
          _amountInput = '0.000';
          
          // If fully paid, update the order status
          if (_balanceAmount <= 0) {
            _updateOrderStatus('completed');
          }
        });
      }
      }
      return;
    }

    // Handle backspace
    if (value == '⌫') {
      if (_amountInput.length > 1) {
        setState(() {
          _amountInput = _amountInput.substring(0, _amountInput.length - 1);
          if (_amountInput.isEmpty || _amountInput == '0') {
            _amountInput = '0.000';
          }
        });
      } else {
        setState(() {
          _amountInput = '0.000';
        });
      }
      return;
    }

    // Handle numeric input
    setState(() {
      if (_amountInput == '0.000') {
        _amountInput = value;
      } else {
        _amountInput += value;
      }
    });
  }

  // Build the payment method selection
  Widget _buildPaymentMethodSelection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      // Add top margin to align with the coupon code section
      margin: const EdgeInsets.only(top: 55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPaymentMethodOption('Bank', Icons.account_balance),
          _buildPaymentMethodOption('Cash', Icons.money),
          // _buildPaymentMethodOption('Coupon', Icons.card_giftcard),
          _buildPaymentMethodOption('Customer Credit', Icons.person),
          _buildPaymentMethodOption('Credit Sale', Icons.credit_card),
        ],
      ),
    );
  }

  // Build each payment method option
  Widget _buildPaymentMethodOption(String method, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade200 : Colors.white,
        border: Border.all(
          color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300, 
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
          child: Icon(
            icon,
            color: isSelected ? Colors.blue.shade800 : Colors.grey,
            size: 20,
          ),
        ),
        title: Text(
          method,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue.shade800 : Colors.black87,
          ),
        ),
        dense: true,
        selected: isSelected,
        onTap: () {
          setState(() {
            _selectedPaymentMethod = method;
            _isCashSelected = (method == 'Cash');
            
            // If Bank payment is selected, show bank payment dialog
            if (method == 'Bank') {
              // Reset card selection dialog data
              _showBankPaymentDialog();
            }
          });
        },
      ),
    );
  }
  
  // Build individual number buttons
  Widget _buildNumberButton(String text) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: text == 'Add' ? Colors.blue.shade700 : Colors.blue.shade100,
            foregroundColor: text == 'Add' ? Colors.white : Colors.blue.shade800,
          ),
          onPressed: _selectedPaymentMethod != null ? () => _updateAmount(text) : null,
          child: Text(
            text,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  // Build the order info bar at the top
  Widget _buildOrderInfoBar() {
    final formatCurrency = NumberFormat.currency(symbol: '', decimalDigits: 3);
     // Get discount and discounted total
    final discount = _getCurrentDiscount();
    // final discountedTotal = _getDiscountedTotal();
  
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Customer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ 
                Text('Customer :', style: TextStyle(fontSize: 12, color: Colors.grey)),
                 Text(
                widget.customer?.name ?? 'NA',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              ],
            ),
          ),
          
          // Order type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order type :', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(widget.order.serviceType, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          // Tables
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tables :', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  widget.order.serviceType.contains('Table') 
                      ? widget.order.serviceType.split('Table ').last 
                      : '0',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
          
          // Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Status :', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(_orderStatus),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      _orderStatus.capitalize(),
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(_orderStatus),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Total amount
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total amount :', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Row(
                  children: [
                    Text(
                      formatCurrency.format(widget.order.total),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(width: 4),
                     // Show discount indicator if there is a discount
                  if (discount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-${formatCurrency.format(discount)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade800,
                        ),
                      ),
                    ),
                    // Text(
                    //   '(Tax: ${widget.taxRate}%)',
                    //   style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    // ),
                  ],
                ), 
              ],
            ),
          ),

        ],
      ),
    );
  }

  // Get color for status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Build number pad with the calculator style layout
  Widget _buildNumberPad() {
    return Column(
      children: [
        // Display current amount input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
            color: _selectedPaymentMethod == null ? Colors.grey.shade200 : Colors.white,
          ),
          alignment: Alignment.centerRight,
          child: Text(
            _amountInput,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _selectedPaymentMethod == null ? Colors.grey : Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Use Expanded to fill available space
        Expanded(
          child: AbsorbPointer(
            absorbing: _selectedPaymentMethod == null,
            child: Opacity(
              opacity: _selectedPaymentMethod == null ? 0.5 : 1.0,
              child: Column(
                children: [
                  // Number buttons
                  Expanded(
                    child: Row(
                      children: [
                        _buildNumberButton('7'),
                        _buildNumberButton('8'),
                        _buildNumberButton('9'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        _buildNumberButton('4'),
                        _buildNumberButton('5'),
                        _buildNumberButton('6'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        _buildNumberButton('1'),
                        _buildNumberButton('2'),
                        _buildNumberButton('3'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        _buildNumberButton('000'),
                        _buildNumberButton('0'),
                        _buildNumberButton('⌫'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        _buildNumberButton('C'),
                        _buildNumberButton('Add'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build payment summary
  Widget _buildPaymentSummary() {
    // Format for currency display
    final formatCurrency = NumberFormat.currency(symbol: '', decimalDigits: 3);
    // Get discount and discounted total
    final discount = _getCurrentDiscount();
    final discountedTotal = _getDiscountedTotal();
  
    return AbsorbPointer(
      absorbing: _selectedPaymentMethod == null,
      child: Opacity(
        opacity: _selectedPaymentMethod == null ? 0.5 : 1.0,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 45),
                
                // Coupon code section
                Container(
                  margin: const EdgeInsets.only(bottom: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Coupon code:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('', style: TextStyle(fontSize: 14)),
                            Icon(Icons.search, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Paid amount section
                Container(
                  margin: const EdgeInsets.only(bottom: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paid amount:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatCurrency.format(_paidAmount),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Balance amount section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Balance amount:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _balanceAmount > 0 ? Colors.blue : Colors.grey.shade300,
                            width: _balanceAmount > 0 ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          color: _balanceAmount > 0 ? Colors.grey.shade200 : Colors.white,
                        ),
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatCurrency.format(_balanceAmount),
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold,
                            color: _balanceAmount > 0 ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Bill amount box - only shown when Cash is selected
                if (_isCashSelected) ...[
                  const SizedBox(height: 32),
                  
                  // Full bill amount box centered
                  Center(
                    child: SizedBox(
                      width: (MediaQuery.of(context).size.width / 3) * 0.6,
                      height: discount > 0 ? 80 : 60,
                      child: GestureDetector(
                        onTap: _applyExactAmount,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(13),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Show either discounted total or original total
                            Text(
                              formatCurrency.format(discount > 0 ? discountedTotal : widget.order.total),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            
                            // Show discount amount if applied
                            if (discount > 0)
                              Text(
                                'Discount: ${formatCurrency.format(discount)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                          ],
                        ),
                          
                          // child: Text(
                          //   formatCurrency.format(widget.order.total),
                          //   style: TextStyle(
                          //     fontSize: 20,
                          //     fontWeight: FontWeight.bold,
                          //     color: Colors.blue.shade700,
                          //   ),
                          // ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Add space at the bottom to prevent overflow
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Show dialog to ask about saving PDF
  Future<bool?> _showSavePdfDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Printer Not Available'),
          content: const Text('No printer was found. Would you like to save the receipt as a PDF?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Save PDF'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }
  // Save PDF using Android's native Create Document Intent
  Future<bool> _saveWithAndroidIntent(pw.Document pdf) async {
    try {
      if (!Platform.isAndroid) {
        debugPrint('This method only works on Android');
        return false;
      }
      
      // First save PDF to a temporary file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final tempFilename = 'temp_receipt_${widget.order.orderNumber}_$timestamp.pdf';
      final tempFile = File('${tempDir.path}/$tempFilename');
      
      // Write PDF to temporary file
      await tempFile.writeAsBytes(await pdf.save());
      
      // Call the native method with file path
      final result = await _channel.invokeMethod('createDocument', {
        'path': tempFile.path,
        'mimeType': 'application/pdf',
        'fileName': 'SIMS_receipt_${widget.order.orderNumber}_$timestamp.pdf',
      });
      
      return result == true;
    } catch (e) {
      debugPrint('Error saving PDF with Android intent: $e');
      return false;
    }
  }

  // Generate the receipt using the PDF library
  Future<pw.Document> _generateReceipt() async {
     double subtotal = widget.order.total / (1 + (widget.taxRate / 100.0)); // Calculate subtotal from total
    double tax = widget.order.total - subtotal; // Calculate tax based on subtotal and tax rate
      // Get the current discount amount from service totals
    double discountAmount = 0.0;
    if (_serviceTotals.containsKey(_currentServiceType)) {
      discountAmount = _serviceTotals[_currentServiceType]!['discount'] ?? 0.0;
    }
    
    
    
    final pdf = await BillService.generateBill(
      items: widget.order.items.map((item) => item.toMenuItem()).toList(),
      serviceType: widget.order.serviceType,
      subtotal: subtotal,
      tax: tax,
      discount: discountAmount,
      total: widget.order.total - discountAmount,
      personName: null,
      tableInfo: widget.order.serviceType.contains('Table') ? widget.order.serviceType : null,
      isEdited: widget.isEdited,
      orderNumber: widget.order.orderNumber,
      taxRate: widget.taxRate,
    );
    
    return pdf;
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Add Cancel button in app bar
          if (_orderStatus.toLowerCase() == 'pending')
            TextButton.icon(
              icon: const Icon(Icons.cancel, color: Colors.white, size: 18),
              label: const Text('Cancel Order', style: TextStyle(color: Colors.white)),
              onPressed: _cancelOrder,
            ),
        ],
      ),
      body: _isProcessing 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing payment...')
              ],
            ),
          )
        : Column(
          children: [
            // Top info bar - order details
            _buildOrderInfoBar(),
            
            // Main content area
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left side - Payment methods
                  Expanded(
                    flex: 2,
                    child: _buildPaymentMethodSelection(),
                  ),
                  
                  // Middle - Number pad for amount (same for all payment methods)
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: _buildNumberPad(),
                    ),
                  ),
                  
                  // Right side - Payment summary
                  Expanded(
                    flex: 3,
                    child: _buildPaymentSummary(),
                  ),
                ],
              ),
            ),
          ],
        ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 2,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end, // Align buttons to the right
          children: [
            // Discount button - ADD THIS NEW BUTTON
            ElevatedButton(
              onPressed: _selectedPaymentMethod != null ? _showDiscountDialog : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade100,
                foregroundColor: Colors.purple.shade900,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 10),
                minimumSize: const Size(10, 36),
                textStyle: const TextStyle(fontSize: 12),
                disabledBackgroundColor: Colors.grey.shade200,
                disabledForegroundColor: Colors.grey.shade500,
              ),
              child: const Text('Discount'),
            ),
            
            const SizedBox(width: 8), // Spacing between buttons

            // Apply Coupon button
            // ElevatedButton(
            //   onPressed: _selectedPaymentMethod != null ? () {
            //     ScaffoldMessenger.of(context).showSnackBar(
            //       const SnackBar(content: Text('Coupon feature will be available soon')),
            //     );
            //   } : null,
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.amber.shade100,
            //     foregroundColor: Colors.amber.shade900,
            //     elevation: 1,
            //     padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 10),
            //     minimumSize: const Size(10, 36),
            //     textStyle: const TextStyle(fontSize: 12),
            //     disabledBackgroundColor: Colors.grey.shade200,
            //     disabledForegroundColor: Colors.grey.shade500,
            //   ),
            //   child: const Text('Apply Coupon'),
            // ),
            
            // const SizedBox(width: 8), // Spacing between buttons
            
            // View Bill button
            ElevatedButton(
              onPressed: (_balanceAmount == widget.order.total && _orderStatus.toLowerCase() != 'completed') 
                ? null // Disable if no payment has been made or no payment method selected
                : () {
                  _showBillPreviewDialog(); 
                },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade100,
                foregroundColor: Colors.green.shade900,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 10),
                minimumSize: const Size(10, 36),
                textStyle: const TextStyle(fontSize: 12),
                // Disable style when button is inactive
                disabledBackgroundColor: Colors.grey.shade200,
                disabledForegroundColor: Colors.grey.shade500,
              ),
              child: const Text('View Bill'), 
            ),
          ],
        ),
      ),
    );
  }
}
 