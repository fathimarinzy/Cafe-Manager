import 'package:cafeapp/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order_history.dart';
import '../services/bill_service.dart';
import '../utils/extensions.dart';
import '../providers/order_history_provider.dart';
import '../screens/order_list_screen.dart';
import 'dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter/services.dart';
import '../providers/table_provider.dart';
// import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../providers/order_provider.dart';
import '../models/person.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/menu_item.dart';
import '../repositories/local_order_repository.dart';
import '../utils/app_localization.dart';
import '../utils/service_type_utils.dart';
import '../providers/person_provider.dart';
import '../screens/search_person_screen.dart';
import '../repositories/credit_transaction_repository.dart';
import '../models/credit_transaction.dart';
import '../services/cross_platform_pdf_service.dart';
import '../services/device_sync_service.dart';


class TenderScreen extends StatefulWidget {
  final OrderHistory order;
  final bool isEdited;
  final double taxRate;
  final String? preselectedPaymentMethod; 
  final bool showBankDialogOnLoad; 
  final Person? customer;
  final bool isCreditCompletion; 
  final String? creditTransactionId; 

  const TenderScreen({
    super.key, 
    required this.order,
    this.isEdited = false, 
    this.taxRate = 5.0,
    this.preselectedPaymentMethod,
    this.showBankDialogOnLoad = false,
    this.customer,
    this.isCreditCompletion = false,
    this.creditTransactionId,
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
  Person? _currentCustomer;

  bool _shouldReopenBankDialog = false; // Add this flag
  bool _shouldReopenSplitDialog = false;

  // NEW: Split payment state variables
  double _cashAmount = 0.0;
  double _bankAmount = 0.0;
  bool _isDepositMode = false; // New: Toggle for deposit payment

  final Map<String, Map<String, double>> _serviceTotals = {};
  final String _currentServiceType = '';
  Order? _updatedOrder; // To track changes to the order (e.g. deposit, ID assignment)

  String _orderStatus = 'pending';
  final LocalOrderRepository _localOrderRepo = LocalOrderRepository();
  // final MethodChannel _channel = const MethodChannel('com.simsrestocafe/file_picker');

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
    // Initialize current customer from widget
    _currentCustomer = widget.customer;
    
    _orderStatus = widget.order.status;
    
    if (widget.preselectedPaymentMethod != null) {
      // FIX: Translate the incoming English method to match UI expectations
      // This ensures 'Cash' becomes 'نقد' in Arabic so string comparisons pass
      _selectedPaymentMethod = widget.preselectedPaymentMethod!.tr();
      _isCashSelected = _selectedPaymentMethod == 'Cash'.tr();
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
      // Use logic that includes delivery charge fix
      final totalAmount = _getDiscountedTotal();
      
      // Use depositAmount for advances if it exists
      final deposit = widget.order.depositAmount ?? 0.0;
      _paidAmount = deposit;
      _balanceAmount = totalAmount - deposit;
      if (_balanceAmount < 0) _balanceAmount = 0.0;
    }
 
    debugPrint('Initial balance: $_balanceAmount, Initial paid: $_paidAmount, Status: $_orderStatus');
    debugPrint('TenderScreen: Received Order logic. Charge=${widget.order.deliveryCharge}, Total=${widget.order.total}');
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
    
    // ✅ FIX: Ensure delivery charge is included
    // If the total seems to be ignoring the delivery charge (e.g. Total approx Subtotal + Tax), add it.
    double total = widget.order.total;
    final deliveryCharge = widget.order.deliveryCharge ?? 0.0;
    
    // Debug the values for troubleshooting
    // debugPrint('TenderScreen Calc: Total=$total, Subtotal=${widget.order.subtotal}, Tax=${widget.order.tax}, Charge=$deliveryCharge');
    
    if (deliveryCharge > 0) {
      // Logic: If total < subtotal + tax + deliveryCharge - 0.1 (tolerance), then add deliveryCharge
      // If subtotal is 0 (data issue), use total as estimated base
      
      double estimatedTotalWithoutDelivery;
      if (widget.order.subtotal > 0) {
         estimatedTotalWithoutDelivery = widget.order.subtotal + widget.order.tax - widget.order.discount;
      } else {
         // Fallback: assume current total IS the item total (missing delivery)
         estimatedTotalWithoutDelivery = total;
      }
      
      final diff = (total - estimatedTotalWithoutDelivery).abs();
      debugPrint('TenderScreen Calc Detailed: Total=$total, Estimated=$estimatedTotalWithoutDelivery, Diff=$diff, Charge=$deliveryCharge');

      // If total is close to estimatedTotalWithoutDelivery, but we have a delivery charge, 
      // then delivery charge is missing.
      if (diff < 1.0) {
         total += deliveryCharge;
         debugPrint('TenderScreen: Detected missing delivery charge in total. Added $deliveryCharge. New Total: $total');
      } else {
         debugPrint('TenderScreen: Delivery charge deemed included. Total ($total) != Estimated ($estimatedTotalWithoutDelivery)');
      }
    } else {
       debugPrint('TenderScreen: No delivery charge ($deliveryCharge). Returning Total: $total');
    }

    return total - discount;
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
      _balanceAmount = widget.order.total - (widget.order.depositAmount ?? 0.0) - effectiveDiscount;
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
     // Force update the received amount controller
    final discountedTotal = _getDiscountedTotal();
    _receivedAmountController.text = discountedTotal.toStringAsFixed(3);
  // Reopen bank dialog if we came from there
    if (_shouldReopenBankDialog) {
      _shouldReopenBankDialog = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showBankPaymentDialog();
        }
      });
    }

    // Reopen split dialog if we came from there
    if (_shouldReopenSplitDialog) {
      _shouldReopenSplitDialog = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSplitPaymentDialog();
        }
      });
    }

  }
   // Add this method to calculate subtotal and tax based on VAT type
 Map<String, double> _calculateAmounts() {
  final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
  final discountAmount = _getCurrentDiscount();
  
  double taxableTotal = 0.0;
  double taxExemptTotal = 0.0;
  
  for (var item in widget.order.items) {
    final itemTotal = item.price * item.quantity;
    // Check if the menu item is tax exempt
    // You'll need to pass this information through the order
    if (item.taxExempt) {
      taxExemptTotal += itemTotal;
    } else {
      taxableTotal += itemTotal;
    }
  }
  
  double subtotal;
  double tax;
  double total;
  
  if (settingsProvider.isVatInclusive) {
    final taxableAmount = taxableTotal / (1 + (settingsProvider.taxRate / 100));
    tax = taxableTotal - taxableAmount;
    subtotal = taxableAmount + taxExemptTotal ;
    total = taxableTotal + taxExemptTotal - discountAmount;
  } else {
    subtotal = taxableTotal + taxExemptTotal;
    tax = taxableTotal * (settingsProvider.taxRate / 100);
    total = subtotal + tax - discountAmount;
  }
  
  return {
    'subtotal': subtotal,
    'tax': tax,
    'total': total + (widget.order.deliveryCharge ?? 0),
    'discount': discountAmount,
    'deliveryCharge': widget.order.deliveryCharge ?? 0.0,
  };
}
Future<void> _reprintMainReceipt() async {
  setState(() {
    _isProcessing = true;
  });
  
  try {
    // ✅ FIX: Load the actual order from database to get all items
    Order? actualOrder;
    if (widget.order.id != 0) {
      actualOrder = await _localOrderRepo.getOrderById(widget.order.id);
    }
    
    // Use the actual order if found, otherwise fall back to widget.order
    final orderToUse = actualOrder ?? Order(
      id: widget.order.id,
      staffDeviceId: actualOrder?.staffDeviceId ?? '',
      serviceType: widget.order.serviceType,
      items: widget.order.items,
      subtotal: _calculateSubtotal(widget.order.items),
      tax: _calculateSubtotal(widget.order.items) * (widget.taxRate / 100.0),
      discount: _getCurrentDiscount(),
      total: widget.order.total,
      status: 'completed',
      createdAt: DateTime.now().toIso8601String(),
      customerId: widget.customer?.id,
      depositAmount: actualOrder?.depositAmount ?? widget.order.depositAmount, 
      // FIX: Preserve delivery and event details in fallback
      deliveryCharge: widget.order.deliveryCharge,
      deliveryAddress: widget.order.deliveryAddress,
      deliveryBoy: widget.order.deliveryBoy,
      eventDate: widget.order.eventDate,
      eventTime: widget.order.eventTime,
      eventGuestCount: widget.order.eventGuestCount,
      eventType: widget.order.eventType,
    );
    // Convert order items to MenuItem objects
    final items = orderToUse.items.map((item) => 
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
    
    
    // Calculate totals from the actual order
    final subtotal = orderToUse.subtotal;
    final tax = orderToUse.tax;
    final discountAmount = orderToUse.discount;
    final total = orderToUse.total;
    
    // Extract tableInfo if this is a dining order
    String? tableInfo;
    if (orderToUse.serviceType.startsWith('Dining - Table')) {
      tableInfo = orderToUse.serviceType;
    }
    
    // Generate PDF with original order number
    final pdf = await BillService.generateBill(
      items: items,
      serviceType: orderToUse.serviceType,
      subtotal: subtotal,
      tax: tax,
      discount: discountAmount,
      total: total,
      personName: widget.customer?.name,
      tableInfo: tableInfo,
      isEdited: widget.isEdited,
      orderNumber: widget.order.orderNumber, // Use original order number
      taxRate: widget.taxRate,
      depositAmount: orderToUse.depositAmount,
      deliveryCharge: orderToUse.deliveryCharge, // Pass delivery charge
    );

    // Try to print directly first
    bool printed = false;
    try {
      printed = await BillService.printBill(
        items: items,
        serviceType: orderToUse.serviceType,
        subtotal: subtotal,
        tax: tax,
        discount: discountAmount,
        total: total,
        personName: widget.customer?.name,
        tableInfo: tableInfo,
        isEdited: widget.isEdited,
        orderNumber: widget.order.orderNumber, // Use original order number
        taxRate: widget.taxRate,
        depositAmount: orderToUse.depositAmount,
        deliveryCharge: orderToUse.deliveryCharge, // Pass delivery charge
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
      bool? saveAsPdf = await CrossPlatformPdfService.showSavePdfDialog(context);
      if (saveAsPdf == true) {
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final fileName = 'SIMS_receipt_${widget.order.orderNumber}_reprint_$timestamp.pdf';
        final saved = await CrossPlatformPdfService.savePdf(pdf, suggestedFileName: fileName);
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
          content: Text('${'Error reprinting receipt'.tr()}: ${e.toString()}'),
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

// Update the _showSavePdfDialog method
Future<bool?> _showSavePdfDialog() {
  return CrossPlatformPdfService.showSavePdfDialog(context);
}
  
  Future<void> _showBillPreviewDialog() async {
  setState(() {
    _isProcessing = true;
  });
  
  try {
    final pdf = await _generateReceipt();
    
    if (!mounted) {
      setState(() {
        _isProcessing = false;
      });
      return;
    }
    
     // For desktop, show custom dialog with reprint button
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await _showDesktopBillPreview(pdf);
    } else {
      // For mobile, use the existing preview with reprint
      await _showMobileBillPreview(pdf);
    }
    
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Error generating bill preview'.tr()}: $e')),
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
// Desktop bill preview with reprint button
Future<void> _showDesktopBillPreview(pw.Document pdf) async {
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        height: MediaQuery.of(context).size.height * 0.7,
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
                  // Add Reprint button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.print, size: 16),
                    label: Text('Reprint'.tr()),
                    onPressed: () async {
                      // Navigator.of(context).pop(); // Close preview
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.picture_as_pdf, size: 80, color: Colors.grey),
                    const SizedBox(height: 24),
                    Text(
                      '${'Receipt #'.tr()}${widget.order.orderNumber}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Click "Open PDF" to view in your default PDF viewer'.tr(),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label:  Text('Open PDF'.tr()),
                      onPressed: () async {
                        try {
                          final tempDir = await getTemporaryDirectory();
                          final pdfPath = '${tempDir.path}/receipt_${widget.order.orderNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
                          final file = File(pdfPath);
                          await file.writeAsBytes(await pdf.save());
                          final uri = Uri.file(pdfPath);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not open PDF viewer'.tr())),
                              );
                            }
                          }
                        } catch (e) {
                          debugPrint('Error opening PDF: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Mobile bill preview with reprint button (existing behavior)
Future<void> _showMobileBillPreview(pw.Document pdf) async {
  final tempDir = await getTemporaryDirectory();
  final pdfPath = '${tempDir.path}/bill_preview_${widget.order.id}.pdf';
  final file = File(pdfPath);
  await file.writeAsBytes(await pdf.save());
  
  if (!mounted) return;
  
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
                // Reprint button for mobile
                ElevatedButton.icon(
                  icon: const Icon(Icons.print, size: 16),
                  label: Text('Reprint'.tr()),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _reprintMainReceipt();
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
}

void _handleAdvancePayment() {
  String cleanInput = _amountInput.replaceAll(',', '.');
  double amount = double.tryParse(cleanInput) ?? 0.0;

  if (amount <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please enter an advance amount'.tr())),
    );
    return;
  }

  final discountedTotal = _getDiscountedTotal();
  if (amount >= discountedTotal) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Advance must be less than total. Use full payment instead.'.tr())),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Confirm Advance'.tr()),
      content: Text('${'Record Advance of'.tr()} ${amount.toStringAsFixed(3)}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'.tr()),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _processAdvance(amount);
          },
          child: Text('Confirm'.tr()),
        ),
      ],
    ),
  );
}

Future<void> _processAdvance(double amount) async {
  setState(() {
    _isProcessing = true;
  });

  try {
    // Get the full Order object from the repository
    Order? orderToUpdate;
    if (_updatedOrder != null) {
      orderToUpdate = _updatedOrder;
    } else {
      orderToUpdate = await _localOrderRepo.getOrderById(widget.order.id);
    }
    
    if (orderToUpdate == null) {
      throw Exception('Could not find order to update');
    }
    
    // Update the Order object in the database
    final updatedOrder = orderToUpdate.copyWith(
      depositAmount: amount,
      status: 'confirmed',
    );

    await _localOrderRepo.saveOrder(updatedOrder);
    
    // NEW: Force sync to ensure other devices see the advance payment
    try {
      debugPrint('🔄 Force syncing advance payment update...');
      await DeviceSyncService.syncOrderUpdate(updatedOrder);
    } catch (e) {
      debugPrint('⚠️ Error syncing advance payment: $e');
      // Non-blocking error, user still sees success locally
    }
    
    if (mounted) {
      setState(() {
        _updatedOrder = updatedOrder;
        _orderStatus = 'confirmed';
        _paidAmount = amount;
        _balanceAmount = updatedOrder.total - amount;
        _isProcessing = false;
        _amountInput = '0.000';
      });
      
      // Generate and show receipt
      _generateReceipt();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Advance recorded successfully'.tr())),
      );
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Error recording advance'.tr()}: $e')),
      );
    }
  }
}


