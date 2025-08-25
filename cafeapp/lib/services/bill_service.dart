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

  // Load Arabic-compatible font with multiple fallbacks
  static Future<pw.Font?> _loadArabicFont() async {
    final List<String> arabicFonts = [
      "assets/fonts/cairo-regular.ttf",
      "assets/fonts/noto-sans-arabic.ttf", 
      "assets/fonts/amiri-regular.ttf",
      "assets/fonts/tajawal-regular.ttf",
      "assets/fonts/scheherazade-regular.ttf"
    ];
    
    for (String fontPath in arabicFonts) {
      try {
        final fontData = await rootBundle.load(fontPath);
        debugPrint('Successfully loaded Arabic font: $fontPath');
        return pw.Font.ttf(fontData.buffer.asByteData());
      } catch (e) {
        debugPrint('Failed to load font $fontPath: $e');
        continue;
      }
    }
    
    debugPrint('Could not load any Arabic font, will use default');
    return null;
  }

  // Load fallback font for English text
  static Future<pw.Font?> _loadFallbackFont() async {
    final List<String> fallbackFonts = [
      "assets/fonts/open-sans-regular.ttf",
      "assets/fonts/roboto-regular.ttf",
      "assets/fonts/ubuntu-regular.ttf"
    ];
    
    for (String fontPath in fallbackFonts) {
      try {
        final fontData = await rootBundle.load(fontPath);
        debugPrint('Successfully loaded fallback font: $fontPath');
        return pw.Font.ttf(fontData.buffer.asByteData());
      } catch (e) {
        debugPrint('Failed to load font $fontPath: $e');
        continue;
      }
    }
    
    debugPrint('Could not load any fallback font, will use default');
    return null;
  }

  // Check if text contains Arabic characters
  static bool _containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  // Get appropriate text direction for Arabic text
  static pw.TextDirection _getTextDirection(String text) {
    return _containsArabic(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  }

  // Create text widget with proper direction and font for PDF
  static pw.Widget _createText(
    String text, {
    pw.Font? arabicFont,
    pw.Font? fallbackFont,
    pw.TextStyle? style,
    pw.TextAlign? textAlign,
  }) {
    final textDirection = _getTextDirection(text);
    final useArabicFont = _containsArabic(text) && arabicFont != null;
    
    // Choose the appropriate font
    pw.Font? selectedFont;
    if (useArabicFont) {
      selectedFont = arabicFont;
    } else if (fallbackFont != null) {
      selectedFont = fallbackFont;
    } else if (style?.font != null) {
      selectedFont = style!.font;
    }
    
    return pw.Directionality(
      textDirection: textDirection,
      child: pw.Text(
        text,
        style: style?.copyWith(font: selectedFont) ?? pw.TextStyle(font: selectedFont),
        textAlign: textAlign,
        textDirection: textDirection,
      ),
    );
  }

  // Enhanced bill generation with better Arabic support
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
    
    final effectiveTaxRate = taxRate ?? 0.0;
    
    // Load fonts
    final arabicFont = await _loadArabicFont();
    final fallbackFont = await _loadFallbackFont();
    
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
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 3),
                    _createText(
                      businessInfo['name']!,
                      arabicFont: arabicFont,
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(
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
                        fallbackFont: fallbackFont,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    pw.SizedBox(height: 5),
                    if (businessInfo['address']!.isNotEmpty)
                      _createText(
                        businessInfo['address']!,
                        arabicFont: arabicFont,
                        fallbackFont: fallbackFont,
                        style: pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                    if (businessInfo['phone']!.isNotEmpty)
                      _createText(
                        businessInfo['phone']!,
                        arabicFont: arabicFont,
                        fallbackFont: fallbackFont,
                        style: pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                    pw.SizedBox(height: 3),
                    
                    // Add EDITED marker if order was edited
                    if (isEdited)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.red),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: _createText(
                          'EDITED',
                          arabicFont: arabicFont,
                          fallbackFont: fallbackFont,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    
                    pw.SizedBox(height: 3),
                    
                    _createText(
                      'ORDER #$billNumber',
                      arabicFont: arabicFont,
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(
                        fontSize: 10,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    _createText(
                      '$formattedDate at $formattedTime',
                      arabicFont: arabicFont,
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    _createText(
                      'Service: $serviceType',
                      arabicFont: arabicFont,
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (personName != null && personName.isNotEmpty)
                      _createText(
                        'Customer: $personName',
                        arabicFont: arabicFont,
                        fallbackFont: fallbackFont,
                        style: pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1),
              
              // Item header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: _createText(
                      'Item',
                      arabicFont: arabicFont,
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(
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
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(
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
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(
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
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(
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
                                fallbackFont: fallbackFont,
                                style: pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Expanded(
                              flex: 1,
                              child: _createText(
                                '${item.quantity}',
                                arabicFont: arabicFont,
                                fallbackFont: fallbackFont,
                                style: pw.TextStyle(fontSize: 10),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: _createText(
                                item.price.toStringAsFixed(3),
                                arabicFont: arabicFont,
                                fallbackFont: fallbackFont,
                                style: pw.TextStyle(fontSize: 10),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: _createText(
                                (item.price * item.quantity).toStringAsFixed(3),
                                arabicFont: arabicFont,
                                fallbackFont: fallbackFont,
                                style: pw.TextStyle(fontSize: 10),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Add kitchen note if it exists - display in its original language
                      // if (item.kitchenNote.isNotEmpty)
                      //   pw.Padding(
                      //     padding: const pw.EdgeInsets.only(left: 10, bottom: 5),
                      //     child: pw.Row(
                      //       children: [
                      //         _createText(
                      //           'Note: ',
                      //           arabicFont: arabicFont,
                      //           fallbackFont: fallbackFont,
                      //           style: pw.TextStyle(
                      //             fontSize: 8,
                      //             fontWeight: pw.FontWeight.bold,
                      //             color: PdfColors.blue900,
                      //           ),
                      //         ),
                      //         pw.Expanded(
                      //           child: _createText(
                      //             item.kitchenNote,
                      //             arabicFont: arabicFont,
                      //             fallbackFont: fallbackFont,
                      //             style: pw.TextStyle(
                      //               fontSize: 8,
                      //               fontStyle: pw.FontStyle.italic,
                      //               color: PdfColors.blue900,
                      //             ),
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
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
                      child: _createText(
                        'Subtotal:',
                        arabicFont: arabicFont,
                        fallbackFont: fallbackFont,
                        style: pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Expanded(
                      flex: 4,
                      child: _createText(
                        subtotal.toStringAsFixed(3),
                        arabicFont: arabicFont,
                        fallbackFont: fallbackFont,
                        style: pw.TextStyle(fontSize: 10),
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
                        fallbackFont: fallbackFont,
                        style: pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Expanded(
                      flex: 4,
                      child: _createText(
                        tax.toStringAsFixed(3),
                        arabicFont: arabicFont,
                        fallbackFont: fallbackFont,
                        style: pw.TextStyle(fontSize: 10),
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
                          fallbackFont: fallbackFont,
                          style: pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Expanded(
                        flex: 4,
                        child: _createText(
                          discount.toStringAsFixed(3),
                          arabicFont: arabicFont,
                          fallbackFont: fallbackFont,
                          style: pw.TextStyle(fontSize: 10),
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
                        fallbackFont: fallbackFont,
                        style: pw.TextStyle(
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
                        fallbackFont: fallbackFont,
                        style: pw.TextStyle(
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
              
              // Footer
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Column(
                  children: [
                    _createText(
                      'Thank you for your visit!',
                      arabicFont: arabicFont,
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    _createText(
                      'Please come again',
                      arabicFont: arabicFont,
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                    
                    // Add Arabic footer if there's Arabic content
                    if (_containsArabic(businessInfo['name']!) || 
                        _containsArabic(businessInfo['second_name']!) ||
                        _containsArabic(serviceType) ||
                        (personName != null && _containsArabic(personName)) ||
                        items.any((item) => _containsArabic(item.name) || _containsArabic(item.kitchenNote))) ...[
                      pw.SizedBox(height: 5),
                      _createText(
                        'شكراً لزيارتكم!',
                        arabicFont: arabicFont,
                        fallbackFont: fallbackFont,
                        style: pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 2),
                      _createText(
                        'نتطلع لزيارتكم مرة أخرى',
                        arabicFont: arabicFont,
                        fallbackFont: fallbackFont,
                        style: pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
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

  // Enhanced kitchen bill generation with Arabic support
  static Future<pw.Document> generateKitchenBill({
    required List<MenuItem> items,
    required String serviceType,
    String? tableInfo,
    String? orderNumber,
  }) async {
    final pdf = pw.Document();
    
    // Load fonts
    final arabicFont = await _loadArabicFont();
    final fallbackFont = await _loadFallbackFont();
    
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
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    _createText(
                      'KITCHEN ORDER',
                      arabicFont: arabicFont,
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(
                        fontSize: 16,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 5),
                    
                    _createText(
                      'ORDER #$billNumber',
                      arabicFont: arabicFont,
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(
                        fontSize: 14,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 3),
                    _createText(
                      '$formattedDate at $formattedTime',
                      arabicFont: arabicFont,
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 3),
                    _createText(
                      'Service: $serviceType',
                      arabicFont: arabicFont,
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(
                        fontSize: 12,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1),
              
              // Item header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: _createText(
                      'Item',
                      arabicFont: arabicFont,
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: _createText(
                      'Qty',
                      arabicFont: arabicFont,
                      fallbackFont: fallbackFont,
                      style: pw.TextStyle(
                        fontSize: 12,
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
                        padding: const pw.EdgeInsets.only(top: 5, bottom: 2),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              flex: 6,
                              child: _createText(
                                item.name,
                                arabicFont: arabicFont,
                                fallbackFont: fallbackFont,
                                style: pw.TextStyle(fontSize: 12),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: _createText(
                                '${item.quantity}',
                                arabicFont: arabicFont,
                                fallbackFont: fallbackFont,
                                style: pw.TextStyle(fontSize: 12),
                                textAlign: pw.TextAlign.right,
                              ),
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
                              _createText(
                                'NOTE: ',
                                arabicFont: arabicFont,
                                fallbackFont: fallbackFont,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                ),
                              ),
                              pw.Expanded(
                                child: _createText(
                                  item.kitchenNote,
                                  arabicFont: arabicFont,
                                  fallbackFont: fallbackFont,
                                  style: pw.TextStyle(
                                    fontSize: 10,
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
              
              // Add Arabic header if any item contains Arabic
              // if (_containsArabic(serviceType) || 
              //     items.any((item) => _containsArabic(item.name) || _containsArabic(item.kitchenNote)))
              //   pw.Center(
              //     child: pw.Column(
              //       children: [
              //         pw.SizedBox(height: 10),
              //         _createText(
              //           'طلب المطبخ',
              //           arabicFont: arabicFont,
              //           fallbackFont: fallbackFont,
              //           style: pw.TextStyle(
              //             fontSize: 14,
              //             fontWeight: pw.FontWeight.bold,
              //           ),
              //           textAlign: pw.TextAlign.center,
              //         ),
              //       ],
              //     ),
              //  ),
            ],
          );
        },
      ),
    );
    
    return pdf;
  }

  // Direct thermal printing of a bill with enhanced Arabic support
  static Future<bool> printThermalBill(OrderHistory order, {bool isEdited = false, double? taxRate, double discount = 0.0}) async {
    try {
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
      
      // Use the enhanced thermal printer service
      final printed = await ThermalPrinterService.printOrderReceipt(
        items: items,
        serviceType: order.serviceType,
        subtotal: order.total - (order.total * (effectiveTaxRate / 100)),
        tax: order.total * (effectiveTaxRate / 100),
        discount: discount,
        total: adjustedTotal,
        personName: null,
        tableInfo: tableInfo,
        isEdited: isEdited,
        orderNumber: order.orderNumber,
        taxRate: effectiveTaxRate,
      );
      
      return printed;
    } catch (e) {
      debugPrint('Error printing thermal bill: $e');
      return false;
    }
  }

  // Print KOT (Kitchen Order Ticket) with enhanced Arabic support
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
      
      // Use the enhanced KOT printer service
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

  // Print the bill directly to thermal printer with enhanced Arabic support
  static Future<bool> printBill({
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
    try {
      final effectiveTaxRate = taxRate ?? 0.0;
      
      // Use enhanced thermal printer service
      final printed = await ThermalPrinterService.printOrderReceipt(
        items: items,
        serviceType: serviceType,
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        total: total,
        personName: personName,
        tableInfo: tableInfo,
        isEdited: isEdited,
        orderNumber: orderNumber,
        taxRate: effectiveTaxRate,
      );
      
      return printed;
    } catch (e) {
      debugPrint('Error printing bill: $e');
      return false;
    }
  }

  // Print KOT to KOT printer with enhanced Arabic support
  static Future<bool> printKot({
    required List<MenuItem> items,
    required String serviceType,
    String? tableInfo,
    String? orderNumber,
  }) async {
    try {
      // Use enhanced thermal printer service
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
      
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final tempFilename = 'temp_receipt_$timestamp.pdf';
      final tempFile = File('${tempDir.path}/$tempFilename');
      
      await tempFile.writeAsBytes(await pdf.save());
      
      const platform = MethodChannel('com.simsrestocafe/file_picker');
      
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
          title: Text('Printer Not Available'.tr()),
          content: Text('Could not connect to the thermal printer. Would you like to save the bill as a PDF?'.tr()),
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
  }

  // Check if printer is enabled in settings
  static Future<bool> isPrinterEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('printer_enabled') ?? true;
    } catch (e) {
      debugPrint('Error checking printer status: $e');
      return true;
    }
  }

  // Enhanced process order bill with Arabic support
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
    bool isEdited = false,
    double? taxRate,
  }) async {
    final effectiveTaxRate = taxRate ?? 0.0;
    final printerEnabled = await isPrinterEnabled();

    if (!printerEnabled) {
      if (!context.mounted) {
        return {
          'success': false,
          'message': 'Context no longer valid',
          'printed': false,
          'saved': false,
          'filePath': null,
        };
      }
      
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
    
    // Try to print using enhanced Arabic support
    final printed = await printBill(
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
    
    if (printed) {
      return {
        'success': true,
        'message': 'Order processed and bill printed successfully'.tr(),
        'printed': true,
        'saved': false,
        'filePath': null,
      };
    }
    
    if (!context.mounted) {
      return {
        'success': false,
        'message': 'Context no longer valid',
        'printed': false,
        'saved': false,
        'filePath': null,
      };
    }
    
    final shouldSave = await showSavePdfDialog(context);
    
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
  
  // Enhanced kitchen order receipt with Arabic support
  static Future<Map<String, dynamic>> printKitchenOrderReceipt({
    required List<MenuItem> items,
    required String serviceType,
    String? tableInfo,
    String? orderNumber,
    BuildContext? context,
  }) async {
    try {
      final kotEnabled = await ThermalPrinterService.isKotPrinterEnabled();
      
      if (!kotEnabled) {
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
      
      // Try printing with enhanced Arabic support
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
      
      final pdf = await generateKitchenBill(
        items: items,
        serviceType: serviceType,
        tableInfo: tableInfo,
        orderNumber: orderNumber,
      );

      if (context != null && context.mounted) {
        final shouldSave = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('KOT Printer Not Available'.tr()),
              content: Text('Could not print kitchen receipt to KOT printer. Would you like to save it as a PDF?'.tr()),
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