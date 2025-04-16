import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/order_history.dart';
import '../services/bill_service.dart';
import '../utils/extensions.dart';
// import '../models/menu_item.dart';
import 'payment_success_screen.dart';

class TenderScreen extends StatefulWidget {
  final OrderHistory order;

  const TenderScreen({super.key, required this.order});

  @override
  State<TenderScreen> createState() => _TenderScreenState();
}

class _TenderScreenState extends State<TenderScreen> {
  String? _selectedPaymentMethod; // No default payment method
  String _amountInput = '0.000';
  double _balanceAmount = 0.0;
  bool _isProcessing = false;
  bool _isCashSelected = false;

  // Denomination values
  final List<String> _cashDenominations = ['2.000','5.000', '10.000', '20.000', '50.000', '100.000'];

  @override
  void initState() {
    super.initState();
    _balanceAmount = widget.order.total;
  }

  // Process payment calculation
  void _processPayment(double amount) async {
    // Check if payment method is selected
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

    try {
      // Generate the receipt PDF
      final pdf = await _generateReceipt();
      
      // Try to print the receipt
      bool printed = false;
      try {
        final printers = await Printing.listPrinters();
        if (printers.isNotEmpty) {
          await Printing.directPrintPdf(
            printer: printers.first,
            onLayout: (format) async => pdf.save(),
          );
          printed = true;
        }
      } catch (e) {
        debugPrint('Printing error: $e');
      }

      bool? saveAsPdf = false;
      if (!printed) {
        // If printing failed, offer to save as PDF
        saveAsPdf = await _showSavePdfDialog();
        
        if (saveAsPdf == true) {
          try {
            // Try using the built-in print dialog first
            final saved = await Printing.layoutPdf(
              onLayout: (format) async => pdf.save(),
              name: 'receipt_${widget.order.id}_${DateTime.now().millisecondsSinceEpoch}.pdf',
            );
            
            if (!saved) {
              // If that fails, save to a temp file and use the Share API
              final tempDir = await getTemporaryDirectory();
              final file = File('${tempDir.path}/receipt_${widget.order.id}_${DateTime.now().millisecondsSinceEpoch}.pdf');
              await file.writeAsBytes(await pdf.save());
              await Printing.sharePdf(
                bytes: await pdf.save(),
                filename: 'receipt_${widget.order.id}.pdf',
              );
            }
          } catch (e) {
            debugPrint('Error saving PDF: $e');
          }
        }
      }

      // Show success screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              order: widget.order,
              isPrinted: printed,
              isPdfSaved: !printed && (saveAsPdf == true),
            ),
          ),
        );
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

  // Apply quick denomination value
  void _applyDenomination(String denomination) {
    double value = double.tryParse(denomination) ?? 0.0;
    if (value > 0) {
      setState(() {
        _amountInput = denomination;
        
        // Automatically add the denomination
        if (_balanceAmount > 0) {
          double newBalance = _balanceAmount - value;
          if (newBalance < 0) newBalance = 0;
          _balanceAmount = newBalance;
          
          // Clear input after adding
          _amountInput = '0.000';
        }
      });
    }
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

  // Generate the receipt using the PDF library
  Future<pw.Document> _generateReceipt() async {
    final pdf = await BillService.generateBill(
      items: widget.order.items.map((item) => 
        item.toMenuItem()
      ).toList(),
      serviceType: widget.order.serviceType,
      subtotal: widget.order.total - (widget.order.total * 0.05),
      tax: widget.order.total * 0.05,
      discount: 0,
      total: widget.order.total,
      personName: null,
      tableInfo: widget.order.serviceType.contains('Table') ? widget.order.serviceType : null,
    );
    
    return pdf;
  }

  // Update amount input
  void _updateAmount(String value) {
    if (value == 'C') {
      setState(() {
        _amountInput = '0.000';
      });
      return;
    }

    if (value == 'Add') {
      double amount = double.tryParse(_amountInput) ?? 0;
      if (amount > 0) {
        // Check for payment method
        if (_selectedPaymentMethod == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a payment method')),
          );
          return;
        }
        
        setState(() {
          _balanceAmount = _balanceAmount - amount;
          if (_balanceAmount < 0) _balanceAmount = 0;
          
          // Clear input after adding
          _amountInput = '0.000';
          
          // We're removing this automatic payment processing
          // If balance is zero or payment exceeds total, process the payment automatically
          // if (_balanceAmount <= 0) {
          //   _processPayment(amount);
          // }
        });
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
          _buildPaymentMethodOption('Coupon', Icons.card_giftcard),
          _buildPaymentMethodOption('Customer Credit', Icons.person),
          _buildPaymentMethodOption('Credit Sale', Icons.credit_card),
        ],
      ),
    );
  }

  // Build each payment method option - styled to match the image
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
          });
        },
      ),
    );
  }

  // Build individual number buttons - with the calculator style
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
          onPressed: () => _updateAmount(text),
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
              children: const [
                Text('Customer :', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text('NA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
          
          // Tax amount
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tax amount :', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  formatCurrency.format(widget.order.total * 0.05),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
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
                Text(
                  formatCurrency.format(widget.order.total),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          ),
          alignment: Alignment.centerRight,
          child: Text(
            _amountInput,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Use Expanded to fill available space
        Expanded(
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
      ],
    );
  }

  // Build payment summary - styled to match the image
  Widget _buildPaymentSummary() {
    // Format for currency display
    final formatCurrency = NumberFormat.currency(symbol: '', decimalDigits: 3);
    
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order info
            // Column(
            //   crossAxisAlignment: CrossAxisAlignment.start,
            //   children: [
            //     Row(
            //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //       children: const [
            //         Text('Customer:', style: TextStyle(fontSize: 14)),
            //         Text('NA', style: TextStyle(fontSize: 14)),
            //       ],
            //     ),
            //     const SizedBox(height: 4),
            //     Row(
            //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //       children: [
            //         const Text('Order type:', style: TextStyle(fontSize: 14)),
            //         Text(widget.order.serviceType, style: const TextStyle(fontSize: 14)),
            //       ],
            //     ),
            //     const SizedBox(height: 4),
            //     Row(
            //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //       children: [
            //         const Text('Tables:', style: TextStyle(fontSize: 14)),
            //         Text(
            //           widget.order.serviceType.contains('Table') 
            //               ? widget.order.serviceType.split('Table ').last 
            //               : '0',
            //           style: const TextStyle(fontSize: 14)
            //         ),
            //       ],
            //     ),
            //     const SizedBox(height: 4),
            //     Row(
            //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //       children: [
            //         const Text('Tax amount:', style: TextStyle(fontSize: 14)),
            //         Text(
            //           formatCurrency.format(widget.order.total * 0.05),
            //           style: const TextStyle(fontSize: 14)
            //         ),
            //       ],
            //     ),
            //     const SizedBox(height: 4),
            //     Row(
            //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //       children: [
            //         const Text('Total amount:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            //         Text(
            //           formatCurrency.format(widget.order.total),
            //           style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
            //         ),
            //       ],
            //     ),
            //   ],
            // ),
            
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
                      formatCurrency.format(widget.order.total - _balanceAmount),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            
            // Balance amount section (clickable card) 
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Balance amount:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  // onTap: () {
                  //   if (_balanceAmount > 0) {
                  //     // When card is clicked
                  //     if (_selectedPaymentMethod != null) {
                  //       _processPayment(_balanceAmount);
                  //     } else {
                  //       ScaffoldMessenger.of(context).showSnackBar(
                  //         const SnackBar(content: Text('Please select a payment method')),
                  //       );
                  //     }
                  //   }
                  // },
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
            
            // Denomination boxes - only shown when Cash is selected
            if (_isCashSelected) ...[
              const SizedBox(height: 32),
              
              // First box centered
              if (_cashDenominations.isNotEmpty)
                Center(
                  child: SizedBox(
                    width: (MediaQuery.of(context).size.width / 3) * 0.6,
                    height: 40,
                    child: _buildDenominationBox(_cashDenominations[0]),
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // Remaining boxes in pairs (2 per row) - evenly spaced
              if (_cashDenominations.length > 1)
                for (int i = 1; i < _cashDenominations.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                          width: (MediaQuery.of(context).size.width / 3) * 0.45,
                          height: 40,
                          child: _buildDenominationBox(_cashDenominations[i]),
                        ),
                        if (i + 1 < _cashDenominations.length)
                          SizedBox(
                            width: (MediaQuery.of(context).size.width / 3) * 0.45,
                            height: 40,
                            child: _buildDenominationBox(_cashDenominations[i + 1]),
                          ),
                      ],
                    ),
                  ),
              
              // Add space at the bottom to prevent overflow
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
  
  // Helper to build denomination boxes
  Widget _buildDenominationBox(String amount) {
    return GestureDetector(
      onTap: () => _applyDenomination(amount),
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
        child: Text(
          amount,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
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
        padding: const EdgeInsets.all(8),
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
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                foregroundColor: Colors.blue.shade700,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Save'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: (_balanceAmount <= 0 && _selectedPaymentMethod != null)
                ? () {
                    // Now we use _processPayment here to resolve the unused element warning
                    if (_selectedPaymentMethod != null) {
                      _processPayment(widget.order.total);
                    } else {
                      Navigator.of(context).pop();
                    }
                  }
                : null,
              child: const Text('Finish'),
            ),
          ],
        ),
      ),
    );
  }
}