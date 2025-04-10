import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/menu_item.dart';

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
                  return pw.Padding(
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

  // Print the bill using a printer
  static Future<bool> printBill(pw.Document pdf) async {
    try {
      // Check for available printers
      final printers = await Printing.listPrinters();
      
      if (printers.isNotEmpty) {
        // Use the first available printer
        final printer = printers.first;
        
        // Print the document
        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
        
        return true;
      } else {
        // No printers available
        return false;
      }
    } catch (e) {
      debugPrint('Error printing bill: $e');
      return false;
    }
  }

  // Use Printing.pickDirectory to let user choose where to save file
  static Future<bool> saveBillToDownloads(pw.Document pdf) async {
    try {
      // First, save PDF to a temporary file
      final output = await getTemporaryDirectory();
      final filename = 'cafe_order_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final tempFile = File('${output.path}/$filename');
      
      // Write PDF to temporary file
      await tempFile.writeAsBytes(await pdf.save());
      
      // Now use Share.shareXFiles to open the save dialog
      final xFile = XFile(tempFile.path, mimeType: 'application/pdf');
      
      // This will open the share dialog where users can choose to save the file
      await Share.shareXFiles(
        [xFile],
        text: 'Order Receipt',
        subject: 'Cafe Order Receipt',
      );
      
      return true;
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      return false;
    }
  }
  
  // Use Printing.layoutPdf to let user choose where to save the file
  static Future<bool> saveBillWithFilePicker(pw.Document pdf) async {
    try {
      // This will open the native file picker dialog for saving the PDF
      final successful = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'cafe_order_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      
      return successful;
    } catch (e) {
      debugPrint('Error using print dialog: $e');
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
          content: const Text('No printer was found or printing failed. Would you like to save the bill as a PDF?'),
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

  // Show a dialog to ask the user if they want to try an alternative save method
  static Future<bool?> showAlternativeMethodDialog(BuildContext context) async {
    if (!context.mounted) return null;
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Try Alternative Method'),
          content: const Text('Would you like to try saving with the share menu instead?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('Yes'),
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
    // First generate the PDF bill
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
    
    // Try to print the bill
    final printed = await printBill(pdf);
    
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
    
    // User chose to save the PDF - show file picker dialog
    final saved = await saveBillWithFilePicker(pdf);
    
    if (saved) {
      return {
        'success': true,
        'message': 'Order processed and bill saved as PDF',
        'printed': false,
        'saved': true,
        'filePath': null,
      };
    }
    
    // If we get here, saving with file picker failed
    // Check if context is still valid before showing dialog
    if (!context.mounted) {
      return {
        'success': false,
        'message': 'Context no longer valid',
        'printed': false,
        'saved': false,
        'filePath': null,
      };
    }
    
    // Ask user if they want to try the share approach
    final shouldTryShare = await showAlternativeMethodDialog(context);
    
    // Check context again and handle null case
    if (shouldTryShare == null || !context.mounted) {
      return {
        'success': false,
        'message': 'Dialog was dismissed or context is no longer valid',
        'printed': false,
        'saved': false,
        'filePath': null,
      };
    }
    
    if (!shouldTryShare) {
      // User chose not to try alternative method
      return {
        'success': false,
        'message': 'Failed to save the bill',
        'printed': false,
        'saved': false,
        'filePath': null,
      };
    }
    
    // Try the share approach
    final savedWithShare = await saveBillToDownloads(pdf);
    
    return {
      'success': savedWithShare,
      'message': savedWithShare ? 'Order processed and bill shared' : 'Failed to share the bill',
      'printed': false,
      'saved': savedWithShare,
      'filePath': null,
    };
  }
}