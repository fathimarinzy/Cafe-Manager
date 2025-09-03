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
import '../models/menu_item.dart';
import '../repositories/local_order_repository.dart';
import '../utils/app_localization.dart';
import '../utils/service_type_utils.dart';

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
  String? _selectedPaymentMethod;
  String _amountInput = '0.000';
  double _balanceAmount = 0.0;
  double _paidAmount = 0.0;
  bool _isProcessing = false;
  bool _isCashSelected = false;
  final Map<String, Map<String, double>> _serviceTotals = {};
  final String _currentServiceType = '';

  String _orderStatus = 'pending';
  final LocalOrderRepository _localOrderRepo = LocalOrderRepository();
  final MethodChannel _channel = const MethodChannel('com.simsrestocafe/file_picker');

  String _selectedCardType = 'VISA';
  final TextEditingController _lastFourDigitsController = TextEditingController();
  final TextEditingController _approvalCodeController = TextEditingController();
  final TextEditingController _receivedAmountController = TextEditingController();
  
  final FocusNode _lastFourFocusNode = FocusNode();
  final FocusNode _approvalFocusNode = FocusNode();
  final FocusNode _receivedFocusNode = FocusNode();
  
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
    
    _orderStatus = widget.order.status;
    
    if (widget.preselectedPaymentMethod != null) {
      _selectedPaymentMethod = widget.preselectedPaymentMethod;
      _isCashSelected = _selectedPaymentMethod == 'Cash';
    }
     
    if (!_serviceTotals.containsKey(_currentServiceType)) {
      _serviceTotals[_currentServiceType] = {
        'subtotal': 0.0,
        'tax': 0.0,
        'discount': 0.0,
        'total': widget.order.total,
      };
    }
    
    if (_orderStatus.toLowerCase() == 'completed') {
      _balanceAmount = 0.0;
      _paidAmount = widget.order.total;
    } else {
      _balanceAmount = widget.order.total;
      _paidAmount = 0.0;
    }
 
    debugPrint('Initial balance: $_balanceAmount, Initial paid: $_paidAmount, Status: $_orderStatus');
    if (widget.showBankDialogOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBankPaymentDialog();
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

  double _getDiscountedTotal() {
    double discount = 0.0;
    if (_serviceTotals.containsKey(_currentServiceType)) {
      discount = _serviceTotals[_currentServiceType]!['discount'] ?? 0.0;
    }
    
    return widget.order.total - discount;
  }

  double _getCurrentDiscount() {
    if (_serviceTotals.containsKey(_currentServiceType)) {
      return _serviceTotals[_currentServiceType]!['discount'] ?? 0.0;
    }
    return 0.0;
  }

  void _applyDiscount(double discountAmount) {
    if (discountAmount <= 0) return;
    
    final effectiveDiscount = discountAmount > widget.order.total ? widget.order.total : discountAmount;
    
    setState(() {
      _balanceAmount = widget.order.total - effectiveDiscount;
      if (_balanceAmount < 0) _balanceAmount = 0.0;
      
      if (_serviceTotals.containsKey(_currentServiceType)) {
        final totals = _serviceTotals[_currentServiceType]!;
        
        totals['discount'] = effectiveDiscount;
        totals['total'] = totals['subtotal']! + totals['tax']! - totals['discount']!;
        
        _serviceTotals[_currentServiceType] = totals;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'Discount of'.tr()} ${effectiveDiscount.toStringAsFixed(3)} ${'applied successfully'.tr()}'),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }


Future<void> _reprintMainReceipt() async {
  setState(() {
    _isProcessing = true;
  });
  
  try {
    // Convert order items to MenuItem objects
    final items = widget.order.items.map((item) => 
      MenuItem(
        id: item.id.toString(),
        name: item.name,
        price: item.price,
        quantity: item.quantity,
        imageUrl: '',
        category: '',
        kitchenNote: item.kitchenNote,
      )
    ).toList();
    
    // Calculate totals
    final subtotal = _calculateSubtotal(widget.order.items);
    final tax = subtotal * (widget.taxRate / 100.0);
    final discountAmount = _getCurrentDiscount();
    final total = subtotal + tax - discountAmount;
    
    // Extract tableInfo if this is a dining order
    String? tableInfo;
    if (widget.order.serviceType.startsWith('Dining - Table')) {
      tableInfo = widget.order.serviceType;
    }
    
    // Generate PDF with original order number
    final pdf = await BillService.generateBill(
      items: items,
      serviceType: widget.order.serviceType,
      subtotal: subtotal,
      tax: tax,
      discount: discountAmount,
      total: total,
      personName: widget.customer?.name,
      tableInfo: tableInfo,
      isEdited: widget.isEdited,
      orderNumber: widget.order.orderNumber, // Use original order number
      taxRate: widget.taxRate,
    );

    // Try to print directly first
    bool printed = false;
    try {
      printed = await BillService.printBill(
        items: items,
        serviceType: widget.order.serviceType,
        subtotal: subtotal,
        tax: tax,
        discount: discountAmount,
        total: total,
        personName: widget.customer?.name,
        tableInfo: tableInfo,
        isEdited: widget.isEdited,
        orderNumber: widget.order.orderNumber, // Use original order number
        taxRate: widget.taxRate,
      );
    } catch (e) {
      debugPrint('Direct printing failed: $e');
    }

    Map<String, dynamic> result;
    if (printed) {
      result = {
        'success': true,
        'message': 'Receipt reprinted successfully',
        'printed': true,
        'saved': false,
      };
    } else {
      if (!mounted) return;
      // If printing fails, offer to save as PDF
      bool? saveAsPdf = await BillService.showSavePdfDialog(context);
      if (saveAsPdf == true) {
        final saved = await _saveWithCustomFileName(pdf, widget.order.orderNumber);
        result = {
          'success': saved,
          'message': saved ? 'Receipt saved as PDF' : 'Failed to save PDF',
          'printed': false,
          'saved': saved,
        };
      } else {
        result = {
          'success': false,
          'message': 'Printing failed and PDF save was cancelled',
          'printed': false,
          'saved': false,
        };
      }
    }
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      
      // Show result message
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt reprinted successfully'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to reprint  receipt'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('Error reprinting main receipt: $e');
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reprinting receipt: ${e.toString()}'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Helper method to calculate subtotal (if not already present)
double _calculateSubtotal(List<dynamic> items) {
  return items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
}

// Custom save method with original order number filename
Future<bool> _saveWithCustomFileName(pw.Document pdf, String orderNumber) async {
  try {
    if (!Platform.isAndroid) {
      debugPrint('This method only works on Android');
      return false;
    }
    
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final tempFilename = 'temp_receipt_${orderNumber}_$timestamp.pdf';
    final tempFile = File('${tempDir.path}/$tempFilename');
    
    await tempFile.writeAsBytes(await pdf.save());
    
    final result = await _channel.invokeMethod('createDocument', {
      'path': tempFile.path,
      'mimeType': 'application/pdf',
      'fileName': 'SIMS_receipt_${orderNumber}_reprint.pdf', // Use original order number
    });
    
    return result == true;
  } catch (e) {
    debugPrint('Error saving PDF with custom filename: $e');
    return false;
  }
}

  Future<void> _showBillPreviewDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      final pdf = await _generateReceipt();
      
      final tempDir = await getTemporaryDirectory();
      final pdfPath = '${tempDir.path}/bill_preview_${widget.order.id}.pdf';
      final file = File(pdfPath);
      await file.writeAsBytes(await pdf.save());
      
      if (!mounted) return;
      Navigator.of(context).pop();
      
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                color: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      'Preview'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                      // Add Reprint button next to Preview text
                    ElevatedButton.icon(
                      icon: const Icon(Icons.print, size: 16),
                      label: Text('Reprint'.tr()),
                      onPressed: () async {
                        await _reprintMainReceipt(); // Call reprint method
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade900,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                        minimumSize: const Size(80, 32),
                      ),
                    ),
                  ],
                ),
              ),
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
                        SnackBar(content: Text('Error loading PDF preview'.tr())),
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
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'Error generating bill preview'.tr()}: $e')),
        );
      }
    }
  }

  Future<bool> _updateOrderStatus(String status) async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final orders = await _localOrderRepo.getAllOrders();
      final orderIndex = orders.indexWhere((o) => o.id == widget.order.id);
      
      if (orderIndex >= 0) {
        final order = orders[orderIndex];
        
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
        
        await _localOrderRepo.saveOrder(updatedOrder);
        
        if (mounted) {
          setState(() {
            _orderStatus = status;
          });
        }
        
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

  Future<void> _processPayment(double amount) async {
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a payment method'.tr())),
      );
      return;
    }
    
    if (amount <= 0) return;

    setState(() {
      _isProcessing = true;
    });

    final discountedTotal = _getDiscountedTotal();
    
    double change = 0.0;
    if (amount > discountedTotal) {
      change = amount - discountedTotal;
    }

    try {
      final paymentMethod = _selectedPaymentMethod!.toLowerCase();
      Order? savedOrder;
      
      double discountAmount = 0.0;
      if (_serviceTotals.containsKey(_currentServiceType)) {
        discountAmount = _serviceTotals[_currentServiceType]!['discount'] ?? 0.0;
      }
      
      if (widget.order.id != 0) {
        final orders = await _localOrderRepo.getAllOrders();
        final orderIndex = orders.indexWhere((o) => o.id == widget.order.id);
        
        if (orderIndex >= 0) {
          final existingOrder = orders[orderIndex];
          
          savedOrder = Order(
            id: existingOrder.id,
            serviceType: existingOrder.serviceType,
            items: existingOrder.items,
            subtotal: widget.order.total - (widget.order.total * (widget.taxRate / 100)),
            tax: widget.order.total * (widget.taxRate / 100),
            discount: discountAmount,
            total: widget.order.total- discountAmount,
            status: 'completed',
            createdAt: existingOrder.createdAt,
            customerId: widget.customer?.id ?? existingOrder.customerId,
            paymentMethod: paymentMethod
          );
          
          savedOrder = await _localOrderRepo.saveOrder(savedOrder);
        }
      } else {
        debugPrint('Creating new order in TenderScreen - unusual case');
        
        final orderItems = widget.order.items.map((item) => 
          OrderItem(
            id: item.id,
            name: item.name,
            price: item.price,
            quantity: item.quantity,
            kitchenNote: item.kitchenNote,
          )
        ).toList();
        
        savedOrder = Order(
          serviceType: widget.order.serviceType,
          items: orderItems,
          subtotal: widget.order.total - (widget.order.total * (widget.taxRate / 100)),
          tax: widget.order.total * (widget.taxRate / 100),
          discount: discountAmount,
          total: widget.order.total - discountAmount,
          status: 'completed',
          createdAt: DateTime.now().toIso8601String(),
          customerId: widget.customer?.id,
          paymentMethod: paymentMethod,
        );
        
        savedOrder = await _localOrderRepo.saveOrder(savedOrder);
      }
      
      if (savedOrder == null) {
        throw Exception('Failed to process order in the system');
      }
      
      if (widget.order.id == 0) {
        widget.order.id = savedOrder.id ?? 0;
      }
      
      final statusUpdated = await _updateOrderStatus('completed');
      
      if (!statusUpdated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update order status, but continuing with payment processing'.tr())),
          );
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      final savedPrinterName = prefs.getString('selected_printer');
      debugPrint('Selected printer: $savedPrinterName');
      
      final pdf = await _generateReceipt();

      bool printed = false;
      try {
        printed = await BillService.printThermalBill(widget.order, isEdited: widget.isEdited, taxRate: widget.taxRate, discount: discountAmount);
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
      
      if (widget.order.serviceType.contains('Dining - Table')) {
        final tableNumberStr = widget.order.serviceType.split('Table ').last;
        final tableNumber = int.tryParse(tableNumberStr);
        
        if (tableNumber != null && mounted) {
          final tableProvider = Provider.of<TableProvider>(context, listen: false);
          
          await tableProvider.setTableStatus(tableNumber, false);
          debugPrint('Table $tableNumber status set to available after payment');
        }
      }
      
      if (mounted) {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        orderProvider.clearSelectedPerson(); 
        orderProvider.clearCart();
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
          SnackBar(content: Text('${'Error processing payment'.tr()}: $e')),
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

  void _showDiscountDialog() {
    final currentTotal = widget.order.total;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        String discountInput = '0.000';
        double discountAmount = 0.0;
        
        final screenSize = MediaQuery.of(context).size;
        
        return StatefulBuilder(
          builder: (context, setState) {
            discountAmount = double.tryParse(discountInput) ?? 0.0;
            
            return Material(
              type: MaterialType.transparency,
              child: Center(
                child: Container(
                  width: screenSize.width * 0.7,
                  height: screenSize.height * 0.9,
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
                              'Apply Discount'.tr(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                      Row(
                                        children: [
                                          Text('${'Current Total'.tr()}: ', style: const TextStyle(fontSize: 16)),
                                          Text(
                                            currentTotal.toStringAsFixed(3),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      Container(
                                        height: 24,
                                        width: 1,
                                        color: Colors.grey.shade300,
                                      ),
                                      
                                      Row(
                                        children: [
                                          Text('${'New Total'.tr()}: ', style: const TextStyle(fontSize: 16)),
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
                                const SizedBox(height: 12),
                                
                                Container(
                                  width: double.infinity,
                                  alignment: Alignment.center,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
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
                                      ],
                                    ),
                                  ),
                                ),
                                                            
                                const SizedBox(height: 20),
                                
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${'Discount Amount'.tr()}: ',
                                      style: const TextStyle(
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
                                
                                SizedBox(
                                  height: 250,
                                  child: Column(
                                    children: [
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
                              child: Text('Cancel'.tr()),
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
                              child: Text('Apply'.tr()),
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

  Future<void> _cancelOrder() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Order?'.tr()),
        content: Text('Are you sure you want to cancel this order?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Yes'.tr(), style: const TextStyle(color: Colors.red)),
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
              SnackBar(content: Text('Order cancelled successfully'.tr())),
            );
            
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
              (route) => false,
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to cancel order. Please try again.'.tr())),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${'Error cancelling order'.tr()}: $e')),
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
  
  void _showBankPaymentDialog() {
    _lastFourDigitsController.clear();
    _approvalCodeController.clear();
    
    final discountedTotal = _getDiscountedTotal();
    _receivedAmountController.text = discountedTotal.toStringAsFixed(3);
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
                    Row(
                      children: [
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
                        Text(
                          'Terminal credit card'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        Expanded(child: Container()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Balance amount'.tr(),
                                        style: const TextStyle(fontSize: 16),
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
                                
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Received'.tr(),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 6,
                                      child: TextField(
                                        controller: _receivedAmountController,
                                        focusNode: _receivedFocusNode,
                                        readOnly: true,
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
                                
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Last 4 digit'.tr(),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 6,
                                      child: TextField(
                                        controller: _lastFourDigitsController,
                                        focusNode: _lastFourFocusNode,
                                        readOnly: true,
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
                                
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Approval code'.tr(),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 6,
                                      child: TextField(
                                        controller: _approvalCodeController,
                                        focusNode: _approvalFocusNode,
                                        readOnly: true,
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
                          
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.only(left: 16),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(child: _buildNumberPadDialogButton('7', setState)),
                                        Expanded(child: _buildNumberPadDialogButton('8', setState)),
                                        Expanded(child: _buildNumberPadDialogButton('9', setState)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(child: _buildNumberPadDialogButton('4', setState)),
                                        Expanded(child: _buildNumberPadDialogButton('5', setState)),
                                        Expanded(child: _buildNumberPadDialogButton('6', setState)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(child: _buildNumberPadDialogButton('1', setState)),
                                        Expanded(child: _buildNumberPadDialogButton('2', setState)),
                                        Expanded(child: _buildNumberPadDialogButton('3', setState)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  
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
                                  const SizedBox(height: 8),
                                  
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
                                                  SnackBar(content: Text('Please enter a valid amount'.tr())),
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
                                            child: Text(
                                              'OK'.tr(),
                                              style: const TextStyle(
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

  Widget _buildNumberPadDialogButton(String text, StateSetter setState, {bool isBackspace = false}) {
    return Container(
      margin: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: () {
          TextEditingController controller;
          if (_lastFourFocusNode.hasFocus) {
            controller = _lastFourDigitsController;
          } else if (_approvalFocusNode.hasFocus) {
            controller = _approvalCodeController;
          } else if (_receivedFocusNode.hasFocus) {
            controller = _receivedAmountController;
          } else {
            controller = _receivedAmountController;
            FocusScope.of(context).requestFocus(_receivedFocusNode);
          }
          
          if (text == 'C') {
            setState(() {
              controller.clear();
            });
          } else if (text == '⌫') {
            if (controller.text.isNotEmpty) {
              setState(() {
                controller.text = controller.text
                  .substring(0, controller.text.length - 1);
              });
            }
          } else {
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
          padding: const EdgeInsets.symmetric(vertical: 20),
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

  void _applyExactAmount() {
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a payment method'.tr())),
      );
      return;
    }

    if (_balanceAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No remaining balance to pay'.tr())),
      );
      return;
    }

    double amount = _getDiscountedTotal();
    
    if (!mounted) return;
    
    _showPaymentConfirmationDialog(amount);
  }

  Future<void> _showPaymentConfirmationDialog(double amount) async {
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a payment method'.tr())),
      );
      return;
    }

    if (_balanceAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No remaining balance to pay'.tr())),
      );
      return;
    }
    
    double change = 0.0;
    if (_selectedPaymentMethod == 'Bank') {
      if (amount > widget.order.total) {
        change = amount - widget.order.total;
      }
    } else {
      if (amount > _balanceAmount) {
        change = amount - _balanceAmount;
      }
    }
    
    if (!mounted) return;
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirm'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Do you want to print?'.tr()),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'.tr()),
              onPressed: () {
                Navigator.of(dialogContext).pop('cancel');
              },
            ),
            TextButton(
              child: Text('No'.tr()),
              onPressed: () {
                Navigator.of(dialogContext).pop('no');
              },
            ),
            TextButton(
              child: Text('Yes'.tr()),
              onPressed: () {
                Navigator.of(dialogContext).pop('yes');
              },
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (result == 'cancel') {
      return;
    }

    if (result == 'yes' || result == 'no') {
      setState(() {
        if (_selectedPaymentMethod == 'Cash') {
          double amountToDeduct = _balanceAmount < amount ? _balanceAmount : amount;
          
          _balanceAmount -= amountToDeduct;
          if (_balanceAmount < 0) _balanceAmount = 0;
          
          _paidAmount += amountToDeduct;
        } else {
          _paidAmount = widget.order.total;
          _balanceAmount = 0;
        }
        
        debugPrint('Payment processed. Amount: $amount, Change: $change');
        debugPrint('New balance: $_balanceAmount, Total paid: $_paidAmount');
      });
      
      if (change > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${'Payment of'.tr()} ${NumberFormat.currency(symbol: '', decimalDigits: 3).format(amount)} ${'accepted. Return change'.tr()}: ${NumberFormat.currency(symbol: '', decimalDigits: 3).format(change)}'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${'Payment of'.tr()} ${NumberFormat.currency(symbol: '', decimalDigits: 3).format(amount)} ${'accepted'.tr()}.'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
      
      if (result == 'yes') {
        if (_selectedPaymentMethod == 'Cash') {
          _processCashPayment(amount, change);
        } else {
          _processPayment(amount);
        }
      } else if (result == 'no' && _balanceAmount <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment complete!'.tr()),
              duration: const Duration(seconds: 1),
            ),
          );
        }

        await _updateOrderStatus('completed');
          
        // Clear cart and customer selection
        if (mounted) {
          final orderProvider = Provider.of<OrderProvider>(context, listen: false);
          orderProvider.clearSelectedPerson(); 
          orderProvider.clearCart();
        }
        
        // Update table status 
        if (widget.order.serviceType.contains('Dining - Table')) {
          final tableNumberStr = widget.order.serviceType.split('Table ').last;
          final tableNumber = int.tryParse(tableNumberStr);
          
          if (tableNumber != null && mounted) {
            final tableProvider = Provider.of<TableProvider>(context, listen: false);
            await tableProvider.setTableStatus(tableNumber, false);
            debugPrint('Table $tableNumber status set to available after no-print payment');
          }
        }
        
        // Refresh order history
        if (mounted) {
          Provider.of<OrderHistoryProvider>(context, listen: false).refreshOrdersAndConnectivity();
        }

        if (change > 0) {
          _showBalanceMessageDialog(change);
        } else {
          _showBalanceMessageDialog();
        }
      }
    }
  }

  Future<void> _processCashPayment(double amount, double change) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      Order? savedOrder;
        
      double discountAmount = 0.0;
      if (_serviceTotals.containsKey(_currentServiceType)) {
        discountAmount = _serviceTotals[_currentServiceType]!['discount'] ?? 0.0;
      }
   
      if (widget.order.id != 0) {
        final orders = await _localOrderRepo.getAllOrders();
        final orderIndex = orders.indexWhere((o) => o.id == widget.order.id);
        
        if (orderIndex >= 0) {
          final existingOrder = orders[orderIndex];
          
          savedOrder = Order(
            id: existingOrder.id,
            serviceType: existingOrder.serviceType,
            items: existingOrder.items,
            subtotal: widget.order.total - (widget.order.total * (widget.taxRate / 100)),
            tax: widget.order.total * (widget.taxRate / 100),
            discount: discountAmount,
            total: widget.order.total - discountAmount,
            status: 'completed',
            createdAt: existingOrder.createdAt,
            customerId: widget.customer?.id ?? existingOrder.customerId,
            paymentMethod: 'cash'
          );
          
          savedOrder = await _localOrderRepo.saveOrder(savedOrder);
          debugPrint('Updated order with cash payment method: ${savedOrder.id}');
        } else {
          throw Exception('Order not found in local database');
        }
      } else {
        debugPrint('Creating new order with cash payment');
        
        final orderItems = widget.order.items.map((item) => 
          OrderItem(
            id: item.id,
            name: item.name,
            price: item.price,
            quantity: item.quantity,
            kitchenNote: item.kitchenNote,
          )
        ).toList();
        
        savedOrder = Order(
          serviceType: widget.order.serviceType,
          items: orderItems,
          subtotal: widget.order.total - (widget.order.total * (widget.taxRate / 100)),
          tax: widget.order.total * (widget.taxRate / 100),
          discount: discountAmount,
          total: widget.order.total - discountAmount,
          status: 'completed',
          createdAt: DateTime.now().toIso8601String(),
          customerId: widget.customer?.id,
          paymentMethod: 'cash',
        );
        
        savedOrder = await _localOrderRepo.saveOrder(savedOrder);
        debugPrint('Created new order with cash payment: ${savedOrder.id}');
      }
      
      if (widget.order.id == 0) {
        widget.order.id = savedOrder.id ?? 0;
      }
      
      final statusUpdated = await _updateOrderStatus('completed');
       
      if (!statusUpdated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update order status, but continuing with payment processing'.tr())),
          );
        }
      }
      
      final pdf = await _generateReceipt();
      
      bool printed = false;
      try {
        printed = await BillService.printThermalBill(widget.order, isEdited: widget.isEdited, taxRate: widget.taxRate, discount: discountAmount);
      } catch (e) {
        debugPrint('Printing error: $e');
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
      
      if (widget.order.serviceType.contains('Dining - Table')) {
        final tableNumberStr = widget.order.serviceType.split('Table ').last;
        final tableNumber = int.tryParse(tableNumberStr);
        
        if (tableNumber != null && mounted) {
          final tableProvider = Provider.of<TableProvider>(context, listen: false);
          
          await tableProvider.setTableStatus(tableNumber, false);
          debugPrint('Table $tableNumber status set to available after cash payment');
        }
      }
      
      if (mounted) {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        orderProvider.clearSelectedPerson(); 
        orderProvider.clearCart();
      }
      
      if (mounted) {
        Provider.of<OrderHistoryProvider>(context, listen: false).refreshOrdersAndConnectivity();
      }
      
      if (mounted) {
        await _showBalanceMessageDialog(change);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'Error processing payment'.tr()}: $e')),
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
                      ? '${'Balance amount is'.tr()} ${NumberFormat.currency(symbol: '', decimalDigits: 3).format(change)}'
                      : '${'Balance amount is'.tr()} 0.000',
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
                    child: Text('OK'.tr()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _updateAmount(String value) {
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a payment method first'.tr())),
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
      String cleanInput = _amountInput.replaceAll(',', '.');
      double amount = double.tryParse(cleanInput) ?? 0.0;
      
      debugPrint('Add button pressed. Amount input: $_amountInput, Parsed amount: $amount');
      
      if (amount > 0) {
        if (_selectedPaymentMethod == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select a payment method'.tr())),
          );
          return;
        }
        
        if (_selectedPaymentMethod == 'Cash') {
          double amountToDeduct = amount > _balanceAmount ? _balanceAmount : amount;
          double change = amount > _balanceAmount ? amount - _balanceAmount : 0.0;
          
          setState(() {
            _balanceAmount -= amountToDeduct;
            if (_balanceAmount < 0) _balanceAmount = 0;
            
            _paidAmount += amountToDeduct;
            
            _amountInput = '0.000';
          });
          
          if (_balanceAmount <= 0) {
            _processCashPayment(amount, change);
          }
        } else {
          setState(() {
            debugPrint('Before calculation - Current balance: $_balanceAmount, Amount to add: $amount');
            
            double amountToDeduct = amount > _balanceAmount ? _balanceAmount : amount;
            double newBalance = _balanceAmount - amountToDeduct;
            
            debugPrint('After calculation - New balance: $newBalance');
            
            _balanceAmount = newBalance;
            _paidAmount += amountToDeduct;
            
            debugPrint('Paid amount: $_paidAmount, Final balance: $_balanceAmount');
            
            _amountInput = '0.000';
            
            if (_balanceAmount <= 0) {
              _updateOrderStatus('completed');
            }
          });
        }
      }
      return;
    }

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

    setState(() {
      if (_amountInput == '0.000') {
        _amountInput = value;
      } else {
        _amountInput += value;
      }
    });
  }

  Widget _buildPaymentMethodSelection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      margin: const EdgeInsets.only(top: 55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPaymentMethodOption('Bank'.tr(), Icons.account_balance),
          _buildPaymentMethodOption('Cash'.tr(), Icons.money),
          _buildPaymentMethodOption('Customer Credit'.tr(), Icons.person),
          _buildPaymentMethodOption('Credit Sale'.tr(), Icons.credit_card),
        ],
      ),
    );
  }

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
            _isCashSelected = (method == 'Cash'.tr());
            
            if (method == 'Bank'.tr()) {
              _showBankPaymentDialog();
            }
          });
        },
      ),
    );
  }
  
  Widget _buildNumberButton(String text) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            backgroundColor: text == 'Add'.tr() ? Colors.blue.shade700 : Colors.blue.shade100,
            foregroundColor: text == 'Add'.tr() ? Colors.white : Colors.blue.shade800,
          ),
          onPressed: _selectedPaymentMethod != null ? () => _updateAmount(text) : null,
          child: Text(
            text == 'Add' ? 'Add'.tr() : text,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInfoBar() {
    final formatCurrency = NumberFormat.currency(symbol: '', decimalDigits: 3);
    final discount = _getCurrentDiscount();
    
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ 
                Text('${'Customer'.tr()}:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                 Text(
                widget.customer?.name ?? 'NA',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              ],
            ),
          ),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${'Order type'.tr()}:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(_getTranslatedServiceType(widget.order.serviceType), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${'Tables'.tr()}:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  widget.order.serviceType.contains('Table') 
                      ? widget.order.serviceType.split('Table ').last 
                      : '0',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${'Status'.tr()}:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                      _getTranslatedStatus(_orderStatus),
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
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${'Total amount'.tr()}:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Row(
                  children: [
                    Text(
                      formatCurrency.format(widget.order.total),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(width: 4),
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
                  ],
                ), 
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTranslatedStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending'.tr();
      case 'completed':
        return 'Completed'.tr();
      case 'cancelled':
        return 'Cancelled'.tr();
      default:
        return status;
    }
  }

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

  Widget _buildNumberPad() {
    return Column(
      children: [
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
        
        Expanded(
          child: AbsorbPointer(
            absorbing: _selectedPaymentMethod == null,
            child: Opacity(
              opacity: _selectedPaymentMethod == null ? 0.5 : 1.0,
              child: Column(
                children: [
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

  Widget _buildPaymentSummary() {
    final formatCurrency = NumberFormat.currency(symbol: '', decimalDigits: 3);
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
                
                Container(
                  margin: const EdgeInsets.only(bottom: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'Coupon code'.tr()}:',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('', style: TextStyle(fontSize: 14)),
                            Icon(Icons.search, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                Container(
                  margin: const EdgeInsets.only(bottom: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'Paid amount'.tr()}:',
                        style: const TextStyle(fontSize: 14),
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
                
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'Balance amount'.tr()}:',
                      style: const TextStyle(fontSize: 14),
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
                
                if (_isCashSelected) ...[
                  const SizedBox(height: 32),
                  
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
                            Text(
                              formatCurrency.format(discount > 0 ? discountedTotal : widget.order.total),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            
                            if (discount > 0)
                              Text(
                                '${'Discount'.tr()}: ${formatCurrency.format(discount)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                          ],
                        ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Future<bool?> _showSavePdfDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Printer Not Available'.tr()),
          content: Text('No printer was found. Would you like to save the receipt as a PDF?'.tr()),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'.tr()),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text('Save PDF'.tr()),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _saveWithAndroidIntent(pw.Document pdf) async {
    try {
      if (!Platform.isAndroid) {
        debugPrint('This method only works on Android');
        return false;
      }
      
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final tempFilename = 'temp_receipt_${widget.order.orderNumber}_$timestamp.pdf';
      final tempFile = File('${tempDir.path}/$tempFilename');
      
      await tempFile.writeAsBytes(await pdf.save());
      
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

  Future<pw.Document> _generateReceipt() async {
     double subtotal = widget.order.total / (1 + (widget.taxRate / 100.0));
    double tax = widget.order.total - subtotal;
    
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
        title: Text('Receipt'.tr()),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_orderStatus.toLowerCase() == 'pending')
            TextButton.icon(
              icon: const Icon(Icons.cancel, color: Colors.white, size: 18),
              label: Text('Cancel Order'.tr(), style: const TextStyle(color: Colors.white)),
              onPressed: _cancelOrder,
            ),
        ],
      ),
      body: _isProcessing 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Processing payment...'.tr())
              ],
            ),
          )
        : Column(
          children: [
            _buildOrderInfoBar(),
            
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildPaymentMethodSelection(),
                  ),
                  
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: _buildNumberPad(),
                    ),
                  ),
                  
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
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
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
              child: Text('Discount'.tr()),
            ),
            
            const SizedBox(width: 8),
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
            
            
            ElevatedButton(
              onPressed: (_balanceAmount == widget.order.total && _orderStatus.toLowerCase() != 'completed') 
                ? null
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
                disabledBackgroundColor: Colors.grey.shade200,
                disabledForegroundColor: Colors.grey.shade500,
              ),
              child: Text('View Bill'.tr()), 
            ),
          ],
        ),
      ),
    );
  }

  String _getTranslatedServiceType(String serviceType) {
  return ServiceTypeUtils.getTranslated(serviceType);
}
}