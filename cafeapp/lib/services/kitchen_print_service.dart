import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/menu_item.dart';

class KitchenPrintService {
  // Print a kitchen ticket with just the menu item and note
  static Future<bool> printKitchenTicket(MenuItem item) async {
    final pdf = await generateKitchenTicket(item);
    return await printTicket(pdf);
  }
  
  // Generate a simple PDF for the kitchen with just the item info and note
  static Future<pw.Document> generateKitchenTicket(MenuItem item) async {
    final pdf = pw.Document();
    
    // Create the kitchen ticket
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
                        fontSize: 14, 
                        fontWeight: pw.FontWeight.bold
                      )
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      DateTime.now().toString().substring(0, 19), 
                      style: pw.TextStyle(fontSize: 10)
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 10),
              
              // Divider
              pw.Divider(thickness: 1),
              
              // Item details - large and prominent
              pw.Center(
                child: pw.Text(
                  item.name,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold
                  ),
                ),
              ),
              
              pw.SizedBox(height: 5),
              
              pw.Center(
                child: pw.Text(
                  'QTY: ${item.quantity}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold
                  ),
                ),
              ),
              
              pw.SizedBox(height: 10),
              
              // Kitchen note - highlighted prominently
              if (item.kitchenNote.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                    color: PdfColors.grey200,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SPECIAL INSTRUCTIONS:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        item.kitchenNote,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              
              pw.SizedBox(height: 20),
              
              // Footer with dashed line to tear
              pw.Center(
                child: pw.Text(
                  '--------------------------------',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );
    
    return pdf;
  }

  // Print the ticket to the kitchen printer
  static Future<bool> printTicket(pw.Document pdf) async {
    try {
      // Check for available printers
      final printers = await Printing.listPrinters();
      
      if (printers.isEmpty) {
        debugPrint('No printers found');
        return false;
      }
      
      // Try to find a kitchen printer specifically (if named)
      Printer kitchenPrinter = printers.firstWhere(
        (printer) => printer.name.toLowerCase().contains('kitchen'), 
        orElse: () => printers.first // Default to first printer if no kitchen printer
      );
      
      // Print the document
      await Printing.directPrintPdf(
        printer: kitchenPrinter,
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
      
      return true;
    } catch (e) {
      debugPrint('Error printing kitchen ticket: $e');
      return false;
    }
  }
}