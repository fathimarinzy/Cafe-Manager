import 'dart:io';
import 'package:flutter/services.dart';
// import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../models/menu_item.dart';
import './thermal_printer_service.dart';
import '../models/order_history.dart';

class BillService {
  // Generate PDF bill for order - used only for saving as PDF, not for printing
  static Future<pw.Document> generateBill({
    required List<MenuItem> items,
    required String serviceType,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    String? personName,
    String? tableInfo,
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
                    pw.SizedBox(height: 5),
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
  static Future<bool> printThermalBill(OrderHistory order) async {
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
      );
      
      return printed;
    } catch (e) {
      debugPrint('Error printing bill: $e');
      return false;
    }
  }

  // New method: Save PDF file with file picker to let the user choose the location
  static Future<String?> savePdfWithFilePicker(pw.Document pdf, {String defaultFileName = ''}) async {
    try {
      // Generate default filename if not provided
      String fileName = defaultFileName.isNotEmpty 
          ? defaultFileName 
          : 'cafe_order_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      // Generate the PDF data
      final pdfBytes = await pdf.save();
      
      // Use FilePicker to get the save location from the user
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Receipt',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      
      // If user canceled the save dialog
      if (outputPath == null) {
        debugPrint('User canceled the save dialog');
        return null;
      }
      
      // Make sure the file path has .pdf extension
      if (!outputPath.toLowerCase().endsWith('.pdf')) {
        outputPath = '$outputPath.pdf';
      }
      
      // Write PDF to chosen file path
      final file = File(outputPath);
      await file.writeAsBytes(pdfBytes);
      
      debugPrint('PDF saved to: $outputPath');
      return outputPath;
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      return null;
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
    );
    
    // Generate a sensible filename
    final now = DateTime.now();
    final dateString = DateFormat('yyyyMMdd_HHmmss').format(now);
    final orderNumber = now.millisecondsSinceEpoch % 10000;
    final fileName = 'receipt_order${orderNumber}_$dateString.pdf';
    
    // Use FilePicker to save file where user chooses
    final filePath = await savePdfWithFilePicker(pdf, defaultFileName: fileName);
    
    if (filePath != null) {
      return {
        'success': true,
        'message': 'Order processed and bill saved as PDF',
        'printed': false,
        'saved': true,
        'filePath': filePath,
      };
    }
    
    // If we get here, saving with FilePicker approach failed
    return {
      'success': false,
      'message': 'Failed to save the bill',
      'printed': false,
      'saved': false,
      'filePath': null,
    };
  }
}