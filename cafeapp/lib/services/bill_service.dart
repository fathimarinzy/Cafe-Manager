import 'dart:io';
import 'package:cafeapp/utils/app_localization.dart';
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
      'name': prefs.getString('business_name') ?? 'SIMS CAFE',
      'second_name': prefs.getString('second_business_name') ?? '',
      'address': prefs.getString('business_address') ?? '',
      'phone': prefs.getString('business_phone') ?? '',
      'footer': prefs.getString('receipt_footer') ?? 'Thank you for your visit! Please come again.',
    };
  }

  // Load Arabic-compatible font
  static Future<pw.Font?> _loadArabicFont() async {
    try {
      // Try to load Cairo font (good for Arabic)
      final fontData = await rootBundle.load("assets/fonts/cairo-regular.ttf");
      return pw.Font.ttf(fontData.buffer.asByteData());
    } catch (e) {
      try {
        // Fallback to Noto Sans Arabic
        final fontData = await rootBundle.load("assets/fonts/noto-sans-arabic.ttf");
        return pw.Font.ttf(fontData.buffer.asByteData());
      } catch (e2) {
        try {
          // Fallback to Amiri font
          final fontData = await rootBundle.load("assets/fonts/amiri-regular.ttf");
          return pw.Font.ttf(fontData.buffer.asByteData());
        } catch (e3) {
          debugPrint('Could not load any Arabic font: $e3');
          return null;
        }
      }
    }
  }

  // Check if text contains Arabic characters
  static bool _containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  // Get appropriate text direction for Arabic text
  static pw.TextDirection _getTextDirection(String text) {
    return _containsArabic(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  }

  // Create text widget with proper direction and font
  static pw.Widget _createText(
    String text, {
    pw.Font? arabicFont,
    pw.TextStyle? style,
    pw.TextAlign? textAlign,
  }) {
    final textDirection = _getTextDirection(text);
    final useArabicFont = _containsArabic(text) && arabicFont != null;
    
    return pw.Directionality(
      textDirection: textDirection,
      child: pw.Text(
        text,
        style: style?.copyWith(
          font: useArabicFont ? arabicFont : style.font,
        ) ?? pw.TextStyle(
          font: useArabicFont ? arabicFont : null,
        ),
        textAlign: textAlign,
        textDirection: textDirection,
      ),
    );
  }

  // Replace the generateBill method in BillService class
static Future<pw.Document> generateBill({
  required List<MenuItem> items,
  required String serviceType,
  required double subtotal,
  required double tax,
  required double discount,
  required double total,
  String? personName,
  String? tableInfo,
  bool isEdited = false,
  String? orderNumber,
  double? taxRate,
}) async {
  final pdf = pw.Document();
  final businessInfo = await getBusinessInfo();
  
  // If tax rate is not provided, use a default
  final effectiveTaxRate = taxRate ?? 0.0;
  
  // Load Arabic-compatible font
  final arabicFont = await _loadArabicFont();
  
  // Try to load fallback font for non-Arabic text
  pw.Font? fallbackFont;
  try {
    final fontData = await rootBundle.load("assets/fonts/open-sans.regular.ttf");
    fallbackFont = pw.Font.ttf(fontData.buffer.asByteData());
  } catch (e) {
    debugPrint('Could not load fallback font, using default: $e');
  }
  
  // Format current date and time
  final now = DateTime.now();
  final dateFormatter = DateFormat('dd-MM-yyyy');
  final timeFormatter = DateFormat('hh:mm a');
  final formattedDate = dateFormatter.format(now);
  final formattedTime = timeFormatter.format(now);
  
  // Generate order number
  final billNumber = orderNumber ?? '${now.millisecondsSinceEpoch % 10000}';
  
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  _createText(
                    'RECEIPT',
                    arabicFont: arabicFont,
                    style: pw.TextStyle(
                      font: fallbackFont,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  _createText(
                    businessInfo['name']!,
                    arabicFont: arabicFont,
                    style: pw.TextStyle(
                      font: _containsArabic(businessInfo['name']!) ? arabicFont : fallbackFont,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  if (businessInfo['second_name']!.isNotEmpty)
                    _createText(
                      businessInfo['second_name']!,
                      arabicFont: arabicFont,
                      style: pw.TextStyle(
                        font: _containsArabic(businessInfo['second_name']!) ? arabicFont : fallbackFont,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                pw.SizedBox(height: 5),
                _createText(
                  businessInfo['address']!,
                  arabicFont: arabicFont,
                  style: pw.TextStyle(
                    font: _containsArabic(businessInfo['address']!) ? arabicFont : fallbackFont,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                _createText(
                  businessInfo['phone']!,
                  arabicFont: arabicFont,
                  style: pw.TextStyle(
                    font: fallbackFont,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 3),
                
                // Add EDITED marker if order was edited
                if (isEdited)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: _createText(
                      'EDITED',
                      arabicFont: arabicFont,
                      style: pw.TextStyle(
                        font: fallbackFont,
                        fontSize: 5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                
                pw.SizedBox(height: 3),
                
                _createText(
                  'ORDER #$billNumber',
                  arabicFont: arabicFont,
                  style: pw.TextStyle(
                    font: fallbackFont,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                _createText(
                  '$formattedDate at $formattedTime',
                  arabicFont: arabicFont,
                  style: pw.TextStyle(
                    font: fallbackFont,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                _createText(
                  'Service: $serviceType',
                  arabicFont: arabicFont,
                  style: pw.TextStyle(
                    font: _containsArabic(serviceType) ? arabicFont : fallbackFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                if (personName != null)
                  _createText(
                    'Customer: $personName',
                    arabicFont: arabicFont,
                    style: pw.TextStyle(
                      font: _containsArabic(personName) ? arabicFont : fallbackFont,
                      fontSize: 10,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1),
          
          // Item header - only in English (since PDF is for customers)
          pw.Row(
            children: [
              pw.Expanded(
                flex: 5,
                child: _createText(
                  'Item',
                  arabicFont: arabicFont,
                  style: pw.TextStyle(
                    font: fallbackFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: _createText(
                  'Qty',
                  arabicFont: arabicFont,
                  style: pw.TextStyle(
                    font: fallbackFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: _createText(
                  'Price',
                  arabicFont: arabicFont,
                  style: pw.TextStyle(
                    font: fallbackFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: _createText(
                  'Total',
                  arabicFont: arabicFont,
                  style: pw.TextStyle(
                    font: fallbackFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
          
          pw.Divider(thickness: 1),
          
          // Items - each item displays in its original language
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
                          child: _createText(
                            item.name,
                            arabicFont: arabicFont,
                            style: pw.TextStyle(
                              font: _containsArabic(item.name) ? arabicFont : fallbackFont,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: _createText(
                            '${item.quantity}',
                            arabicFont: arabicFont,
                            style: pw.TextStyle(
                              font: fallbackFont,
                              fontSize: 10,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: _createText(
                            item.price.toStringAsFixed(3),
                            arabicFont: arabicFont,
                            style: pw.TextStyle(
                              font: fallbackFont,
                              fontSize: 10,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: _createText(
                            (item.price * item.quantity).toStringAsFixed(3),
                            arabicFont: arabicFont,
                            style: pw.TextStyle(
                              font: fallbackFont,
                              fontSize: 10,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Add kitchen note if it exists - display in its original language
                  if (item.kitchenNote.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 10, bottom: 5),
                      child: pw.Row(
                        children: [
                          _createText(
                            'Note: ',
                            arabicFont: arabicFont,
                            style: pw.TextStyle(
                              font: fallbackFont,
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.Expanded(
                            child: _createText(
                              item.kitchenNote,
                              arabicFont: arabicFont,
                              style: pw.TextStyle(
                                font: _containsArabic(item.kitchenNote) ? arabicFont : fallbackFont,
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
          
          // Totals - only in English
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 6,
                  child: _createText(
                    'Subtotal:',
                    arabicFont: arabicFont,
                    style: pw.TextStyle(
                      font: fallbackFont,
                      fontSize: 10,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 4,
                  child: _createText(
                    subtotal.toStringAsFixed(3),
                    arabicFont: arabicFont,
                    style: pw.TextStyle(
                      font: fallbackFont,
                      fontSize: 10,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
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
                  child: _createText(
                    'Tax (${effectiveTaxRate.toStringAsFixed(1)}%):',
                    arabicFont: arabicFont,
                    style: pw.TextStyle(
                      font: fallbackFont,
                      fontSize: 10,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 4,
                  child: _createText(
                    tax.toStringAsFixed(3),
                    arabicFont: arabicFont,
                    style: pw.TextStyle(
                      font: fallbackFont,
                      fontSize: 10,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
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
                    child: _createText(
                      'Discount:',
                      arabicFont: arabicFont,
                      style: pw.TextStyle(
                        font: fallbackFont,
                        fontSize: 10,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 4,
                    child: _createText(
                      discount.toStringAsFixed(3),
                      arabicFont: arabicFont,
                      style: pw.TextStyle(
                        font: fallbackFont,
                        fontSize: 10,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
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
                  child: _createText(
                    'TOTAL:',
                    arabicFont: arabicFont,
                    style: pw.TextStyle(
                      font: fallbackFont,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 4,
                  child: _createText(
                    total.toStringAsFixed(3),
                    arabicFont: arabicFont,
                    style: pw.TextStyle(
                      font: fallbackFont,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          
          pw.Divider(thickness: 1),
          
          // Footer - only in English
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Column(
              children: [
                _createText(
                  'Thank you for your visit!',
                  arabicFont: arabicFont,
                  style: pw.TextStyle(
                    font: fallbackFont,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                _createText(
                  'Please come again',
                  arabicFont: arabicFont,
                  style: pw.TextStyle(
                    font: fallbackFont,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
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
    
      
      // Use the direct printer service to print the receipt to RECEIPT printer
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

  // Print KOT (Kitchen Order Ticket) - NEW METHOD
  static Future<bool> printKotOrder(OrderHistory order) async {
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
      
      // Use the KOT printer service to print to KOT printer
      final printed = await ThermalPrinterService.printKotReceipt(
        items: items,
        serviceType: order.serviceType,
        tableInfo: tableInfo,
        orderNumber: order.orderNumber,
      );
      
      return printed;
    } catch (e) {
      debugPrint('Error printing KOT order: $e');
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
      
      // Use direct ESC/POS commands for printing to RECEIPT printer
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

  // Print KOT to KOT printer - NEW METHOD
  static Future<bool> printKot({
    required List<MenuItem> items,
    required String serviceType,
    String? tableInfo,
    String? orderNumber,
  }) async {
    try {
      // Use direct ESC/POS commands for printing to KOT printer
      final printed = await ThermalPrinterService.printKotReceipt(
        items: items,
        serviceType: serviceType,
        tableInfo: tableInfo,
        orderNumber: orderNumber,
      );
      
      return printed;
    } catch (e) {
      debugPrint('Error printing KOT: $e');
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
          title:  Text('Printer Not Available'.tr()),
          content:  Text('Could not connect to the thermal printer. Would you like to save the bill as a PDF?'.tr()),
          actions: <Widget>[
            TextButton(
              child:  Text('Cancel'.tr()),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child:  Text('Save PDF'.tr()),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  // Check if printer is enabled in settings
static Future<bool> isPrinterEnabled() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('printer_enabled') ?? true;
  } catch (e) {
    debugPrint('Error checking printer status: $e');
    return true; // Default to enabled if error
  }
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
    // Check if printer is enabled before attempting to print
    final printerEnabled = await isPrinterEnabled();

    if (!printerEnabled) {
    // Printer is disabled, skip printing and go straight to PDF option
    if (!context.mounted) {
      return {
        'success': false,
        'message': 'Context no longer valid',
        'printed': false,
        'saved': false,
        'filePath': null,
      };
    }
    // Show dialog to ask if user wants to save PDF since printer is disabled
    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Printer Disabled'.tr()),
          content: Text('Printer connection is disabled. Would you like to save the bill as a PDF?'.tr()),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'.tr()),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: Text('Save PDF'.tr()),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );
    
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
      return {
        'success': true,
        'message': 'Order processed, but bill was not printed or saved'.tr(),
        'printed': false,
        'saved': false,
        'filePath': null,
      };
    }
     // Generate and save PDF
    final pdf = await generateBill(
      items: items,
      serviceType: serviceType,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      total: total,
      personName: personName,
      tableInfo: tableInfo,
      isEdited: isEdited,
      taxRate: effectiveTaxRate,
    );
    
    final saved = await saveWithAndroidIntent(pdf);
    
    if (saved) {
      return {
        'success': true,
        'message': 'Order processed and bill saved as PDF'.tr(),
        'printed': false,
        'saved': true,
        'filePath': null,
      };
    }
    
    return {
      'success': false,
      'message': 'Failed to save the bill'.tr(),
      'printed': false,
      'saved': false,
      'filePath': null,
    };
  }
    
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
        'message': 'Order processed and bill printed successfully'.tr(),
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
        'message': 'Order processed, but bill was not printed or saved'.tr(),
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
        'message': 'Order processed and bill saved as PDF'.tr(),
        'printed': false,
        'saved': true,
        'filePath': null,
      };
    }
    
    // If we get here, saving failed
    return {
      'success': false,
      'message': 'Failed to save the bill'.tr(),
      'printed': false,
      'saved': false,
      'filePath': null,
    };
  }
  
  // Replace the generateKitchenBill method in BillService class
static Future<pw.Document> generateKitchenBill({
  required List<MenuItem> items,
  required String serviceType,
  String? tableInfo,
  String? orderNumber,
}) async {
  final pdf = pw.Document();
  
  // Load Arabic-compatible font
  final arabicFont = await _loadArabicFont();
  
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
            // Header - only in English
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
                  _createText(
                    'Service: $serviceType',
                    arabicFont: arabicFont,
                    style: pw.TextStyle(
                      font: _containsArabic(serviceType) ? arabicFont : ttf,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 10),
            
            // Divider
            pw.Divider(thickness: 1),
            
            // Item header - simplified for kitchen, only in English
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
            
           // Items - each item displays in its original language
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
                            child: _createText(
                              item.name,
                              arabicFont: arabicFont,
                              style: pw.TextStyle(
                                font: _containsArabic(item.name) ? arabicFont : ttf,
                                fontSize: 12,
                              ),
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
                    
                    // Add kitchen note if present - display in its original language
                    if (item.kitchenNote.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 10, bottom: 5),
                        child: pw.Row(
                          children: [
                            pw.Text(
                              'NOTE: ',
                              style: pw.TextStyle(
                                font: ttf,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Expanded(
                              child: _createText(
                                item.kitchenNote,
                                arabicFont: arabicFont,
                                style: pw.TextStyle(
                                  font: _containsArabic(item.kitchenNote) ? arabicFont : ttf,
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Add a small space between items
                    pw.SizedBox(height: 2),
                  ],
                );
              }).toList(),
            ),
            
            pw.Divider(thickness: 1),
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
      // Check if KOT printer is enabled
      final kotEnabled = await ThermalPrinterService.isKotPrinterEnabled();
      
      if (!kotEnabled) {
        // KOT printer is disabled, skip to PDF option or just skip entirely
        if (context != null && context.mounted) {
          final shouldSave = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('KOT Printer Disabled'.tr()),
                content: Text('KOT printer is disabled. Would you like to save kitchen receipt as PDF?'.tr()),
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
          ) ?? false;
          
          if (shouldSave) {
            final pdf = await generateKitchenBill(
              items: items,
              serviceType: serviceType,
              tableInfo: tableInfo,
              orderNumber: orderNumber,
            );
            
            final saved = await saveWithAndroidIntent(pdf);
            
            if (saved) {
              return {
                'success': true,
                'message': 'Kitchen receipt saved as PDF'.tr(),
                'printed': false,
                'saved': true,
              };
            }
          }
        }
        
        return {
          'success': true,
          'message': 'Kitchen receipt skipped (KOT printer disabled)'.tr(),
          'printed': false,
          'saved': false,
        };
      }
      
      // Try direct ESC/POS commands for printing a kitchen-focused receipt to KOT printer
      final printed = await ThermalPrinterService.printKotReceipt(
        items: items,
        serviceType: serviceType,
        tableInfo: tableInfo,
        orderNumber: orderNumber,
      );
      
      if (printed) {
        return {
          'success': true,
          'message': 'Kitchen receipt printed successfully to KOT printer',
          'printed': true,
          'saved': false,
        };
      }
      
      // Generate the PDF if printing failed
      final pdf = await generateKitchenBill(
        items: items,
        serviceType: serviceType,
        tableInfo: tableInfo,
        orderNumber: orderNumber,
      );

      if (context != null && context.mounted) {
        // Show dialog to ask if user wants to save PDF
        final shouldSave = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title:  Text('KOT Printer Not Available'.tr()),
              content:  Text('Could not print kitchen receipt to KOT printer. Would you like to save it as a PDF?'.tr()),
              actions: <Widget>[
                TextButton(
                  child:  Text('Cancel'.tr()),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child:  Text('Save PDF'.tr()),
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
            'message': 'Kitchen receipt saved as PDF'.tr(),
            'printed': false,
            'saved': true,
          };
        }
      }
    }
    
    // If we get here, printing and saving both failed or were declined
    return {
      'success': false,
      'message': 'Failed to print or save kitchen receipt'.tr(),
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