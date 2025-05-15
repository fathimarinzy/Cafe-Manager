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

class BillService {
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
    
    // Generate order number (simple implementation)
    final orderNumber = '${now.millisecondsSinceEpoch % 10000}';
    
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
                    pw.Text('SIMS RESTO CAFE', 
                      style: pw.TextStyle(
                        font: ttf, 
                        fontSize: 14, 
                        fontWeight: pw.FontWeight.bold
                      )
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text('123 Cafe Street, City', 
                      style: pw.TextStyle(font: ttf, fontSize: 10)
                    ),
                    pw.Text('Tel: +1234567890', 
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
                    
                    pw.Text('ORDER #$orderNumber', 
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
                    if (tableInfo != null)
                      pw.Text(tableInfo, style: pw.TextStyle(font: ttf, fontSize: 10)),
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
                        'Tax:', 
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
  static Future<bool> printThermalBill(OrderHistory order, {bool isEdited = false}) async {
    try {
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
      
      // Use the direct printer service to print the receipt
      final printed = await ThermalPrinterService.printOrderReceipt(
        items: items,
        serviceType: order.serviceType,
        subtotal: order.total - (order.total * 0.05), // Estimate subtotal as 95% of total
        tax: order.total * 0.05, // Estimate tax as 5% of total
        discount: 0, // No discount info in OrderHistory
        total: order.total,
        personName: null, // No customer info in OrderHistory
        tableInfo: tableInfo,
        isEdited: isEdited, // Pass the edited flag
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
  }) async {
    try {
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

  // Process the order (try printing, if fails save as PDF)
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
  }) async {
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
}