// NEW: Split Payment Dialog with responsive layout for tablets
void _showSplitPaymentDialog() {
  if (_orderStatus.toLowerCase() == 'completed') {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No remaining balance to pay'.tr())
      ),
    );
    
    // Reset payment method and amount
    setState(() {
      _selectedPaymentMethod = null;
      _amountInput = '0.000';
    });
    return;
  }
  
  final discountedTotal = _getDiscountedTotal();
  
  _cashAmount = 0.0;
  _bankAmount = 0.0;
  // Initialize deposit mode: default to false, but logic could auto-enable for catering if needed
  _isDepositMode = false;
  
  final TextEditingController cashController = TextEditingController(text: '0.000');
  final TextEditingController bankController = TextEditingController(text: '0.000');
  
  _lastFourDigitsController.clear();
  _approvalCodeController.clear();
  _selectedCardType = 'VISA';
  
  bool isCashMode = true;
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final deposit = widget.order.depositAmount ?? 0.0;
          double remainingAmount = discountedTotal - deposit - _cashAmount - _bankAmount;
          if (remainingAmount < 0) remainingAmount = 0;
          
          void updateAmount(String value) {
            final controller = isCashMode ? cashController : bankController;
            String current = controller.text;
            
            if (value == 'C') {
              current = '0.000';
            } else if (value == '⌫') {
              if (current.length > 1) {
                current = current.substring(0, current.length - 1);
              } else {
                current = '0.000';
              }
            } else if (value == '.') {
              if (!current.contains('.')) {
                current += value;
              }
            } else {
              // Digit input
              if (current == '0.000' || current == '0') {
                 current = value;
              } else {
                 current += value;
              }
            }
            
            setState(() {
              controller.text = current;
              double val = double.tryParse(current) ?? 0.0;
              if (isCashMode) {
                _cashAmount = val;
              } else {
                _bankAmount = val;
              }
            });
          }
          
          // ✅ Check if we're on a tablet or larger device
          final isTabletOrLarger = MediaQuery.of(context).size.width >= 600;
          
          return Dialog(
            insetPadding: const EdgeInsets.all(20),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          this.setState(() {
                            _selectedPaymentMethod = null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Split Payment'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.discount, size: 14), // Smaller icon
                        label: Text('Discount'.tr()),
                        onPressed: () {
                          _shouldReopenSplitDialog = true;
                          Navigator.of(dialogContext).pop();
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted) {
                              _showDiscountDialog();
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade100,
                          foregroundColor: Colors.purple.shade900,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Smaller padding
                          textStyle: const TextStyle(fontSize: 12), // Smaller text
                          minimumSize: const Size(60, 28), // Compact size
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // ✅ Content area with responsive layout
                  Expanded(
                    child: isTabletOrLarger 
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ✅ LEFT SIDE - Summary and amount inputs (60% width)
                            Expanded(
                              flex: 6,
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Amount summary
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Subtotal:'.tr(), style: const TextStyle(fontSize: 14)),
                                              Text(
                                                discountedTotal.toStringAsFixed(3),
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ],
                                          ),
                                          if ((widget.order.deliveryCharge ?? 0.0) > 0) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Delivery Fee:'.tr(), style: const TextStyle(fontSize: 14)),
                                                Text(
                                                  (widget.order.deliveryCharge ?? 0.0).toStringAsFixed(3),
                                                  style: const TextStyle(fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if ((widget.order.depositAmount ?? 0.0) > 0) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Advance Paid:'.tr(), style: TextStyle(fontSize: 14, color: Colors.orange.shade800)),
                                                Text(
                                                  '-${(widget.order.depositAmount ?? 0.0).toStringAsFixed(3)}',
                                                  style: TextStyle(fontSize: 14, color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ],
                                          const Divider(height: 20),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Balance to Pay:'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                              Text(
                                                (discountedTotal - (widget.order.depositAmount ?? 0.0)).toStringAsFixed(3),
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 20),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Cash Amount:'.tr(), style: const TextStyle(fontSize: 14)),
                                              Text(
                                                _cashAmount.toStringAsFixed(3),
                                                style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Bank Amount:'.tr(), style: const TextStyle(fontSize: 14)),
                                              Text(
                                                _bankAmount.toStringAsFixed(3),
                                                style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 20),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(_isDepositMode ? 'Balance:'.tr() : 'Remaining:'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                              Text(
                                                remainingAmount.toStringAsFixed(3),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: remainingAmount > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    // Cash amount input
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green.shade300),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.money, color: Colors.green.shade700, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Cash Amount'.tr(),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: cashController,
                                            readOnly: true,
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    // Bank amount input
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.shade300),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.account_balance, color: Colors.blue.shade700, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Bank Amount'.tr(),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: bankController,
                                            readOnly: true,
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // ✅ RIGHT SIDE - Number pad (40% width)
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  // Mode selector
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Enter amount for:'.tr(),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  setState(() {
                                                    isCashMode = true;
                                                  });
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isCashMode ? Colors.green.shade600 : Colors.grey.shade400,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
                                                child: Text('Cash'.tr(), style: const TextStyle(fontSize: 14)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  setState(() {
                                                    isCashMode = false;
                                                  });
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: !isCashMode ? Colors.blue.shade600 : Colors.grey.shade400,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
                                                child: Text('Bank'.tr(), style: const TextStyle(fontSize: 14)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Number pad
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Expanded(child: _buildNumButton('7', () => updateAmount('7'))),
                                              Expanded(child: _buildNumButton('8', () => updateAmount('8'))),
                                              Expanded(child: _buildNumButton('9', () => updateAmount('9'))),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Expanded(child: _buildNumButton('4', () => updateAmount('4'))),
                                              Expanded(child: _buildNumButton('5', () => updateAmount('5'))),
                                              Expanded(child: _buildNumButton('6', () => updateAmount('6'))),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Expanded(child: _buildNumButton('1', () => updateAmount('1'))),
                                              Expanded(child: _buildNumButton('2', () => updateAmount('2'))),
                                              Expanded(child: _buildNumButton('3', () => updateAmount('3'))),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Expanded(child: _buildNumButton('000', () => updateAmount('000'))),
                                              Expanded(child: _buildNumButton('0', () => updateAmount('0'))),
                                              Expanded(child: _buildNumButton('⌫', () => updateAmount('⌫'), isBackspace: true)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Expanded(child: _buildNumButton('C', () => updateAmount('C'))),
                                              Expanded(child: _buildNumButton('.', () => updateAmount('.'))),
                                              Expanded(
                                                child: Container(
                                                  margin: const EdgeInsets.all(2),
                                                  child: ElevatedButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        isCashMode = !isCashMode;
                                                      });
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: isCashMode ? Colors.green.shade600 : Colors.blue.shade600,
                                                      foregroundColor: Colors.white,
                                                    ),
                                                    child: Icon(isCashMode ? Icons.money : Icons.account_balance, size: 20),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : // ✅ MOBILE/PHONE LAYOUT (vertical stack as before)
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              // Amount summary
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Subtotal:'.tr(), style: const TextStyle(fontSize: 14)),
                                        Text(
                                          discountedTotal.toStringAsFixed(3),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    if ((widget.order.deliveryCharge ?? 0.0) > 0) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Delivery Fee:'.tr(), style: const TextStyle(fontSize: 14)),
                                          Text(
                                            (widget.order.deliveryCharge ?? 0.0).toStringAsFixed(3),
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if ((widget.order.depositAmount ?? 0.0) > 0) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Advance Paid:'.tr(), style: TextStyle(fontSize: 14, color: Colors.orange.shade800)),
                                          Text(
                                            '-${(widget.order.depositAmount ?? 0.0).toStringAsFixed(3)}',
                                            style: TextStyle(fontSize: 14, color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Balance to Pay:'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        Text(
                                          (discountedTotal - (widget.order.depositAmount ?? 0.0)).toStringAsFixed(3),
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Cash Amount:'.tr(), style: const TextStyle(fontSize: 14)),
                                        Text(
                                          _cashAmount.toStringAsFixed(3),
                                          style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Bank Amount:'.tr(), style: const TextStyle(fontSize: 14)),
                                        Text(
                                          _bankAmount.toStringAsFixed(3),
                                          style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_isDepositMode ? 'Balance:'.tr() : 'Remaining:'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        Text(
                                          remainingAmount.toStringAsFixed(3),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: remainingAmount > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Cash amount input
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.money, color: Colors.green.shade700, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Cash Amount'.tr(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: cashController,
                                      readOnly: true,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.right,
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Bank amount input
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.account_balance, color: Colors.blue.shade700, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Bank Amount'.tr(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: bankController,
                                      readOnly: true,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.right,
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Mode selector
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Enter amount for:'.tr(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                isCashMode = true;
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isCashMode ? Colors.green.shade600 : Colors.grey.shade400,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: Text('Cash'.tr()),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                isCashMode = false;
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: !isCashMode ? Colors.blue.shade600 : Colors.grey.shade400,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: Text('Bank'.tr()),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Advance Payment Button for Catering
                              if (ServiceTypeUtils.normalize(widget.order.serviceType) == 'Catering')
                                Container(
                                  margin: const EdgeInsets.only(top: 16),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _isDepositMode = !_isDepositMode;
                                          // If enabling advance mode, we might want to clear current input to let them type advance
                                          if (_isDepositMode) {
                                             if (isCashMode) {
                                               _cashAmount = 0.0;
                                               cashController.text = '0.000';
                                             } else {
                                               _bankAmount = 0.0;
                                               bankController.text = '0.000';
                                             }
                                             // No _amountInput here, it uses local controllers
                                          }
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(_isDepositMode ? 'Advance Mode: Enter advance amount'.tr() : 'Full Payment Mode'.tr()),
                                            backgroundColor: _isDepositMode ? Colors.orange : Colors.grey,
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isDepositMode ? Colors.orange : Colors.grey.shade300,
                                        foregroundColor: _isDepositMode ? Colors.white : Colors.black87,
                                        elevation: _isDepositMode ? 4 : 0,
                                      ),
                                      icon: Icon(_isDepositMode ? Icons.check_circle : Icons.verified_user_outlined),
                                      label: Text(
                                        'Advance Payment'.tr(), 
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                      ),
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 16),
                              
                              // Number pad
                              SizedBox(
                                height: 280,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(child: _buildNumButton('7', () => updateAmount('7'))),
                                          Expanded(child: _buildNumButton('8', () => updateAmount('8'))),
                                          Expanded(child: _buildNumButton('9', () => updateAmount('9'))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(child: _buildNumButton('4', () => updateAmount('4'))),
                                          Expanded(child: _buildNumButton('5', () => updateAmount('5'))),
                                          Expanded(child: _buildNumButton('6', () => updateAmount('6'))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(child: _buildNumButton('1', () => updateAmount('1'))),
                                          Expanded(child: _buildNumButton('2', () => updateAmount('2'))),
                                          Expanded(child: _buildNumButton('3', () => updateAmount('3'))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(child: _buildNumButton('000', () => updateAmount('000'))),
                                          Expanded(child: _buildNumButton('0', () => updateAmount('0'))),
                                          Expanded(child: _buildNumButton('⌫', () => updateAmount('⌫'), isBackspace: true)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(child: _buildNumButton('C', () => updateAmount('C'))),
                                          Expanded(child: _buildNumButton('.', () => updateAmount('.'))),
                                          Expanded(
                                            child: Container(
                                              margin: const EdgeInsets.all(2),
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  setState(() {
                                                    isCashMode = !isCashMode;
                                                  });
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isCashMode ? Colors.green.shade600 : Colors.blue.shade600,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: Icon(isCashMode ? Icons.money : Icons.account_balance, size: 20),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                  ),
                  
                  // Action buttons
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            this.setState(() {
                              _selectedPaymentMethod = null;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text('Cancel'.tr()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (remainingAmount <= 0.001 || (_isDepositMode && (_cashAmount > 0 || _bankAmount > 0)))
                            ? () {
                              Navigator.of(dialogContext).pop();
                              // ✅ Calculate total payment amount
                              final totalAmount = _cashAmount + _bankAmount;
                              
                              // ✅ Show the payment confirmation dialog (with print option)
                               _showPaymentConfirmationDialog(totalAmount); 
                            }                           
                            : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            disabledBackgroundColor: Colors.grey.shade300,
                          ),
                          child: Text('Confirm Payment'.tr()),
                        ),
                      ),
                    ],
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
   Widget _buildNumButton(String text, VoidCallback onPressed, {bool isBackspace = false}) {
    return Container(
      margin: const EdgeInsets.all(2),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isBackspace ? Colors.grey.shade200 : Colors.white,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: isBackspace 
          ? const Icon(Icons.backspace, size: 20)
          : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
  
   // NEW: Process split payment
  Future<void> _processSplitPayment(double cashAmount, double bankAmount) async {
    setState(() {
      _isProcessing = true;
    });
    try {
      final discountedTotal = _getDiscountedTotal();
      final totalPaid = cashAmount + bankAmount;

      debugPrint('=== SPLIT PAYMENT DEBUG ===');
      debugPrint('Cash Amount: $cashAmount');
      debugPrint('Bank Amount: $bankAmount');
      debugPrint('Total Paid: $totalPaid');
      debugPrint('Discounted Total: $discountedTotal');
      
      debugPrint('Discounted Total: $discountedTotal');
      
      // ✅ Check logic modified for Deposit Mode
      final existingDeposit = widget.order.depositAmount ?? 0.0;
      final balanceToPay = discountedTotal - existingDeposit;
      
      if (!_isDepositMode && totalPaid < balanceToPay - 0.001) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Total payment is less than remaining balance'.tr())),
        );
        return;
      }
      
      double change = totalPaid > balanceToPay ? totalPaid - balanceToPay : 0.0;
      
      Order? savedOrder;
      double discountAmount = _getCurrentDiscount();
      final amounts = _calculateAmounts();
      
      if (widget.order.id != 0) {
        final orders = await _localOrderRepo.getAllOrders();
        final orderIndex = orders.indexWhere((o) => o.id == widget.order.id);
        
        if (orderIndex >= 0) {
          final existingOrder = orders[orderIndex];
          
          savedOrder = Order(
            id: existingOrder.id,
            staffDeviceId: existingOrder.staffDeviceId,
            serviceType: existingOrder.serviceType,
            items: existingOrder.items,
            subtotal: amounts['subtotal']!,
            tax: amounts['tax']!,
            discount: discountAmount,
            total: amounts['total']!,
            status: _isDepositMode ? 'confirmed' : 'completed', // 'confirmed' implies deposit paid but not fully complete
            createdAt: existingOrder.createdAt,
            customerId: widget.customer?.id ?? existingOrder.customerId,
            paymentMethod: 'bank+cash',
            cashAmount: cashAmount,  // ✅ Store cash portion
            bankAmount: bankAmount,
            depositAmount: _isDepositMode ? totalPaid : existingOrder.depositAmount, // ✅ Store deposit (or preserve existing)
            // ✅ Preserve catering/delivery fields
            deliveryCharge: existingOrder.deliveryCharge,
            deliveryAddress: existingOrder.deliveryAddress,
            deliveryBoy: existingOrder.deliveryBoy,
            eventDate: existingOrder.eventDate,
            eventTime: existingOrder.eventTime,
            eventGuestCount: existingOrder.eventGuestCount,
            eventType: existingOrder.eventType,
            tokenNumber: existingOrder.tokenNumber,
            customerName: existingOrder.customerName,
          );
          debugPrint('Creating order with split payment:');
          debugPrint('  Payment Method: ${savedOrder.paymentMethod}');
          debugPrint('  Cash Amount: ${savedOrder.cashAmount}');
          debugPrint('  Bank Amount: ${savedOrder.bankAmount}');
          debugPrint('  Total: ${savedOrder.total}');
        
          
          savedOrder = await _localOrderRepo.saveOrder(savedOrder);
           // ✅ VERIFY IT WAS SAVED CORRECTLY
          if (savedOrder.id != null) {
            final verifyOrders = await _localOrderRepo.getAllOrders();
            final verifyOrder = verifyOrders.firstWhere((o) => o.id == savedOrder!.id);
            debugPrint('VERIFICATION - Order saved:');
            debugPrint('  ID: ${verifyOrder.id}');
            debugPrint('  Payment Method: ${verifyOrder.paymentMethod}');
            debugPrint('  Cash Amount: ${verifyOrder.cashAmount}');
            debugPrint('  Bank Amount: ${verifyOrder.bankAmount}');
            debugPrint('  Total: ${verifyOrder.total}');
          }
        }
      } else {
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
          staffDeviceId: '',
          serviceType: widget.order.serviceType,
          items: orderItems,
          subtotal: amounts['subtotal']!,
          tax: amounts['tax']!,
          discount: discountAmount,
          total: amounts['total']!,
          status: _isDepositMode ? 'confirmed' : 'completed',
          createdAt: DateTime.now().toIso8601String(),
          customerId: widget.customer?.id,
          paymentMethod: 'bank+cash',
          cashAmount: cashAmount,  // ✅ Store cash portion
          bankAmount: bankAmount,
          depositAmount: _isDepositMode ? totalPaid : widget.order.depositAmount, // ✅ Store deposit (or preserve from widget)
          // ✅ Preserve catering/delivery fields
          deliveryCharge: widget.order.deliveryCharge,
          deliveryAddress: widget.order.deliveryAddress,
          deliveryBoy: widget.order.deliveryBoy,
          eventDate: widget.order.eventDate,
          eventTime: widget.order.eventTime,
          eventGuestCount: widget.order.eventGuestCount,
          eventType: widget.order.eventType,
          tokenNumber: widget.order.tokenNumber,
          customerName: widget.order.customerName,
        );
          debugPrint('Creating NEW order with split payment:');
          debugPrint('  Payment Method: ${savedOrder.paymentMethod}');
          debugPrint('  Cash Amount: ${savedOrder.cashAmount}');
          debugPrint('  Bank Amount: ${savedOrder.bankAmount}');
          debugPrint('  Total: ${savedOrder.total}');
        
        savedOrder = await _localOrderRepo.saveOrder(savedOrder);
        // ✅ VERIFY IT WAS SAVED CORRECTLY
        if (savedOrder.id != null) {
          final verifyOrders = await _localOrderRepo.getAllOrders();
          final verifyOrder = verifyOrders.firstWhere((o) => o.id == savedOrder!.id);
          debugPrint('VERIFICATION - Order saved:');
          debugPrint('  ID: ${verifyOrder.id}');
          debugPrint('  Payment Method: ${verifyOrder.paymentMethod}');
          debugPrint('  Cash Amount: ${verifyOrder.cashAmount}');
          debugPrint('  Bank Amount: ${verifyOrder.bankAmount}');
          debugPrint('  Total: ${verifyOrder.total}');
        }
      }
      
      if (savedOrder == null) {
        throw Exception('Failed to process order in the system');
      }
      
      _updatedOrder = savedOrder; // Update local tracking since widget.order is immutable/final
      
      await _updateOrderStatus(_isDepositMode ? 'confirmed' : 'completed');

      final prefs = await SharedPreferences.getInstance();
      final savedPrinterName = prefs.getString('selected_printer');
      debugPrint('Selected printer: $savedPrinterName');
      
      final pdf = await _generateReceipt();
      bool printed = false;
      
      try {
        printed = await BillService.printThermalBill(
          widget.order, 
          isEdited: widget.isEdited, 
          taxRate: widget.taxRate, 
          discount: discountAmount
        );
      } catch (e) {
        debugPrint('Printing error: $e');
      }
      if (!mounted) return;
      if (!printed) {
        bool? saveAsPdf = await CrossPlatformPdfService.showSavePdfDialog(context);
        if (saveAsPdf == true) {
          try {
            final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
            final fileName = 'SIMS_receipt_${widget.order.orderNumber}_$timestamp.pdf';
            await CrossPlatformPdfService.savePdf(pdf, suggestedFileName: fileName);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'Payment processed'.tr()} - ${'Cash'.tr()}: ${cashAmount.toStringAsFixed(3)}, ${'Bank'.tr()}: ${bankAmount.toStringAsFixed(3)}'),
            backgroundColor: Colors.green,
          ),
        );
        
        if (change > 0) {
          await _showBalanceMessageDialog(change);
        } else {
          await _showBalanceMessageDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'Error processing split payment'.tr()}: $e')),
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
  Future<bool> _updateOrderStatus(String status) async {
    try {
      // Use _updatedOrder if available (e.g. newly created order), otherwise use widget.order
      final targetId = _updatedOrder?.id ?? widget.order.id;
      
      if (targetId == 0) {
        debugPrint('Cannot update order status: invalid order ID');
        return false;
      }
      
      // ✅ FIX: Use atomic updateOrderStatus instead of getAllOrders + saveOrder
      // This prevents database locking issues
      final success = await _localOrderRepo.updateOrderStatus(targetId, status);
      
      if (success) {
        // ✅ SYNC: Sync the status update to Firestore in background
        // Don't await this call - let it run in background to prevent UI hanging
        // Use getOrderById instead of getAllOrders for efficiency
        _localOrderRepo.getOrderById(targetId).then((updatedOrder) {
          if (updatedOrder != null) {
            DeviceSyncService.syncOrderToFirestore(updatedOrder).then((_) {
              debugPrint('Background sync completed for order #$targetId status update');
            }).catchError((e) {
              debugPrint('Background sync error for order #$targetId: $e');
            });
          }
        }).catchError((e) {
          debugPrint('Error fetching order for sync: $e');
        });
        
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
    }
  }
  Future<void> _processPayment(double amount, [double change = 0.0]) async {
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

    try {
      if (widget.isCreditCompletion) {
        await _processCreditCompletionPayment(amount, _selectedPaymentMethod!.toLowerCase());
        return;
      }

      final discountedTotal = _getDiscountedTotal();
      
      // Change is now passed as an argument or uses the provided amount logic
      final deposit = widget.order.depositAmount ?? 0.0;
      final currentBalance = discountedTotal - deposit;
      if (change <= 0 && amount > currentBalance) {
        change = amount - currentBalance;
      }

      final paymentMethod = _selectedPaymentMethod!.toLowerCase();
      Order? savedOrder;
      
      final amounts = _calculateAmounts();
      
      if (widget.order.id != 0) {
        final orders = await _localOrderRepo.getAllOrders();
        final orderIndex = orders.indexWhere((o) => o.id == widget.order.id);
        
        if (orderIndex >= 0) {
          final existingOrder = orders[orderIndex];

          savedOrder = Order(
            id: existingOrder.id,
            staffDeviceId: existingOrder.staffDeviceId,
            serviceType: existingOrder.serviceType,
            items: existingOrder.items,
            subtotal: amounts['subtotal']!,
            tax: amounts['tax']!,
            discount: _getCurrentDiscount(),
            total: amounts['total']!,
            status: 'completed',
            createdAt: existingOrder.createdAt,
            customerId: widget.customer?.id ?? existingOrder.customerId,
            paymentMethod: paymentMethod,
            // ✅ Preserve catering/delivery fields
            deliveryCharge: existingOrder.deliveryCharge,
            deliveryAddress: existingOrder.deliveryAddress,
            deliveryBoy: existingOrder.deliveryBoy,
            eventDate: existingOrder.eventDate,
            eventTime: existingOrder.eventTime,
            eventGuestCount: existingOrder.eventGuestCount,
            eventType: existingOrder.eventType,
            tokenNumber: existingOrder.tokenNumber,
            customerName: existingOrder.customerName,
            depositAmount: existingOrder.depositAmount,
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
          staffDeviceId: '',
          serviceType: widget.order.serviceType,
          items: orderItems,
          subtotal: amounts['subtotal']!,
          tax: amounts['tax']!,
          discount: _getCurrentDiscount(),
          total: amounts['total']!,
          status: 'completed',
          createdAt: DateTime.now().toIso8601String(),
          customerId: widget.customer?.id,
          paymentMethod: paymentMethod,
          // ✅ Preserve catering/delivery fields
          deliveryCharge: widget.order.deliveryCharge,
          deliveryAddress: widget.order.deliveryAddress,
          deliveryBoy: widget.order.deliveryBoy,
          eventDate: widget.order.eventDate,
          eventTime: widget.order.eventTime,
          eventGuestCount: widget.order.eventGuestCount,
          eventType: widget.order.eventType,
          tokenNumber: widget.order.tokenNumber,
          customerName: widget.order.customerName,
          depositAmount: widget.order.depositAmount,
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
        printed = await BillService.printThermalBill(
          widget.order, 
          isEdited: widget.isEdited, 
          taxRate: widget.taxRate, 
          discount: _getCurrentDiscount()
        );
      } catch (e) {
        debugPrint('Printing error: $e');
        debugPrint('Attempted to print using: $savedPrinterName');
      }
      
      bool? saveAsPdf = false;
      if (!printed) {
        if (mounted) {
          saveAsPdf = await CrossPlatformPdfService.showSavePdfDialog(context);
        }
        
        if (saveAsPdf == true) {
          try {
            final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
            final fileName = 'SIMS_receipt_${widget.order.orderNumber}_$timestamp.pdf';
            await CrossPlatformPdfService.savePdf(pdf, suggestedFileName: fileName);
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

  Future<void> _showDiscountDialog() async{
    // Use updated order logic if available (e.g. if advance was just paid)
    final total = _updatedOrder?.total ?? widget.order.total;
    final deposit = _updatedOrder?.depositAmount ?? widget.order.depositAmount ?? 0.0;
    final currentBalance = total - deposit;
    
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
            
            // If we have a deposit, we should talk about "Balance", not "Total"
            final isCateringWithDeposit = deposit > 0;
            final labelCurrent = isCateringWithDeposit ? 'Current Balance'.tr() : 'Current Total'.tr();
            final labelNew = isCateringWithDeposit ? 'New Balance'.tr() : 'New Total'.tr();
            
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
                                          Text('$labelCurrent: ', style: const TextStyle(fontSize: 16)),
                                          Text(
                                            currentBalance.toStringAsFixed(3),
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
                                          Text('$labelNew: ', style: const TextStyle(fontSize: 16)),
                                          Text(
                                            (currentBalance - discountAmount).toStringAsFixed(3),
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

                                            _buildDiscountNumpadButton('.', () {
                                              setState(() {
                                                if (discountInput == '0.000'|| discountInput == '0') {
                                                  discountInput = '0.';
                                                } else {
                                                  discountInput += '.';
                                                }
                                              });
                                            }),
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
  // FIX: Deduct deposit amount for bank payment initial value
  final depositAmount = widget.order.depositAmount ?? 0.0;
  final remainingAmount = discountedTotal - depositAmount;
  
  _receivedAmountController.text = remainingAmount.toStringAsFixed(3);
  _receivedAmountController.selection = TextSelection.fromPosition(
    TextPosition(offset: _receivedAmountController.text.length),
  ); // Ensure cursor is at end
  _selectedCardType = 'VISA';
  
  // Platform check for responsive layout
  final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          double getCurrentDiscountedTotal() => _getDiscountedTotal();
          double currentDiscountedTotal = getCurrentDiscountedTotal();   

          final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;
          
          // RESPONSIVE WIDTH FIX:
          // Desktop (Windows): Keep 80% (Original)
          // Tablet/Mobile Landscape: Increase to 95% to prevent squeezing
          final dialogWidth = isPortrait 
              ? screenWidth * 0.95 
              : (isDesktop ? screenWidth * 0.8 : screenWidth * 0.96);
          
          return Dialog(
            insetPadding: EdgeInsets.all(isPortrait ? 10 : (isDesktop ? 20 : 8)),
            child: Container(
              width: dialogWidth,
              height: isPortrait ? screenHeight * 0.9 : screenHeight * 0.8, // Slightly taller on landscape too if needed
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header with discount button
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
                        'Terminal card'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      Expanded(child: Container()),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.discount, size: 14), // Smaller icon
                        label: Text('Discount'.tr()),
                         onPressed: () {
                          // Set a flag to indicate we're coming from bank dialog
                          _shouldReopenBankDialog = true;
                          
                          // Close the bank dialog
                          Navigator.of(context).pop();
                          
                          // Show discount dialog after a brief delay
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted) {
                              _showDiscountDialog();
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade100,
                          foregroundColor: Colors.purple.shade900,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Smaller padding
                          textStyle: const TextStyle(fontSize: 12), // Smaller text
                          minimumSize: const Size(60, 28), // Compact size
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Content - Different layout for portrait vs landscape
                  Expanded(
                    child: isPortrait 
                      ? _buildPortraitLayout(setState, currentDiscountedTotal,getCurrentDiscountedTotal)
                      : _buildLandscapeLayout(setState, currentDiscountedTotal,getCurrentDiscountedTotal),
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

// ... existing _buildPaymentMethodSelection ...
// ... existing _buildNumberPad ...
// ... existing _buildNumberButton ...
// ... existing _buildPaymentSummary ...
// ... existing _buildOrderInfoBar ...
// ... existing build method ...
// ... existing _buildPortraitLayout followed immediately by _buildLandscapeLayout ... 
// (We are replacing the definition of _buildLandscapeLayout below, so the StartLine is critical)

Widget _buildLandscapeLayout(StateSetter setState, double initialDiscountedTotal, Function getCurrentDiscountedTotal) {
   double currentDiscountedTotal = getCurrentDiscountedTotal();
   
   // Check platform to determine layout parameters
   final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
   
   // Tablet/Mobile optimizations: Reduce padding, adjust flex ratios
   final double containerPadding = isDesktop ? 16.0 : 10.0;
   final int labelFlex = isDesktop ? 4 : 3;
   final int inputFlex = isDesktop ? 6 : 7;
   final double spacing = isDesktop ? 16.0 : 10.0;
  
   return Row(
    children: [
      Expanded(
        flex: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input fields section
            Container(
              padding: EdgeInsets.all(containerPadding),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                   // Balance amount
                  Row(
                    children: [
                      Expanded(
                        flex: labelFlex, // Responsive flex
                        child: Text(
                          'Balance amount'.tr(),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Expanded(
                        flex: inputFlex, // Responsive flex
                        child: Text(
                          NumberFormat.currency(symbol: '', decimalDigits: 3).format(currentDiscountedTotal - (widget.order.depositAmount ?? 0.0)),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right, // Align right for better visual
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing),
                  
                  // Received amount
                  Row(
                    children: [
                      Expanded(
                        flex: labelFlex,
                        child: Text(
                          'Received'.tr(),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Expanded(
                        flex: inputFlex,
                        child: TextField(
                          controller: _receivedAmountController,
                          focusNode: _receivedFocusNode,
                          readOnly: Platform.isAndroid || Platform.isIOS,
                          keyboardType: (Platform.isAndroid || Platform.isIOS)
                              ? TextInputType.none 
                              : const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue.shade100, width: 2),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                            ),
                             contentPadding: const EdgeInsets.symmetric(vertical: 8),
                             isDense: !isDesktop, // Compact on tablet
                          ),
                          textAlign: TextAlign.right,
                          onChanged: (value) {
                            setState(() {}); 
                          },
                           onTap: () {
                            final deposit = widget.order.depositAmount ?? 0.0;
                            setState(() {
                              _receivedAmountController.text = (currentDiscountedTotal - deposit).toStringAsFixed(3);
                              // Move cursor to end
                              _receivedAmountController.selection = TextSelection.fromPosition(
                                TextPosition(offset: _receivedAmountController.text.length)
                              );
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing),
                  
                  // Last 4 digits
                  Row(
                    children: [
                      Expanded(
                        flex: labelFlex,
                        child: Text(
                          'Last 4 digit'.tr(),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Expanded(
                        flex: inputFlex,
                        child: TextField(
                          controller: _lastFourDigitsController,
                          focusNode: _lastFourFocusNode,
                          readOnly: Platform.isAndroid || Platform.isIOS,
                          keyboardType: (Platform.isAndroid || Platform.isIOS)
                              ? TextInputType.none
                              : TextInputType.number,
                          maxLength: 4,
                          decoration: InputDecoration(
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey, width: 1),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            counterText: '',
                            isDense: !isDesktop,
                          ),
                          textAlign: TextAlign.right,
                          onChanged: (value) {
                            setState(() {}); 
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing),
                  
                  // Approval code
                  Row(
                    children: [
                      Expanded(
                        flex: labelFlex,
                        child: Text(
                          'Approval code'.tr(),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Expanded(
                         flex: inputFlex,
                        child: TextField(
                          controller: _approvalCodeController,
                          focusNode: _approvalFocusNode,
                          readOnly: Platform.isAndroid || Platform.isIOS,
                          keyboardType: (Platform.isAndroid || Platform.isIOS)
                              ? TextInputType.none 
                              : TextInputType.text,
                          decoration: InputDecoration(
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey, width: 1),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                             isDense: !isDesktop,
                          ),
                          textAlign: TextAlign.right,
                          onChanged: (value) {
                            setState(() {}); 
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
             
            SizedBox(height: isDesktop ? 20 : 12),
            
            // Card types section
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Card Type'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          // ... Grid Item Builder ...
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
            ),
          ],
        ),
      ),
      
      Expanded(
        flex: 1,
        child: Container(
          padding: EdgeInsets.only(left: isDesktop ? 16 : 8),
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
                    Expanded(child: _buildNumberPadDialogButton('.', setState)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Centered Payment Button
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
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
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

// Extract payment method selection panel
Widget _buildPaymentMethodSelection() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    margin: const EdgeInsets.only(top: 8), // Reduced from 55
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPaymentMethodOption('Bank'.tr(), Icons.account_balance),
          _buildPaymentMethodOption('Cash'.tr(), Icons.money),
          _buildPaymentMethodOption('Bank + Cash'.tr(), Icons.payment),
          _buildPaymentMethodOption('Customer Credit'.tr(), Icons.person),
        ],
      ),
    ),
  );
}

Widget _buildPaymentMethodOption(String method, IconData icon) {
  final isSelected = _selectedPaymentMethod == method;
  final isCreditOption = method == 'Customer Credit'.tr();
    // Prevent selecting Customer Credit during credit completion
  final isDisabled = isCreditOption && widget.isCreditCompletion;
  
  return Container(
    margin: const EdgeInsets.only(bottom: 12), // Reduced from 25
    decoration: BoxDecoration(
      color: isSelected ? Colors.blue.shade200 : Colors.white,
      border: Border.all(
        color: isSelected ? isDisabled ? Colors.grey.shade400 : Colors.blue.shade400 : Colors.grey.shade300,
        width: 1,
      ),
      borderRadius: BorderRadius.circular(4),
    ),
    child: ListTile(
      title: Text(
        method,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blue.shade800 : Colors.black87,
        ),
        textAlign: TextAlign.center, // Center text since icon is gone
      ),
      dense: true,
      selected: isSelected,
      onTap: () {
        if (isDisabled) {
            // Reset payment method selection
              setState(() {
                _selectedPaymentMethod = null;
              });
              return;
            }
            
        setState(() {
          _selectedPaymentMethod = method;
           _isCashSelected = (method == 'Cash'.tr());
          
          if (method == 'Bank'.tr()) {
            _showBankPaymentDialog();
          }  else if (method == 'Bank + Cash'.tr()) { // NEW BLOCK
            _showSplitPaymentDialog();
          } else if (method == 'Customer Credit'.tr() && !widget.isCreditCompletion) {
            _handleCustomerCreditPayment();
          }
        });
      },
    ),
  );
}

// Extract number pad panel
Widget _buildNumberPad() {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Reduced vertical padding
        margin: const EdgeInsets.only(bottom: 8), // Added margin replacing SizedBox
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
                      _buildNumberButton('.'),
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

Widget _buildNumberButton(String text) {
  return Expanded(
    child: Container(
      margin: const EdgeInsets.all(4),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            vertical: MediaQuery.of(context).size.height < 600 ? 8 : 14
          ),
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

// Extract payment summary panel
Widget _buildPaymentSummary() {
  final formatCurrency = NumberFormat.currency(symbol: '', decimalDigits: 3);
  final discount = _getCurrentDiscount();
  // final discountedTotal = _getDiscountedTotal();

  return AbsorbPointer(
    absorbing: false,
    child: Opacity(
      opacity: 1.0,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16), // Reduced from 45
              
              Container(
                margin: const EdgeInsets.only(bottom: 12), // Reduced from 25
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
                margin: const EdgeInsets.only(bottom: 12), // Reduced from 25
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
                            formatCurrency.format(_balanceAmount),
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

  // Extract order info bar
  Widget _buildOrderInfoBar() {
    final formatCurrency = NumberFormat.currency(symbol: '', decimalDigits: 3);
    final discount = _getCurrentDiscount();
    
    return Container(
      // REDUCED PADDING: horizontal 16 -> 8 to prevent overflow
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                // REDUCED FONT: 12 -> 10
                Text('${'Customer'.tr()}:', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                // SINGLE LINE & REDUCED FONT: 14 -> 12
                Text(
                  _currentCustomer?.name ?? 'NA',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${'Order type'.tr()}:', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(
                  _getTranslatedServiceType(widget.order.serviceType), 
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${'Tables'.tr()}:', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(
                  widget.order.serviceType.contains('Table') 
                      ? widget.order.serviceType.split('Table ').last 
                      : '0',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${'Status'.tr()}:', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(width: 4),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 6, // Reduced size
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(_orderStatus),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded( // Prevent status text overflow
                      child: Text(
                        _getTranslatedStatus(_orderStatus),
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(_orderStatus),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                Text('${'Total amount'.tr()}:', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Wrap( // Use Wrap to handle potential overflow of badges
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 2,
                  children: [
                    Text(
                      formatCurrency.format(widget.order.total),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                    ),
                    if ((widget.order.deliveryCharge ?? 0) > 0)
                       Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+${formatCurrency.format(widget.order.deliveryCharge)}', // Removed 'Del.' text to save space
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    if (discount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '-${formatCurrency.format(discount)}',
                          style: TextStyle(
                            fontSize: 9,
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
      : SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth >= 900;
              
              if (isWideScreen) {
                // Wide screen: Row layout (left: payment methods, center: number pad, right: summary)
                return Column(
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
                );
              } else {
                // Narrow screen: Column layout (top: info bar, middle: payment methods & number pad, bottom: summary)
                return Column(
                  children: [
                    _buildOrderInfoBar(),
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildPaymentMethodSelection(),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              // padding: const EdgeInsets.all(16), // REMOVED to fix overflow
                              child: _buildNumberPad(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildPaymentSummary(),
                    ),
                  ],
                );
              }
            },
          ),
        ),
    bottomNavigationBar: Container(
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
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), // OPTIMIZATION: Raised buttons higher
          child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: _showDiscountDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade100,
              foregroundColor: Colors.purple.shade900,
              elevation: 1,
              padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 10),
              minimumSize: const Size(10, 36),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text('Discount'.tr()),
          ),
          
          const SizedBox(width: 8),

          if (ServiceTypeUtils.normalize(widget.order.serviceType) == 'Catering')
            ElevatedButton(
              onPressed: (_orderStatus.toLowerCase() == 'completed' || _orderStatus.toLowerCase() == 'confirmed')
                ? null
                : _handleAdvancePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade100,
                foregroundColor: Colors.orange.shade900,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 10),
                minimumSize: const Size(10, 36),
                textStyle: const TextStyle(fontSize: 12),
                disabledBackgroundColor: Colors.grey.shade200,
                disabledForegroundColor: Colors.grey.shade500,
              ),
              child: Text('Advance'.tr()),
            ),
          
          const SizedBox(width: 8),
          
          ElevatedButton(
            onPressed: (_balanceAmount == widget.order.total && _orderStatus.toLowerCase() != 'completed' && _orderStatus.toLowerCase() != 'confirmed') 
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
      ),
    ),
  );
}

// Add all remaining methods from the original file
Widget _buildPortraitLayout(StateSetter setState, double initialDiscountedTotal, Function getCurrentDiscountedTotal) {
    // Use the function to get current value instead of initial value
  double currentDiscountedTotal = getCurrentDiscountedTotal();
  
  return SingleChildScrollView(
    child: Column(
      children: [
        // Input fields section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              // Balance amount
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Balance amount'.tr(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      NumberFormat.currency(symbol: '', decimalDigits: 3).format(currentDiscountedTotal - (widget.order.depositAmount ?? 0.0)),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Received amount - Platform-aware input
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Received'.tr(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _receivedAmountController,
                      focusNode: _receivedFocusNode,
                      readOnly: Platform.isAndroid || Platform.isIOS, // Read-only on mobile, editable on desktop
                      keyboardType: (Platform.isAndroid || Platform.isIOS) 
                          ? TextInputType.none // No keyboard on mobile
                          : const TextInputType.numberWithOptions(decimal: true), // Allow keyboard on desktop
                      decoration: InputDecoration(
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue.shade100, width: 2),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      textAlign: TextAlign.right,
                      onChanged: (value) {
                        setState(() {}); // Trigger rebuild when typing
                      },
                      onTap: () {
                        // Update received amount to current discounted total minus deposit when tapped
                        final deposit = widget.order.depositAmount ?? 0.0;
                         setState(() {
                          _receivedAmountController.text = (currentDiscountedTotal - deposit).toStringAsFixed(3);
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Last 4 digits - Platform-aware input
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Last 4 digit'.tr(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _lastFourDigitsController,
                      focusNode: _lastFourFocusNode,
                      readOnly: Platform.isAndroid || Platform.isIOS, // Read-only on mobile, editable on desktop
                      keyboardType: (Platform.isAndroid || Platform.isIOS)
                          ? TextInputType.none // No keyboard on mobile
                          : TextInputType.number, // Allow keyboard on desktop
                      maxLength: 4,
                      decoration: const InputDecoration(
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey, width: 1),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        counterText: '', // Hide character counter
                      ),
                      textAlign: TextAlign.right,
                      onChanged: (value) {
                        setState(() {}); // Trigger rebuild when typing
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Approval code - Platform-aware input
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Approval code'.tr(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _approvalCodeController,
                      focusNode: _approvalFocusNode,
                      readOnly: Platform.isAndroid || Platform.isIOS, // Read-only on mobile, editable on desktop
                      keyboardType: (Platform.isAndroid || Platform.isIOS)
                          ? TextInputType.none // No keyboard on mobile
                          : TextInputType.text, // Allow keyboard on desktop
                      decoration: const InputDecoration(
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey, width: 1),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      textAlign: TextAlign.right,
                      onChanged: (value) {
                        setState(() {}); // Trigger rebuild when typing
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Card types section (keep as is)
        Container(
          height: 190,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Card Type'.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
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
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Number pad section - Adjusted height for extra button row
        SizedBox(
          height: 340, // Increased from 280
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildPortraitNumberPadButton('7', setState)),
                    Expanded(child: _buildPortraitNumberPadButton('8', setState)),
                    Expanded(child: _buildPortraitNumberPadButton('9', setState)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildPortraitNumberPadButton('4', setState)),
                    Expanded(child: _buildPortraitNumberPadButton('5', setState)),
                    Expanded(child: _buildPortraitNumberPadButton('6', setState)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildPortraitNumberPadButton('1', setState)),
                    Expanded(child: _buildPortraitNumberPadButton('2', setState)),
                    Expanded(child: _buildPortraitNumberPadButton('3', setState)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildPortraitNumberPadButton('000', setState)),
                    Expanded(child: _buildPortraitNumberPadButton('0', setState)),
                    Expanded(child: _buildPortraitNumberPadButton('⌫', setState, isBackspace: true)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildPortraitNumberPadButton('C', setState)),
                        Expanded(child: _buildPortraitNumberPadButton('.', setState)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // NEW: Centered Payment Button
                  SizedBox(
                    height: 50,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                elevation: 2,
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}



Widget _buildPortraitNumberPadButton(String text, StateSetter setState, {bool isBackspace = false}) {
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
        } else if (text == '.') {
          if (!controller.text.contains('.')) {
            setState(() {
              controller.text = controller.text + text;
            });
          }
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        minimumSize: const Size(60, 50),

      ),
      child: isBackspace 
        ? const Icon(Icons.backspace, size: 20)
        : Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
    ),
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
          } else if (text == '.') {
            if (!controller.text.contains('.')) {
              setState(() {
                controller.text = controller.text + text;
              });
            }
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
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: isBackspace 
          ? const Icon(Icons.backspace, size: 20)
          : Text(
              text,
              style: const TextStyle(
                fontSize: 18,
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
        // Reset payment method selection
      setState(() {
        _selectedPaymentMethod = null;
      });
      return;
    }

    double amount = _balanceAmount;
    
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

    if (!widget.isCreditCompletion && _balanceAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No remaining balance to pay'.tr())),
      );
       // Reset payment method selection
      setState(() {
        _selectedPaymentMethod = null;
      });
      return;
    }
    
    double change = 0.0;
    // Calculate change differently for credit completion
  if (widget.isCreditCompletion) {
    // FIX: Use discounted total for credit completion
    final discountedTotal = _getDiscountedTotal();
    if (amount > discountedTotal) {
      change = amount - discountedTotal;
    }
  } else {
    final deposit = widget.order.depositAmount ?? 0.0;
    final discountedTotal = _getDiscountedTotal();
    final currentBalance = discountedTotal - deposit;
    if (amount > currentBalance) {
      change = amount - currentBalance;
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
      // For credit completion, always process the payment
     if (widget.isCreditCompletion) {
    // Determine which payment processing method to call
    if (_selectedPaymentMethod == 'Cash'.tr()) {
      if (result == 'yes') {
        await _processCreditCompletionPayment(amount, 'cash');
      } else {
        await _processCreditCompletionPaymentWithoutPrinting(amount, 'cash');
      }
    } else if (_selectedPaymentMethod == 'Bank'.tr()) {
      if (result == 'yes') {
        await _processCreditCompletionPayment(amount, 'bank');
      } else {
        await _processCreditCompletionPaymentWithoutPrinting(amount, 'bank');
      }
    } else if (_selectedPaymentMethod == 'Bank + Cash'.tr()) {
      // ✅ Handle split payment for credit completion
      if (result == 'yes') {
        await _processCreditCompletionPayment(amount, 'bank+cash');
      } else {
        await _processCreditCompletionPaymentWithoutPrinting(amount, 'bank+cash');
      }
    }
    return; // Exit early for credit completion
  }
  
      // Regular order payment processing (not credit completion)
  setState(() {
    if (_selectedPaymentMethod == 'Cash'.tr()) {
      double amountToDeduct = _balanceAmount < amount ? _balanceAmount : amount;
      
      _balanceAmount -= amountToDeduct;
      if (_balanceAmount < 0) _balanceAmount = 0;
      
      _paidAmount += amountToDeduct;
    } else if (_selectedPaymentMethod == 'Bank + Cash'.tr()) {
      // ✅ Handle split payment state update
      final discountedTotal = _getDiscountedTotal();
      _paidAmount = discountedTotal;
      _balanceAmount = 0;
    } else {
      final discountedTotal = _getDiscountedTotal();
      _paidAmount = discountedTotal;
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
        if (_selectedPaymentMethod == 'Cash'.tr()) {
          _processCashPayment(amount, change);
        } else  if (_selectedPaymentMethod == 'Bank'.tr()) {
          _processPayment(amount, change);
        } else if (_selectedPaymentMethod == 'Bank + Cash'.tr()) {
          _processSplitPayment(_cashAmount, _bankAmount);
        }
      }else if (result == 'no') {
        if (_selectedPaymentMethod == 'Bank + Cash'.tr()) {
          await _processSplitPaymentWithoutPrinting(_cashAmount, _bankAmount);
        } else {
          await _processPaymentWithoutPrinting(amount, change);
        }

      }
    }
  }
  Future<void> _processSplitPaymentWithoutPrinting(double cashAmount, double bankAmount) async {
  setState(() {
    _isProcessing = true;
  });
  
  try {
    final discountedTotal = _getDiscountedTotal();
    final totalPaid = cashAmount + bankAmount;

    debugPrint('=== SPLIT PAYMENT WITHOUT PRINTING DEBUG ===');
    debugPrint('Cash Amount: $cashAmount');
    debugPrint('Bank Amount: $bankAmount');
    debugPrint('Total Paid: $totalPaid');
    debugPrint('Discounted Total: $discountedTotal');
    
    final existingDeposit = widget.order.depositAmount ?? 0.0;
    final balanceToPay = discountedTotal - existingDeposit;
    
    if (totalPaid < balanceToPay - 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Total payment is less than remaining balance'.tr())),
      );
      return;
    }
    
    double change = totalPaid > balanceToPay ? totalPaid - balanceToPay : 0.0;
    
    Order? savedOrder;
    double discountAmount = _getCurrentDiscount();
    final amounts = _calculateAmounts();
    
    if (widget.order.id != 0) {
      final orders = await _localOrderRepo.getAllOrders();
      final orderIndex = orders.indexWhere((o) => o.id == widget.order.id);
      
      if (orderIndex >= 0) {
        final existingOrder = orders[orderIndex];
        
        // Logic for catering partial payment
        final isCatering = existingOrder.serviceType.toLowerCase().contains('catering');
        // Calculate total paid so far including this payment
        final currentTotalPaid = (existingOrder.depositAmount ?? 0.0) + totalPaid;
        final isPartial = isCatering && (currentTotalPaid < amounts['total']! - 0.01);
        final newStatus = isPartial ? 'pending' : 'completed';
        final newDeposit = isPartial ? currentTotalPaid : existingOrder.depositAmount;

        savedOrder = Order(
          id: existingOrder.id,
          staffDeviceId: existingOrder.staffDeviceId,
          serviceType: existingOrder.serviceType,
          items: existingOrder.items,
          subtotal: amounts['subtotal']!,
          tax: amounts['tax']!,
          discount: discountAmount,
          total: amounts['total']!,
          status: newStatus,
          createdAt: existingOrder.createdAt,
          customerId: widget.customer?.id ?? existingOrder.customerId,
          paymentMethod: 'bank+cash',
          cashAmount: cashAmount,
          bankAmount: bankAmount,
          deliveryCharge: existingOrder.deliveryCharge,
          deliveryAddress: existingOrder.deliveryAddress,
          deliveryBoy: existingOrder.deliveryBoy,
          eventDate: existingOrder.eventDate,
          eventTime: existingOrder.eventTime,
          eventGuestCount: existingOrder.eventGuestCount,
          eventType: existingOrder.eventType,
          tokenNumber: existingOrder.tokenNumber,
          customerName: existingOrder.customerName,
          depositAmount: newDeposit,
        );
        
        savedOrder = await _localOrderRepo.saveOrder(savedOrder);
      }
    } else {
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
        staffDeviceId: '',
        serviceType: widget.order.serviceType,
        items: orderItems,
        subtotal: amounts['subtotal']!,
        tax: amounts['tax']!,
        discount: discountAmount,
        total: amounts['total']!,
        status: 'completed',
        createdAt: DateTime.now().toIso8601String(),
        customerId: widget.customer?.id,
        paymentMethod: 'bank+cash',
        cashAmount: cashAmount,
        bankAmount: bankAmount,
        deliveryCharge: widget.order.deliveryCharge,
        deliveryAddress: widget.order.deliveryAddress,
        deliveryBoy: widget.order.deliveryBoy,
        eventDate: widget.order.eventDate,
        eventTime: widget.order.eventTime,
        eventGuestCount: widget.order.eventGuestCount,
        eventType: widget.order.eventType,
        tokenNumber: widget.order.tokenNumber,
        customerName: widget.order.customerName,
        depositAmount: widget.order.depositAmount,
      );
      
      savedOrder = await _localOrderRepo.saveOrder(savedOrder);
    }
    
    if (savedOrder == null) {
      throw Exception('Failed to process order in the system');
    }
    
    if (widget.order.id == 0) {
      widget.order.id = savedOrder.id ?? 0;
    }
    
    await _updateOrderStatus(savedOrder.status);
    
    // SKIP PRINTING - payment processed without printing
    debugPrint('Split payment processed without printing');
    
    if (widget.order.serviceType.contains('Dining - Table')) {
      final tableNumberStr = widget.order.serviceType.split('Table ').last;
      final tableNumber = int.tryParse(tableNumberStr);
      
      if (tableNumber != null && mounted) {
        final tableProvider = Provider.of<TableProvider>(context, listen: false);
        await tableProvider.setTableStatus(tableNumber, false);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'Payment processed'.tr()} - ${'Cash'.tr()}: ${cashAmount.toStringAsFixed(3)}, ${'Bank'.tr()}: ${bankAmount.toStringAsFixed(3)}'),
          backgroundColor: Colors.green,
        ),
      );
      
      if (change > 0) {
        await _showBalanceMessageDialog(change);
      } else {
        await _showBalanceMessageDialog();
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Error processing split payment'.tr()}: $e')),
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
  Future<void> _processPaymentWithoutPrinting(double amount, double change) async {
  setState(() {
    _isProcessing = true;
  });

  try {
    // Handle credit completion case
    if (widget.isCreditCompletion) {
      // Sanitize payment method
      String methodCode = _selectedPaymentMethod!.toLowerCase();
      if (_selectedPaymentMethod == 'Cash'.tr()) {
        methodCode = 'cash';
      } else if (_selectedPaymentMethod == 'Bank'.tr()) {
        methodCode = 'bank';
      } else if (_selectedPaymentMethod == 'Bank + Cash'.tr()) {
        methodCode = 'bank+cash';
      } else if (_selectedPaymentMethod == 'Customer Credit'.tr()) {
        methodCode = 'customer_credit';
      }
      
      await _processCreditCompletionPaymentWithoutPrinting(amount, methodCode);
      return;
    }

    final discountedTotal = _getDiscountedTotal();
    final deposit = widget.order.depositAmount ?? 0.0;
    final currentBalance = discountedTotal - deposit;
    
    if (change <= 0 && amount > currentBalance) {
      change = amount - currentBalance;
    }
    
    // Sanitize payment method for DB
    String paymentMethod = _selectedPaymentMethod!.toLowerCase();
    if (_selectedPaymentMethod == 'Cash'.tr()) {
      paymentMethod = 'cash';
    } else if (_selectedPaymentMethod == 'Bank'.tr()) {
      paymentMethod = 'bank';
    } else if (_selectedPaymentMethod == 'Bank + Cash'.tr()) {
      paymentMethod = 'bank+cash';
    } else if (_selectedPaymentMethod == 'Customer Credit'.tr()) {
      paymentMethod = 'customer_credit';
    }
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
        final finalTotal = widget.order.total - discountAmount;

          // Logic for catering partial payment
          final isCatering = existingOrder.serviceType.toLowerCase().contains('catering');
          final currentTotalPaid = (existingOrder.depositAmount ?? 0.0) + amount;
          final isPartial = isCatering && (currentTotalPaid < finalTotal - 0.01);
          final newStatus = isPartial ? 'pending' : 'completed';
          final newDeposit = isPartial ? currentTotalPaid : existingOrder.depositAmount;

          savedOrder = Order(
            id: existingOrder.id,
            staffDeviceId: existingOrder.staffDeviceId,
            serviceType: existingOrder.serviceType,
            items: existingOrder.items,
            subtotal: widget.order.total - (widget.order.total * (widget.taxRate / 100)),
            tax: widget.order.total * (widget.taxRate / 100),
            discount: discountAmount,
            total: finalTotal,
            status: newStatus,
            createdAt: existingOrder.createdAt,
            customerId: widget.customer?.id ?? existingOrder.customerId,
            paymentMethod: paymentMethod,
            deliveryCharge: existingOrder.deliveryCharge,
            deliveryAddress: existingOrder.deliveryAddress,
          deliveryBoy: existingOrder.deliveryBoy,
          eventDate: existingOrder.eventDate,
          eventTime: existingOrder.eventTime,
          eventGuestCount: existingOrder.eventGuestCount,
          eventType: existingOrder.eventType,
          tokenNumber: existingOrder.tokenNumber,
          customerName: existingOrder.customerName,
          depositAmount: newDeposit,
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
        staffDeviceId: '',
        serviceType: widget.order.serviceType,
        items: orderItems,
        subtotal: widget.order.total - (widget.order.total * (widget.taxRate / 100)),
        tax: widget.order.total * (widget.taxRate / 100),
        discount: discountAmount,
        total: discountedTotal, // Use discountedTotal here too
        status: 'completed',
        createdAt: DateTime.now().toIso8601String(),
        customerId: widget.customer?.id,
        paymentMethod: paymentMethod,
        deliveryCharge: widget.order.deliveryCharge,
        deliveryAddress: widget.order.deliveryAddress,
        deliveryBoy: widget.order.deliveryBoy,
        eventDate: widget.order.eventDate,
        eventTime: widget.order.eventTime,
        eventGuestCount: widget.order.eventGuestCount,
        eventType: widget.order.eventType,
        tokenNumber: widget.order.tokenNumber,
        customerName: widget.order.customerName,
        depositAmount: widget.order.depositAmount,
      );
      
      savedOrder = await _localOrderRepo.saveOrder(savedOrder);
    }
    
    if (savedOrder == null) {
      throw Exception('Failed to process order in the system');
    }
    
    if (widget.order.id == 0) {
      widget.order.id = savedOrder.id ?? 0;
    }
    
    // Use the status from the saved order
    final statusUpdated = await _updateOrderStatus(savedOrder.status);
    
    if (!statusUpdated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order status, but continuing with payment processing'.tr())),
        );
      }
    }
    
    // SKIP PRINTING LOGIC ENTIRELY - this is the key difference
    debugPrint('Payment processed without printing');
    
    // Update table status if needed
    if (widget.order.serviceType.contains('Dining - Table')) {
      final tableNumberStr = widget.order.serviceType.split('Table ').last;
      final tableNumber = int.tryParse(tableNumberStr);
      
      if (tableNumber != null && mounted) {
        final tableProvider = Provider.of<TableProvider>(context, listen: false);
        await tableProvider.setTableStatus(tableNumber, false);
        debugPrint('Table $tableNumber status set to available after payment');
      }
    }
    
    // Clear cart and customer selection
    if (mounted) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      orderProvider.clearSelectedPerson(); 
      orderProvider.clearCart();
    }
    
    // Refresh order history
    if (mounted) {
      Provider.of<OrderHistoryProvider>(context, listen: false).refreshOrdersAndConnectivity();
    }
    
    // Show balance message
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

// Add this helper method for credit completion without printing
Future<void> _processCreditCompletionPaymentWithoutPrinting(double amount, String paymentMethod) async {
  if (widget.creditTransactionId == null || widget.customer == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invalid credit transaction'.tr())),
    );
    return;
  }

  try {
      final discountedTotal = _getDiscountedTotal();
    // Get the credit transaction details
    final creditRepo = CreditTransactionRepository();
    final creditTransaction = await creditRepo.getCreditTransactionById(widget.creditTransactionId!);
    
    if (creditTransaction == null) {
      throw Exception('Credit transaction not found');
    }
    
    // Mark credit transaction as completed
    final transactionCompleted = await creditRepo.markCreditTransactionCompleted(widget.creditTransactionId!);

    if (!mounted) return;
    if (transactionCompleted) {
      // Update customer credit balance (deduct the amount)
      final personProvider = Provider.of<PersonProvider>(context, listen: false);
      final success = await personProvider.updateCustomerCredit(
        widget.customer!.id!,
        -widget.order.total, // Negative to deduct from credit
      );

      if (success) {
        // ✅ NEW: Handle split payment for credit completion
        if (paymentMethod == 'bank+cash' && _cashAmount > 0 && _bankAmount > 0) {
          await _updateOriginalOrderPaymentMethodWithSplit(
            creditTransaction.orderNumber,
            paymentMethod.toLowerCase(),
            _cashAmount,
            _bankAmount,
          );
        } else {
          // Update the original order's payment method
          await _updateOriginalOrderPaymentMethod(
            creditTransaction.orderNumber, 
            paymentMethod.toLowerCase()
          );
        }
          // ✅ FIX: Load the actual order from database
        // final orderId = int.tryParse(creditTransaction.orderNumber);
        // Order? actualOrder;
        // if (orderId != null) {
        //   actualOrder = await _localOrderRepo.getOrderById(orderId);
        // }
        
        // if (actualOrder == null) {
        //   throw Exception('Could not load original order');
        // }
        // Use actual order for PDF generation
        // final pdf = await BillService.generateBill(
        //   items: actualOrder.items.map((item) => item.toMenuItem()).toList(),
        //   serviceType: actualOrder.serviceType,
        //   subtotal: actualOrder.subtotal,
        //   tax: actualOrder.tax,
        //   discount: actualOrder.discount,
        //   total: actualOrder.total,
        //   personName: widget.customer?.name,
        //   tableInfo: actualOrder.serviceType.contains('Table') ? actualOrder.serviceType : null,
        //   isEdited: widget.isEdited,
        //   orderNumber: creditTransaction.orderNumber,
        //   taxRate: widget.taxRate,
        // );
        
        // bool printed = false;
        //  try {
        //   printed = await BillService.printThermalBill(
        //     OrderHistory.fromOrder(actualOrder), 
        //     isEdited: widget.isEdited, 
        //     taxRate: widget.taxRate, 
        //     discount: actualOrder.discount
        //   );
        // } catch (e) {
        //   debugPrint('Printing error: $e');
        // }
        
        // bool? saveAsPdf = false;
        // if (!printed) {
        //   if (mounted) {
        //     saveAsPdf = await CrossPlatformPdfService.showSavePdfDialog(context);
        //   }
          
        //   if (saveAsPdf == true) {
        //     try {
        //       final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        //       final fileName = 'SIMS_receipt_${creditTransaction.orderNumber}_$timestamp.pdf';
        //       await CrossPlatformPdfService.savePdf(pdf, suggestedFileName: fileName);
        //     } catch (e) {
        //       debugPrint('Error saving PDF: $e');
        //     }
        //   }
        // }

        // SKIP PRINTING - just show success message
        debugPrint('Credit payment completed without printing');

        if (mounted) {
         String message;
          if (paymentMethod == 'bank+cash') {
            message = '${'Credit payment completed via'.tr()} ${'Bank + Cash'.tr()} - ${'Cash'.tr()}: ${_cashAmount.toStringAsFixed(3)}, ${'Bank'.tr()}: ${_bankAmount.toStringAsFixed(3)}';
          } else {
            message = '${'Credit payment completed via'.tr()} $paymentMethod'.tr();
          }
          // ✅ Add discount info to message if applicable
          if (_getCurrentDiscount() > 0) {
            message += ' (${'Discount'.tr()}: ${_getCurrentDiscount().toStringAsFixed(3)})';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
            ),
          );

          // Show balance message (like normal payments)
          await _showBalanceMessageDialog(amount > discountedTotal ? amount - discountedTotal : 0.0);
        }
      } else {
        throw Exception('Failed to update customer credit balance');
      }
    } else {
      throw Exception('Failed to mark transaction as completed');
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'Error completing credit payment'.tr()}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    rethrow;
  }
}

  Future<void> _processCashPayment(double amount, double change) async {
    setState(() {
      _isProcessing = true;
    });

    try {
       // Handle credit completion case
    if (widget.isCreditCompletion) {
      await _processCreditCompletionPayment(amount, 'Cash');
      return;
    }

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
          
          // Logic for catering partial payment
          final isCatering = existingOrder.serviceType.toLowerCase().contains('catering');
          final finalTotal = widget.order.total - discountAmount;
          final currentTotalPaid = (existingOrder.depositAmount ?? 0.0) + amount;
          final isPartial = isCatering && (currentTotalPaid < finalTotal - 0.01);
          final newStatus = isPartial ? 'pending' : 'completed';
          final newDeposit = isPartial ? currentTotalPaid : existingOrder.depositAmount;

          savedOrder = Order(
            id: existingOrder.id,
            staffDeviceId: existingOrder.staffDeviceId,
            serviceType: existingOrder.serviceType,
            items: existingOrder.items,
            subtotal: widget.order.total - (widget.order.total * (widget.taxRate / 100)),
            tax: widget.order.total * (widget.taxRate / 100),
            discount: discountAmount,
            total: widget.order.total - discountAmount,
            status: newStatus,
            createdAt: existingOrder.createdAt,
            customerId: widget.customer?.id ?? existingOrder.customerId,
            paymentMethod: 'cash',
            deliveryCharge: existingOrder.deliveryCharge,
            deliveryAddress: existingOrder.deliveryAddress,
            deliveryBoy: existingOrder.deliveryBoy,
            eventDate: existingOrder.eventDate,
            eventTime: existingOrder.eventTime,
            eventGuestCount: existingOrder.eventGuestCount,
            eventType: existingOrder.eventType,
            tokenNumber: existingOrder.tokenNumber,
            customerName: existingOrder.customerName,
            depositAmount: newDeposit,
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
          staffDeviceId: '',
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
          deliveryCharge: widget.order.deliveryCharge,
          deliveryAddress: widget.order.deliveryAddress,
          deliveryBoy: widget.order.deliveryBoy,
          eventDate: widget.order.eventDate,
          eventTime: widget.order.eventTime,
          eventGuestCount: widget.order.eventGuestCount,
          eventType: widget.order.eventType,
          tokenNumber: widget.order.tokenNumber,
          customerName: widget.order.customerName,
          depositAmount: widget.order.depositAmount,
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
      saveAsPdf = await CrossPlatformPdfService.showSavePdfDialog(context);
        }
        
        if (saveAsPdf == true) {
          try {
            final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
            final fileName = 'SIMS_receipt_${widget.order.orderNumber}_$timestamp.pdf';
            await CrossPlatformPdfService.savePdf(pdf, suggestedFileName: fileName);
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
                    
                    // Check if it was a catering order to return to catering list
                    final bool isCatering = widget.order.serviceType.toLowerCase().contains('catering');
                    
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => OrderListScreen(
                          isCateringOnly: isCatering,
                          // If it's not catering, we might want to default to normal view
                          excludeCatering: false, 
                        ),
                      ),
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
     // Check if order is already completed
    if (_orderStatus.toLowerCase() == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No remaining balance to pay'.tr())
        ),
      );
      
      // Reset payment method and amount
      setState(() {
        _selectedPaymentMethod = null;
        _amountInput = '0.000';
      });
      return;
    }
    if (value == 'C') {
      setState(() {
        _amountInput = '0.000';
      });
      return;
    }
    
    // Improved Logic for Decimal input
    if (value == '.') {
       if (!_amountInput.contains('.')) {
         setState(() {
            // If currently '0.000' and user types '.', assume they mean '0.'
            // But if we stick to calculator logic, '0' + '.' -> '0.'
            // If current is default '0.000', we should preserve the '0'
            if (_amountInput == '0.000') {
               _amountInput = '0.';
            } else {
               _amountInput += value;
            }
         });
       }
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
        
        if (_selectedPaymentMethod == 'Cash'.tr()) {
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
      setState(() {
        if (_amountInput.length > 1) {
          _amountInput = _amountInput.substring(0, _amountInput.length - 1);
        } else {
          _amountInput = '0.000';
        }
        
        if (_amountInput.isEmpty) _amountInput = '0.000';
      });
      return;
    }

    // Standard digit entry
    setState(() {
      if (_amountInput == '0.000' || _amountInput == '0') {
        _amountInput = value;
      } else {
        _amountInput += value;
      }
    });
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
  
  // Future<bool?> _showSavePdfDialog() {
  //   return showDialog<bool>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text('Printer Not Available'.tr()),
  //         content: Text('No printer was found. Would you like to save the receipt as a PDF?'.tr()),
  //         actions: <Widget>[
  //           TextButton(
  //             child: Text('Cancel'.tr()),
  //             onPressed: () {
  //               Navigator.of(context).pop(false);
  //             },
  //           ),
  //           TextButton(
  //             child: Text('Save PDF'.tr()),
  //             onPressed: () {
  //               Navigator.of(context).pop(true);
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // Future<bool> _saveWithAndroidIntent(pw.Document pdf) async {
  //   try {
  //     if (!Platform.isAndroid) {
  //       debugPrint('This method only works on Android');
  //       return false;
  //     }
      
  //     final tempDir = await getTemporaryDirectory();
  //     final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  //     final tempFilename = 'temp_receipt_${widget.order.orderNumber}_$timestamp.pdf';
  //     final tempFile = File('${tempDir.path}/$tempFilename');
      
  //     await tempFile.writeAsBytes(await pdf.save());
      
  //     final result = await _channel.invokeMethod('createDocument', {
  //       'path': tempFile.path,
  //       'mimeType': 'application/pdf',
  //       'fileName': 'SIMS_receipt_${widget.order.orderNumber}_$timestamp.pdf',
  //     });
      
  //     return result == true;
  //   } catch (e) {
  //     debugPrint('Error saving PDF with Android intent: $e');
  //     return false;
  //   }
  // }

  Future<pw.Document> _generateReceipt() async {
    final amounts = _calculateAmounts();
    
    // Explicitly extract properties to avoid type errors with dynamic/Object
    final orderItems = _updatedOrder?.items ?? widget.order.items;
    final serviceType = _updatedOrder?.serviceType ?? widget.order.serviceType;
    final orderNumber = _updatedOrder?.id?.toString().padLeft(4, '0') ?? widget.order.orderNumber;
    final depositAmount = _updatedOrder?.depositAmount;
    
    final pdf = await BillService.generateBill(
      items: orderItems.map((item) => item.toMenuItem()).toList(),
      serviceType: serviceType,
      subtotal: amounts['subtotal']!,
      tax: amounts['tax']!,
      discount: _getCurrentDiscount(),
      total: amounts['total']!,
      personName: null,
      tableInfo: serviceType.contains('Table') ? serviceType : null,
      isEdited: widget.isEdited,
      orderNumber: orderNumber,
      taxRate: widget.taxRate,
      depositAmount: depositAmount, 
      deliveryCharge: widget.order.deliveryCharge,
    );
    
    return pdf;
  }
  // Add this method to handle customer credit payment
 Future<void> _processCustomerCreditPayment(Person customer) async {
  final discountedTotal = _getDiscountedTotal();
  
  // Show confirmation dialog
  final confirmed = await _showCustomerCreditDialog(customer, discountedTotal);
  
  if (confirmed == true) {
    setState(() {
      _isProcessing = true;
    });

    try {
      if (!mounted) return;
      // Add credit to customer
      final personProvider = Provider.of<PersonProvider>(context, listen: false);
      final success = await personProvider.updateCustomerCredit(
        customer.id!,
        discountedTotal,
      );  

      if (success) {
        // ✅ FIX: Calculate amounts properly before saving
        final amounts = _calculateAmounts();
        final discountAmount = _getCurrentDiscount();
         // ✅ Save the order with CORRECT subtotal and tax
        Order savedOrder;
        if (widget.order.id != 0) {
          final orders = await _localOrderRepo.getAllOrders();
          final orderIndex = orders.indexWhere((o) => o.id == widget.order.id);
          
          if (orderIndex >= 0) {
            final existingOrder = orders[orderIndex];
            savedOrder = Order(
              id: existingOrder.id,
              staffDeviceId: existingOrder.staffDeviceId,
              serviceType: existingOrder.serviceType,
              items: existingOrder.items,
              subtotal: amounts['subtotal']!,  // ✅ Use calculated subtotal
              tax: amounts['tax']!,            // ✅ Use calculated tax
              discount: discountAmount,
              total: amounts['total']!,
              status: 'completed',
              createdAt: existingOrder.createdAt,
              customerId: customer.id,
              paymentMethod: 'customer_credit',
              // ✅ Preserve catering/delivery fields
              deliveryCharge: existingOrder.deliveryCharge,
              deliveryAddress: existingOrder.deliveryAddress,
              deliveryBoy: existingOrder.deliveryBoy,
              eventDate: existingOrder.eventDate,
              eventTime: existingOrder.eventTime,
              eventGuestCount: existingOrder.eventGuestCount,
              eventType: existingOrder.eventType,
              tokenNumber: existingOrder.tokenNumber,
              customerName: existingOrder.customerName,
              depositAmount: existingOrder.depositAmount,
            );
            
            savedOrder = await _localOrderRepo.saveOrder(savedOrder);
          } else {
            throw Exception('Order not found');
          }
        } else {
          throw Exception('Invalid order ID');
        }
        

         // Save credit transaction
        final creditRepo = CreditTransactionRepository();
        final transaction = CreditTransaction(
          id: 'credit_${DateTime.now().millisecondsSinceEpoch}',
          customerId: customer.id!,
          customerName: customer.name,
          orderNumber: savedOrder.id.toString(),
          amount: discountedTotal,
          createdAt: DateTime.now(),
          serviceType: widget.order.serviceType,
          isCompleted: false,
        );
        
        await creditRepo.saveCreditTransaction(transaction);
        
        // Synced
        await DeviceSyncService.syncCreditTransactionToFirestore(transaction);
        
         // Update the original order with customer_credit payment method
        // await _updateOrderPaymentMethodForCredit(widget.order.id, 'customer_credit', _getCurrentDiscount());

        // Update order status to completed (without cash payment processing)
        await _updateOrderStatus('completed');
        
        // Update table status if needed
        if (widget.order.serviceType.contains('Dining - Table')) {
          final tableNumberStr = widget.order.serviceType.split('Table ').last;
          final tableNumber = int.tryParse(tableNumberStr);
          
          if (tableNumber != null && mounted) {
            final tableProvider = Provider.of<TableProvider>(context, listen: false);
            await tableProvider.setTableStatus(tableNumber, false);
          }
        }
        
        // Clear cart and customer selection
        if (mounted) {
          final orderProvider = Provider.of<OrderProvider>(context, listen: false);
          orderProvider.clearSelectedPerson();
          orderProvider.clearCart();
        }
        
        if (mounted) {
          Provider.of<OrderHistoryProvider>(context, listen: false).refreshOrdersAndConnectivity();
        }

        if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${'Credit of'.tr()} ${discountedTotal.toStringAsFixed(3)} ${'added to'.tr()} ${customer.name}${_getCurrentDiscount() > 0 ? ' (${'after discount of'.tr()} ${_getCurrentDiscount().toStringAsFixed(3)})' : ''}'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate back to order list
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add credit to customer'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'Error processing customer credit'.tr()}: $e'),
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
  } else {
    // User cancelled, reset payment method
    setState(() {
      _selectedPaymentMethod = null;
    });
  }
}
  // Add dialog to confirm customer credit
  Future<bool?> _showCustomerCreditDialog(Person customer, double amount) async {
    final originalTotal = widget.order.total;
    final discount = _getCurrentDiscount();

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Customer Credit :'.tr(),style: const TextStyle(
            fontSize: 20,
          )),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
             Text('${'Add credit to customer'.tr()} : ${customer.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
            
              const SizedBox(height: 16),
              // Show original amount if there's a discount
            if (discount > 0) ...[
              Text('${'Original Amount:'.tr()} ${originalTotal.toStringAsFixed(3)}'),
              Text('${'Discount:'.tr()} ${discount.toStringAsFixed(3)}',
                   style: TextStyle(color: Colors.red.shade700)),
              const Divider(),
            ],

              Text('${'Credit Amount:'.tr()} ${amount.toStringAsFixed(3)}'),
              const SizedBox(height: 8),
              Text(
                '${'Current credit balance:'.tr()} ${customer.credit.toStringAsFixed(3)}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              child: Text('Add Credit'.tr()),
            ),
          ],
        );
      },
    );
  }
  // Add this method to handle customer credit
Future<void> _handleCustomerCreditPayment() async {
   // Check if order is already completed
  if (_orderStatus.toLowerCase() == 'completed') {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No remaining balance to pay'.tr()),
        ),
      );
    }
    
    // Reset payment method selection
    setState(() {
      _selectedPaymentMethod = null;
    });
    return;
  }
  
  // Check if customer is selected
  if (_currentCustomer  == null) {
    // Navigate to search person screen
    final selectedPerson = await Navigator.push<Person>(
      context,
      MaterialPageRoute(
        builder: (context) => const SearchPersonScreen(),
      ),
    );
    if (!mounted) return;
    if (selectedPerson != null) {
      // Update the order provider with selected customer
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      orderProvider.setSelectedPerson(selectedPerson);

      // IMPORTANT: Update the order in the database with customer info
      await _updateOrderWithCustomer(selectedPerson);
     // Update local state to reflect the customer selection
      setState(() {
         _currentCustomer = selectedPerson;

      });
      
      // Process the credit payment with the selected customer
      await _processCustomerCreditPayment(selectedPerson);
    } else {
      // User cancelled customer selection, reset payment method
      setState(() {
        _selectedPaymentMethod = null;
      });
    }
  } else {
    // Customer already selected, proceed with credit payment
    await _processCustomerCreditPayment(_currentCustomer!);
  }
}

  String _getTranslatedServiceType(String serviceType) {
    return ServiceTypeUtils.getTranslated(serviceType);
  }

// Add this method to TenderScreen
Future<void> _processCreditCompletionPayment(double amount, String paymentMethod) async {
  if (widget.creditTransactionId == null || widget.customer == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invalid credit transaction'.tr())),
    );
    return;
  }

  try {
    // FIX: Use discounted total for credit completion
    final discountedTotal = _getDiscountedTotal();
   // Get the credit transaction details
    final creditRepo = CreditTransactionRepository();
    final creditTransaction = await creditRepo.getCreditTransactionById(widget.creditTransactionId!);
    
    if (creditTransaction == null) {
      throw Exception('Credit transaction not found');
    }
    // Mark credit transaction as completed
    final transactionCompleted = await creditRepo.markCreditTransactionCompleted(widget.creditTransactionId!);


    if (!mounted) return;
    if (transactionCompleted) {
      // Update customer credit balance (deduct the amount)
      final personProvider = Provider.of<PersonProvider>(context, listen: false);
      final success = await personProvider.updateCustomerCredit(
        widget.customer!.id!,
        -widget.order.total, // Negative to deduct from credit
      );

      if (success) {
        // ✅ NEW: Handle split payment for credit completion
        if (paymentMethod == 'bank+cash' && _cashAmount > 0 && _bankAmount > 0) {
          // Update with split payment amounts
          await _updateOriginalOrderPaymentMethodWithSplit(
            creditTransaction.orderNumber,
            paymentMethod.toLowerCase(),
            _cashAmount,
            _bankAmount,
          );
        } else {
          // IMPORTANT: Update the original order's payment method
          await _updateOriginalOrderPaymentMethod(
            creditTransaction.orderNumber, 
            paymentMethod.toLowerCase()
          );
        }
        // ✅ FIX: Load the actual order from database
        final orderId = int.tryParse(creditTransaction.orderNumber);
        Order? actualOrder;
        if (orderId != null) {
          actualOrder = await _localOrderRepo.getOrderById(orderId);
        }
        
        if (actualOrder == null) {
          throw Exception('Could not load original order');
        }
        // ✅ Calculate tax rate from actual order data
        final effectiveTaxRate = actualOrder.subtotal > 0 
            ? (actualOrder.tax / actualOrder.subtotal) * 100 
            : 0.0;
        // Use actual order for PDF generation
        final pdf = await BillService.generateBill(
          items: actualOrder.items.map((item) => item.toMenuItem()).toList(),
          serviceType: actualOrder.serviceType,
          subtotal: actualOrder.subtotal,
          tax: actualOrder.tax,
          discount: actualOrder.discount,
          total: actualOrder.total,
          personName: widget.customer?.name,
          tableInfo: actualOrder.serviceType.contains('Table') ? actualOrder.serviceType : null,
          isEdited: widget.isEdited,
          orderNumber: creditTransaction.orderNumber,
          taxRate: effectiveTaxRate,
          deliveryCharge: actualOrder.deliveryCharge,
        );

   
        bool printed = false;
         try {
          printed = await BillService.printThermalBill(
            OrderHistory.fromOrder(actualOrder), 
            isEdited: widget.isEdited, 
            taxRate: effectiveTaxRate, 
            discount: actualOrder.discount
          );
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
              final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
              final fileName = 'SIMS_receipt_${widget.order.orderNumber}_$timestamp.pdf';
              await CrossPlatformPdfService.savePdf(pdf, suggestedFileName: fileName);
            } catch (e) {
              debugPrint('Error saving PDF: $e');
            }
          }
        }

        if (mounted) {
          String message;
          if (paymentMethod == 'bank+cash') {
            message = '${'Credit payment completed via'.tr()} ${'Bank + Cash'.tr()} - ${'Cash'.tr()}: ${_cashAmount.toStringAsFixed(3)}, ${'Bank'.tr()}: ${_bankAmount.toStringAsFixed(3)}';
          } else {
            message = '${'Credit payment completed via'.tr()} $paymentMethod'.tr();
          }
           // ✅ Add discount info to message if applicable
          if (_getCurrentDiscount() > 0) {
            message += ' (${'Discount'.tr()}: ${_getCurrentDiscount().toStringAsFixed(3)})';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
            ),
          );

          // Show balance message (like normal payments)
         await _showBalanceMessageDialog(amount > discountedTotal ? amount - discountedTotal : 0.0);
        }
      } else {
        throw Exception('Failed to update customer credit balance');
      }
    } else {
      throw Exception('Failed to mark transaction as completed');
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'Error completing credit payment'.tr()}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    rethrow;
  }
}
// Add this new method to update the original order's payment method
// Update original order payment method (used for Credit Completion)
Future<void> _updateOriginalOrderPaymentMethod(String orderNumber, String paymentMethod) async {
  try {
    final localOrderRepo = LocalOrderRepository();
    final allOrders = await localOrderRepo.getAllOrders();
    
    // Find the order by order number (the order number is the ID formatted)
    final orderId = int.tryParse(orderNumber);
    if (orderId == null) return;
    
    final orderIndex = allOrders.indexWhere((order) => order.id == orderId);
    
    if (orderIndex >= 0) {
      final existingOrder = allOrders[orderIndex];
      // ✅ FIX: Only apply discount if there's a new discount
      // Otherwise preserve the existing order's amounts
      double finalSubtotal = existingOrder.subtotal;
      double finalTax = existingOrder.tax;
      double finalDiscount = existingOrder.discount;
      double finalTotal = existingOrder.total;

      // ✅ FIX: Get current discount from tender screen
      final currentDiscount = _getCurrentDiscount();
      // final discountedTotal = _getDiscountedTotal();
      // ✅ Calculate new amounts with discount
      // final amounts = _calculateAmounts();
      if (currentDiscount > 0 && currentDiscount != existingOrder.discount) {
        // Recalculate only if discount changed
        finalDiscount = currentDiscount;
        finalTotal = existingOrder.subtotal + existingOrder.tax - finalDiscount;
      }
      
      // Create updated order with new payment method
      final updatedOrder = Order(
        id: existingOrder.id,
        staffDeviceId: existingOrder.staffDeviceId,
        serviceType: existingOrder.serviceType,
        items: existingOrder.items,
        subtotal: finalSubtotal,
        tax: finalTax,
        discount: finalDiscount,
        total: finalTotal,
        status: existingOrder.status,
        createdAt: existingOrder.createdAt,
        customerId: existingOrder.customerId,
        paymentMethod: paymentMethod, // Update the payment method
        deliveryCharge: existingOrder.deliveryCharge,
        deliveryAddress: existingOrder.deliveryAddress,
        deliveryBoy: existingOrder.deliveryBoy,
        eventDate: existingOrder.eventDate,
        eventTime: existingOrder.eventTime,
        eventGuestCount: existingOrder.eventGuestCount,
        eventType: existingOrder.eventType,
        tokenNumber: existingOrder.tokenNumber,
        customerName: existingOrder.customerName,
        depositAmount: existingOrder.depositAmount,
      );
      
      // Save the updated order
      await localOrderRepo.saveOrder(updatedOrder);
      
      // ✅ SYNC: Sync the payment method update to Firestore
      await DeviceSyncService.syncOrderToFirestore(updatedOrder);
      
      debugPrint('Updated order #$orderNumber payment method to: $paymentMethod');
    } else {
      debugPrint('Order #$orderNumber not found for payment method update');
    }
  } catch (e) {
    debugPrint('Error updating original order payment method: $e');
  }
}
// Update original order with split payment details
// Update original order with split payment details
Future<void> _updateOriginalOrderPaymentMethodWithSplit(
  String orderNumber, 
  String paymentMethod,
  double cashAmount,
  double bankAmount,
) async {
  try {
    final localOrderRepo = LocalOrderRepository();
    final allOrders = await localOrderRepo.getAllOrders();
    
    // Find the order by order number
    final orderId = int.tryParse(orderNumber);
    if (orderId == null) return;
    
    final orderIndex = allOrders.indexWhere((order) => order.id == orderId);
    
    if (orderIndex >= 0) {
      final existingOrder = allOrders[orderIndex];
       // ✅ FIX: Preserve existing amounts, only apply new discount if any
      double finalSubtotal = existingOrder.subtotal;
      double finalTax = existingOrder.tax;
      double finalDiscount = existingOrder.discount;
      double finalTotal = existingOrder.total;

      // ✅ FIX: Get current discount from tender screen
      final currentDiscount = _getCurrentDiscount();
      // final discountedTotal = _getDiscountedTotal();
      
      // ✅ Calculate new amounts with discount
      // final amounts = _calculateAmounts();
      // Check if there's a new discount being applied
    
      if (currentDiscount > 0 && currentDiscount != existingOrder.discount) {
        finalDiscount = currentDiscount;
        finalTotal = existingOrder.subtotal + existingOrder.tax - finalDiscount;
      }
      // Create updated order with split payment details
      final updatedOrder = Order(
        id: existingOrder.id,
        staffDeviceId: existingOrder.staffDeviceId,
        serviceType: existingOrder.serviceType,
        items: existingOrder.items,
        subtotal: finalSubtotal,
        tax: finalTax,
        discount: finalDiscount,
        total: finalTotal,
        status: existingOrder.status,
        createdAt: existingOrder.createdAt,
        customerId: existingOrder.customerId,
        paymentMethod: paymentMethod,
        cashAmount: cashAmount,  // ✅ Add cash amount
        bankAmount: bankAmount,  // ✅ Add bank amount
        deliveryCharge: existingOrder.deliveryCharge,
        deliveryAddress: existingOrder.deliveryAddress,
        deliveryBoy: existingOrder.deliveryBoy,
        eventDate: existingOrder.eventDate,
        eventTime: existingOrder.eventTime,
        eventGuestCount: existingOrder.eventGuestCount,
        eventType: existingOrder.eventType,
        tokenNumber: existingOrder.tokenNumber,
        customerName: existingOrder.customerName,
        depositAmount: existingOrder.depositAmount,
      );
      
      // Save the updated order
      await localOrderRepo.saveOrder(updatedOrder);
      
      // ✅ SYNC: Sync the split payment update to Firestore
      await DeviceSyncService.syncOrderToFirestore(updatedOrder);
      
      debugPrint('Updated order #$orderNumber with split payment: Cash=$cashAmount, Bank=$bankAmount');
    } else {
      debugPrint('Order #$orderNumber not found for split payment update');
    }
  } catch (e) {
    debugPrint('Error updating order with split payment: $e');
  }
}
// Add this new method to update order with customer information
// Add this new method to update order with customer information
Future<void> _updateOrderWithCustomer(Person customer) async {
  try {
    final localOrderRepo = LocalOrderRepository();
    final allOrders = await localOrderRepo.getAllOrders();
    
    final orderIndex = allOrders.indexWhere((order) => order.id == widget.order.id);
    
    if (orderIndex >= 0) {
      final existingOrder = allOrders[orderIndex];
      
      // Create updated order with customer ID
      final updatedOrder = Order(
        id: existingOrder.id,
        staffDeviceId: existingOrder.staffDeviceId,
        serviceType: existingOrder.serviceType,
        items: existingOrder.items,
        subtotal: existingOrder.subtotal,
        tax: existingOrder.tax,
        discount: existingOrder.discount,
        total: existingOrder.total,
        status: existingOrder.status,
        createdAt: existingOrder.createdAt,
        customerId: customer.id, // Update with customer ID
        paymentMethod: existingOrder.paymentMethod,
      );
      
      // Save the updated order
      await localOrderRepo.saveOrder(updatedOrder);
      
      // ✅ SYNC: Sync the customer update to Firestore
      await DeviceSyncService.syncOrderToFirestore(updatedOrder);
      
      debugPrint('Updated order #${widget.order.id} with customer: ${customer.name}');
      
      // Update the OrderHistoryProvider to refresh the data
      if (mounted) {
        Provider.of<OrderHistoryProvider>(context, listen: false).loadOrders();
      }
    }
  } catch (e) {
    debugPrint('Error updating order with customer: $e');
  }
}
 
}