import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/menu_item.dart';
import './thermal_printer_service.dart';
import '../models/order_history.dart';
import 'package:shared_preferences/shared_preferences.dart';


class BillService {
  // Get business information from shared preferences
  static Future<Map<String, String>> getBusinessInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('business_name') ?? 'SIMS RESTO CAFE',
      'address': prefs.getString('business_address') ?? '123 Cafe Street, City',
      'phone': prefs.getString('business_phone') ?? '+1234567890',
      'footer': prefs.getString('receipt_footer') ?? 'Thank you for your visit! Please come again.',
    };
  }
  // Generate PDF bill for order 
  static Future<pw.Document> generateBill({
    required List<MenuItem> items,
    required String serviceType,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    String? personName,
    String? tableInfo,
    bool isEdited = false, // Add parameter to indicate if order was edited
    String? orderNumber,
    double? taxRate, // Add tax rate parameter
  }) async {
    final pdf = pw.Document();
     final businessInfo = await getBusinessInfo();
    
    // If tax rate is not provided, use a default
    final effectiveTaxRate = taxRate ?? 0.0;
    
    // Try to load custom font if available
    pw.Font? ttf;
    try {
      final fontData = await rootBundle.load("assets/fonts/open-sans.regular.ttf");
      ttf = pw.Font.ttf(fontData.buffer.asByteData());
    } catch (e) {
      debugPrint('Could not load font, using default: $e');
      // Continue without custom font
    }
    
    // Format current date and time
    final now = DateTime.now();
    final dateFormatter = DateFormat('dd-MM-yyyy');
    final timeFormatter = DateFormat('hh:mm a');
    final formattedDate = dateFormatter.format(now);
    final formattedTime = timeFormatter.format(now);
    
    // Generate order number (simple implementation)
    final billNumber = orderNumber ?? '${now.millisecondsSinceEpoch % 10000}';
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Standard receipt roll width
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                     pw.Text('RECEIPT', 
                      style: pw.TextStyle(
                        font: ttf, 
                        fontSize: 14, 
                        fontWeight: pw.FontWeight.bold
                      )
                    ),
                    pw.Text(businessInfo['name']!, 
                      style: pw.TextStyle(
                        font: ttf, 
                        fontSize: 12, 
                        fontWeight: pw.FontWeight.bold
                      )
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(businessInfo['address']!, 
                      style: pw.TextStyle(font: ttf, fontSize: 10)
                    ),
                    pw.Text('Tel: ${businessInfo['phone']}', 
                      style: pw.TextStyle(font: ttf, fontSize: 10)
                    ),
                    pw.SizedBox(height: 3),
                    
                    // Add EDITED marker if order was edited
                    if (isEdited)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: pw.BoxDecoration(
                          // color: PdfColors.orange100,
                          // border: pw.Border.all(color: PdfColors.orange),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'EDITED',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 5,
                            fontWeight: pw.FontWeight.bold,
                            // color: PdfColors.orange900,
                          ),
                        ),
                      ),
                    
                    pw.SizedBox(height: 3),
                    
                    pw.Text('ORDER #$billNumber', 
                      style: pw.TextStyle(
                        font: ttf, 
                        fontSize: 12, 
                        fontWeight: pw.FontWeight.bold
                      )
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('$formattedDate at $formattedTime', 
                      style: pw.TextStyle(font: ttf, fontSize: 10)
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('Service: $serviceType', 
                      style: pw.TextStyle(
                        font: ttf, 
                        fontSize: 10, 
                        fontWeight: pw.FontWeight.bold
                      )
                    ),
                    // if (tableInfo != null)
                    //   pw.Text(tableInfo, style: pw.TextStyle(font: ttf, fontSize: 10)),
                    if (personName != null)
                      pw.Text('Customer: $personName', style: pw.TextStyle(font: ttf, fontSize: 10)),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 10),
              
              // Divider
              pw.Divider(thickness: 1),
              
              // Item header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5, 
                    child: pw.Text(
                      'Item', 
                      style: pw.TextStyle(
                        font: ttf, 
                        fontSize: 10, 
                        fontWeight: pw.FontWeight.bold
                      )
                    )
                  ),
                  pw.Expanded(
                    flex: 1, 
                    child: pw.Text(
                      'Qty', 
                      style: pw.TextStyle(
                        font: ttf, 
                        fontSize: 10, 
                        fontWeight: pw.FontWeight.bold
                      ), 
                      textAlign: pw.TextAlign.center
                    )
                  ),
                  pw.Expanded(
                    flex: 2, 
                    child: pw.Text(
                      'Price', 
                      style: pw.TextStyle(
                        font: ttf, 
                        fontSize: 10, 
                        fontWeight: pw.FontWeight.bold
                      ), 
                      textAlign: pw.TextAlign.right
                    )
                  ),
                  pw.Expanded(
                    flex: 2, 
                    child: pw.Text(
                      'Total', 
                      style: pw.TextStyle(
                        font: ttf, 
                        fontSize: 10, 
                        fontWeight: pw.FontWeight.bold
                      ), 
                      textAlign: pw.TextAlign.right
                    )
                  ),
                ],
              ),
              
              pw.Divider(thickness: 1),
              
              // Items
              pw.Column(
                children: items.map((item) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 5, bottom: 5),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              flex: 5, 
                              child: pw.Text(
                                item.name, 
                                style: pw.TextStyle(font: ttf, fontSize: 10)
                              )
                            ),
                            pw.Expanded(
                              flex: 1, 
                              child: pw.Text(
                                '${item.quantity}', 
                                style: pw.TextStyle(font: ttf, fontSize: 10), 
                                textAlign: pw.TextAlign.center
                              )
                            ),
                            pw.Expanded(
                              flex: 2, 
                              child: pw.Text(
                                item.price.toStringAsFixed(3), 
                                style: pw.TextStyle(font: ttf, fontSize: 10), 
                                textAlign: pw.TextAlign.right
                              )
                            ),
                            pw.Expanded(
                              flex: 2, 
                              child: pw.Text(
                                (item.price * item.quantity).toStringAsFixed(3), 
                                style: pw.TextStyle(font: ttf, fontSize: 10), 
                                textAlign: pw.TextAlign.right
                              )
                            ),
                          ],
                        ),
                      ),
                      
                      // Add kitchen note if it exists
                      if (item.kitchenNote.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 10, bottom: 5),
                          child: pw.Row(
                            children: [
                              pw.Text(
                                'Note: ',
                                style: pw.TextStyle(
                                  font: ttf,
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue900,
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  item.kitchenNote,
                                  style: pw.TextStyle(
                                    font: ttf,
                                    fontSize: 8,
                                    fontStyle: pw.FontStyle.italic,
                                    color: PdfColors.blue900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
              
              pw.Divider(thickness: 1),
              
              // Totals
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 5),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 6, 
                      child: pw.Text(
                        'Subtotal:', 
                        style: pw.TextStyle(font: ttf, fontSize: 10), 
                        textAlign: pw.TextAlign.right
                      )
                    ),
                    pw.Expanded(
                      flex: 4, 
                      child: pw.Text(
                        subtotal.toStringAsFixed(3), 
                        style: pw.TextStyle(font: ttf, fontSize: 10), 
                        textAlign: pw.TextAlign.right
                      )
                    ),
                  ],
                ),
              ),
              
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 6, 
                      child: pw.Text(
                        'Tax (${effectiveTaxRate.toStringAsFixed(1)}%):', 
                        style: pw.TextStyle(font: ttf, fontSize: 10), 
                        textAlign: pw.TextAlign.right
                      )
                    ),
                    pw.Expanded(
                      flex: 4, 
                      child: pw.Text(
                        tax.toStringAsFixed(3), 
                        style: pw.TextStyle(font: ttf, fontSize: 10), 
                        textAlign: pw.TextAlign.right
                      )
                    ),
                  ],
                ),
              ),
              
              if (discount > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 6, 
                        child: pw.Text(
                          'Discount:', 
                          style: pw.TextStyle(font: ttf, fontSize: 10), 
                          textAlign: pw.TextAlign.right
                        )
                      ),
                      pw.Expanded(
                        flex: 4, 
                        child: pw.Text(
                          discount.toStringAsFixed(3), 
                          style: pw.TextStyle(font: ttf, fontSize: 10), 
                          textAlign: pw.TextAlign.right
                        )
                      ),
                    ],
                  ),
                ),
              
              pw.Divider(thickness: 1),
              
              // Grand total
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2, bottom: 5),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 6, 
                      child: pw.Text(
                        'TOTAL:', 
                        style: pw.TextStyle(
                          font: ttf, 
                          fontSize: 12, 
                          fontWeight: pw.FontWeight.bold
                        ), 
                        textAlign: pw.TextAlign.right
                      )
                    ),
                    pw.Expanded(
                      flex: 4, 
                      child: pw.Text(
                        total.toStringAsFixed(3), 
                        style: pw.TextStyle(
                          font: ttf, 
                          fontSize: 12, 
                          fontWeight: pw.FontWeight.bold
                        ), 
                        textAlign: pw.TextAlign.right
                      )
                    ),
                  ],
                ),
              ),
              
              pw.Divider(thickness: 1),
              
              // Footer
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your visit!', 
                      style: pw.TextStyle(font: ttf, fontSize: 10)
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Please come again', 
                      style: pw.TextStyle(font: ttf, fontSize: 10)
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    
    return pdf;
  }

  // Direct thermal printing of a bill
  static Future<bool> printThermalBill(OrderHistory order, {bool isEdited = false, double? taxRate, double discount = 0.0 }) async {
    try {
      // Get the tax rate from settings if not provided
      final effectiveTaxRate = taxRate ?? 0.0;
      
      // Convert order items to MenuItem objects
      final items = order.items.map((item) => 
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
      
      // Extract tableInfo if this is a dining order
      String? tableInfo;
      if (order.serviceType.startsWith('Dining - Table')) {
        tableInfo = order.serviceType;
      }
       // Calculate the new total after discount
      double adjustedTotal = order.total - discount;
    
      
      // Use the direct printer service to print the receipt
      final printed = await ThermalPrinterService.printOrderReceipt(
        items: items,
        serviceType: order.serviceType,
        subtotal: order.total - (order.total * (effectiveTaxRate / 100)), // Use effective tax rate
        tax: order.total * (effectiveTaxRate / 100), // Use effective tax rate
        discount: discount, // No discount info in OrderHistory
        total: adjustedTotal,
        personName: null, // No customer info in OrderHistory
        tableInfo: tableInfo,
        isEdited: isEdited, // Pass the edited flag
        orderNumber: order.orderNumber,
        taxRate: effectiveTaxRate, // Pass the tax rate
      );
      
      return printed;
    } catch (e) {
      debugPrint('Error printing thermal bill: $e');
      return false;
    }
  }

  // Print the bill directly to thermal printer - Using only direct ESC/POS commands
  static Future<bool> printBill({
    required List<MenuItem> items,
    required String serviceType,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    String? personName,
    String? tableInfo,
    bool isEdited = false, // Add parameter to indicate if order was edited
    String? orderNumber,
    double? taxRate, // Add tax rate parameter
  }) async {
    try {
      // Get the tax rate from settings if not provided
      final effectiveTaxRate = taxRate ?? 0.0;
      
      // Use direct ESC/POS commands for printing
      final printed = await ThermalPrinterService.printOrderReceipt(
        items: items,
        serviceType: serviceType,
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        total: total,
        personName: personName,
        tableInfo: tableInfo,
        isEdited: isEdited, // Pass the edited flag
        orderNumber: orderNumber,
        taxRate: effectiveTaxRate, // Pass the tax rate
      );
      
      return printed;
    } catch (e) {
      debugPrint('Error printing bill: $e');
      return false;
    }
  }

  // Save PDF using Android's native Create Document Intent
  static Future<bool> saveWithAndroidIntent(pw.Document pdf) async {
    try {
      if (!Platform.isAndroid) {
        debugPrint('This method only works on Android');
        return false;
      }
      
      // First save PDF to a temporary file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final tempFilename = 'temp_receipt_$timestamp.pdf';
      final tempFile = File('${tempDir.path}/$tempFilename');
      
      // Write PDF to temporary file
      await tempFile.writeAsBytes(await pdf.save());
      
      // Create platform channel for intent
      const platform = MethodChannel('com.simsrestocafe/file_picker');
      
      // Call the native method with file path
      final result = await platform.invokeMethod('createDocument', {
        'path': tempFile.path,
        'mimeType': 'application/pdf',
        'fileName': 'SIMS_receipt_$timestamp.pdf',
      });
      
      return result == true;
    } catch (e) {
      debugPrint('Error saving PDF with Android intent: $e');
      return false;
    }
  }
  
  // Show a dialog to ask the user if they want to save the PDF
  static Future<bool?> showSavePdfDialog(BuildContext context) async {
    if (!context.mounted) return null;
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Printer Not Available'),
          content: const Text('Could not connect to the thermal printer. Would you like to save the bill as a PDF?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('Save PDF'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  // Process the order (try printing, if fails save as PDF) with tax rate
  static Future<Map<String, dynamic>> processOrderBill({
    required List<MenuItem> items,
    required String serviceType,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    String? personName,
    String? tableInfo,
    required BuildContext context,
    bool isEdited = false, // Add parameter to indicate if order was edited
    double? taxRate, // Add tax rate parameter
  }) async {
    // Get the effective tax rate
    final effectiveTaxRate = taxRate ?? 0.0;
    
    // Try to print the bill using direct ESC/POS commands only
    final printed = await printBill(
      items: items,
      serviceType: serviceType,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      total: total,
      personName: personName,
      tableInfo: tableInfo,
      isEdited: isEdited, // Pass the edited flag
      taxRate: effectiveTaxRate, // Pass the tax rate
    );
    
    if (printed) {
      // Successfully printed
      return {
        'success': true,
        'message': 'Order processed and bill printed successfully',
        'printed': true,
        'saved': false,
        'filePath': null,
      };
    }
    
    // If printing failed, check if context is still valid
    if (!context.mounted) {
      return {
        'success': false,
        'message': 'Context no longer valid',
        'printed': false,
        'saved': false,
        'filePath': null,
      };
    }
    
    // Show dialog to ask if user wants to save PDF
    final shouldSave = await showSavePdfDialog(context);
    
    // Check context again and handle null case
    if (shouldSave == null || !context.mounted) {
      return {
        'success': false,
        'message': 'Dialog was dismissed or context is no longer valid',
        'printed': false,
        'saved': false,
        'filePath': null,
      };
    }
    
    if (!shouldSave) {
      // User canceled
      return {
        'success': true, // Still mark as success as the order will be processed
        'message': 'Order processed, but bill was not printed or saved',
        'printed': false,
        'saved': false,
        'filePath': null,
      };
    }
    
    // User chose to save the PDF - generate and save it
    final pdf = await generateBill(
      items: items,
      serviceType: serviceType,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      total: total,
      personName: personName,
      tableInfo: tableInfo,
      isEdited: isEdited, // Pass the edited flag
      taxRate: effectiveTaxRate, // Pass the tax rate
    );
    
    // Save using native Android intent
    final saved = await saveWithAndroidIntent(pdf);
    
    if (saved) {
      return {
        'success': true,
        'message': 'Order processed and bill saved as PDF',
        'printed': false,
        'saved': true,
        'filePath': null,
      };
    }
    
    // If we get here, saving failed
    return {
      'success': false,
      'message': 'Failed to save the bill',
      'printed': false,
      'saved': false,
      'filePath': null,
    };
  }
  
  // Generate PDF kitchen receipt (simplified format) with tax rate
  static Future<pw.Document> generateKitchenBill({
    required List<MenuItem> items,
    required String serviceType,
    String? tableInfo,
    String? orderNumber,
  
  }) async {
    final pdf = pw.Document();
    
    // Try to load custom font if available
    pw.Font? ttf;
    try {
      final fontData = await rootBundle.load("assets/fonts/open-sans.regular.ttf");
      ttf = pw.Font.ttf(fontData.buffer.asByteData());
    } catch (e) {
      debugPrint('Could not load font, using default: $e');
      // Continue without custom font
    }
    
    // Format current date and time
    final now = DateTime.now();
    final dateFormatter = DateFormat('dd-MM-yyyy');
    final timeFormatter = DateFormat('hh:mm a');
    final formattedDate = dateFormatter.format(now);
    final formattedTime = timeFormatter.format(now);
    
    // Use provided order number or generate a new one
    final billNumber = orderNumber ?? '${now.millisecondsSinceEpoch % 10000}';
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Standard receipt roll width
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('KITCHEN ORDER', 
                      style: pw.TextStyle(
                        font: ttf, 
                        fontSize: 16, 
                        fontWeight: pw.FontWeight.bold
                      )
                    ),
                    pw.SizedBox(height: 5),
                    
                    pw.Text('ORDER #$billNumber', 
                      style: pw.TextStyle(
                        font: ttf, 
                        fontSize: 14, 
                        fontWeight: pw.FontWeight.bold
                      )
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text('$formattedDate at $formattedTime', 
                      style: pw.TextStyle(font: ttf, fontSize: 10)
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text('Service: $serviceType', 
                      style: pw.TextStyle(
                        font: ttf, 
                        fontSize: 12, 
                        fontWeight: pw.FontWeight.bold
                      )
                    ),
                    // if (tableInfo != null)
                    //   pw.Text(tableInfo, style: pw.TextStyle(font: ttf, fontSize: 12)),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 10),
              
              // Divider
              pw.Divider(thickness: 1),
              
              // Item header - simplified for kitchen
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 6, 
                    child: pw.Text(
                      'Item', 
                      style: pw.TextStyle(
                        font: ttf, 
                        fontSize: 12, 
                        fontWeight: pw.FontWeight.bold
                      )
                    )
                  ),
                  pw.Expanded(
                    flex: 2, 
                    child: pw.Text(
                      'Qty', 
                      style: pw.TextStyle(
                        font: ttf, 
                        fontSize: 12, 
                        fontWeight: pw.FontWeight.bold
                      ), 
                      textAlign: pw.TextAlign.right
                    )
                  ),
                ],
              ),
              
              pw.Divider(thickness: 1),
              
              // Items - with focus on name, quantity, and kitchen notes
              pw.Column(
                children: items.map((item) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 5, bottom: 2),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              flex: 6, 
                              child: pw.Text(
                                item.name, 
                                style: pw.TextStyle(font: ttf, fontSize: 12)
                              )
                            ),
                            pw.Expanded(
                              flex: 2, 
                              child: pw.Text(
                                '${item.quantity}', 
                                style: pw.TextStyle(font: ttf, fontSize: 12), 
                                textAlign: pw.TextAlign.right
                              )
                            ),
                          ],
                        ),
                      ),
                      
                      // Add kitchen note if present - this is important for kitchen staff
                      if (item.kitchenNote.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 10, bottom: 5),
                          child: pw.Text(
                            'NOTE: ${item.kitchenNote}',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      
                      // Add a small space between items
                      pw.SizedBox(height: 2),
                    ],
                  );
                }).toList(),
              ),
              
              pw.Divider(thickness: 1),
              
              // Footer with table number or service type for reference
              // pw.SizedBox(height: 10),
              // pw.Center(
              //   child: pw.Column(
              //     children: [
              //       if (tableInfo != null)
              //         pw.Text(
              //           'TABLE: ${tableInfo.split("Table ").last}', 
              //           style: pw.TextStyle(
              //             font: ttf, 
              //             fontSize: 14,
              //             fontWeight: pw.FontWeight.bold
              //           )
              //         ),
              //     ],
              //   ),
              // ),
            ],
          );
        },
      ),
    );
    
    return pdf;
  }
  
  // Print a kitchen-focused receipt (just item names, quantities, and notes) with tax rate
  static Future<Map<String, dynamic>> printKitchenOrderReceipt({
    required List<MenuItem> items,
    required String serviceType,
    String? tableInfo,
    String? orderNumber,
    BuildContext? context,
  
  }) async {
    try {
      // Try direct ESC/POS commands for printing a kitchen-focused receipt
      final printed = await ThermalPrinterService.printKitchenReceipt(
        items: items,
        serviceType: serviceType,
        tableInfo: tableInfo,
        orderNumber: orderNumber,
      );
      
      if (printed) {
        return {
          'success': true,
          'message': 'Kitchen receipt printed successfully',
          'printed': true,
          'saved': false,
        };
      }
      
      // If printing failed, try to save as PDF
      if (context != null && context.mounted) {
        // Generate the PDF
        final pdf = await generateKitchenBill(
          items: items,
          serviceType: serviceType,
          tableInfo: tableInfo,
          orderNumber: orderNumber,
        
        );
        
        // Show dialog to ask if user wants to save PDF
        final shouldSave = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Printer Not Available'),
              content: const Text('Could not print kitchen receipt. Would you like to save it as a PDF?'),
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
        ) ?? false;
        
      
      if (shouldSave) {
        // Save the PDF using Android intent
        final saved = await saveWithAndroidIntent(pdf);
        
        if (saved) {
          return {
            'success': true,
            'message': 'Kitchen receipt saved as PDF',
            'printed': false,
            'saved': true,
          };
        }
      }
    }
    
    // If we get here, printing and saving both failed or were declined
    return {
      'success': false,
      'message': 'Failed to print or save kitchen receipt',
      'printed': false,
      'saved': false,
    };
  } catch (e) {
    debugPrint('Error with kitchen receipt: $e');
    return {
      'success': false,
      'message': 'Error: $e',
      'printed': false,
      'saved': false,
    };
  }
}
}