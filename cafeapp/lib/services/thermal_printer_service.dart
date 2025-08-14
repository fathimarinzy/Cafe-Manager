import 'package:flutter/material.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';

class ThermalPrinterService {
  // Receipt Printer settings
  static const String _defaultReceiptPrinterIp = '192.168.1.100';
  static const int _defaultReceiptPrinterPort = 9100;
  static const String _receiptPrinterIpKey = 'receipt_printer_ip';
  static const String _receiptPrinterPortKey = 'receipt_printer_port';
  
  // KOT Printer settings
  static const String _defaultKotPrinterIp = '192.168.1.101';
  static const int _defaultKotPrinterPort = 9100;
  static const String _kotPrinterIpKey = 'kot_printer_ip';
  static const String _kotPrinterPortKey = 'kot_printer_port';
  static const String _kotPrinterEnabledKey = 'kot_printer_enabled';

  // Receipt Printer methods
  static Future<String> getPrinterIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_receiptPrinterIpKey) ?? _defaultReceiptPrinterIp;
  }

  static Future<int> getPrinterPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_receiptPrinterPortKey) ?? _defaultReceiptPrinterPort;
  }

  static Future<void> savePrinterIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_receiptPrinterIpKey, ip);
  }

  static Future<void> savePrinterPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_receiptPrinterPortKey, port);
  }

  // KOT Printer methods
  static Future<String> getKotPrinterIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kotPrinterIpKey) ?? _defaultKotPrinterIp;
  }

  static Future<int> getKotPrinterPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kotPrinterPortKey) ?? _defaultKotPrinterPort;
  }

  static Future<void> saveKotPrinterIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kotPrinterIpKey, ip);
  }

  static Future<void> saveKotPrinterPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kotPrinterPortKey, port);
  }

  static Future<bool> isKotPrinterEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kotPrinterEnabledKey) ?? true;
  }

  static Future<void> setKotPrinterEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kotPrinterEnabledKey, enabled);
  }

  // Check if text contains Arabic characters
  static bool _containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  // Check if ANY of the business info or content contains Arabic
  static bool _hasArabicContent(Map<String, String> businessInfo, List<MenuItem> items, String serviceType, String? personName) {
    // Check business info
    if (_containsArabic(businessInfo['name'] ?? '') ||
        _containsArabic(businessInfo['second_name'] ?? '') ||
        _containsArabic(businessInfo['address'] ?? '')) {
      return true;
    }

    // Check service type
    if (_containsArabic(serviceType)) {
      return true;
    }

    // Check person name
    if (personName != null && _containsArabic(personName)) {
      return true;
    }

    // Check items
    for (var item in items) {
      if (_containsArabic(item.name) || _containsArabic(item.kitchenNote)) {
        return true;
      }
    }

    return false;
  }

  // Get appropriate codepage based on content
  static String _getCodePage(bool hasArabic) {
    return hasArabic ? 'CP1256' : 'CP437'; // CP1256 for Arabic, CP437 for English
  }

  // Get appropriate text alignment for text
  static PosAlign _getTextAlign(String text, PosAlign defaultAlign) {
    if (_containsArabic(text)) {
      // Arabic text should be right-aligned or center
      if (defaultAlign == PosAlign.left) return PosAlign.right;
      if (defaultAlign == PosAlign.right) return PosAlign.right;
      return defaultAlign; // keep center as center
    }
    return defaultAlign; // Keep original alignment for English
  }

  // Process text for printing (handle encoding issues)
  static String _processTextForPrinting(String text, bool useArabicMode) {
    if (!_containsArabic(text) || !useArabicMode) {
      // English text or Arabic mode disabled - return as is
      return text;
    }

    try {
      // For Arabic text, try to ensure proper encoding
      return text; // Most modern printers can handle UTF-8 with proper codepage
    } catch (e) {
      debugPrint('Error processing Arabic text: $e');
      return text; // Return original if processing fails
    }
  }

  // Test receipt printer connection
  static Future<bool> testConnection() async {
    final ip = await getPrinterIp();
    final port = await getPrinterPort();
    
    try {
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      
      debugPrint('Testing receipt printer connection at $ip:$port');
      final PosPrintResult result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 3));
      
      if (result == PosPrintResult.success) {
        printer.text('Receipt printer test successful', styles: const PosStyles(align: PosAlign.center, bold: true));
        printer.cut();
        printer.disconnect();
        return true;
      } else {
        debugPrint('Failed to connect to receipt printer: ${result.msg}');
        return false;
      }
    } catch (e) {
      debugPrint('Error connecting to receipt printer: $e');
      return false;
    }
  }

  // Test KOT printer connection
  static Future<bool> testKotConnection() async {
    final ip = await getKotPrinterIp();
    final port = await getKotPrinterPort();
    
    try {
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      
      debugPrint('Testing KOT printer connection at $ip:$port');
      final PosPrintResult result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 3));
      
      if (result == PosPrintResult.success) {
        printer.text('KOT printer test successful', styles: const PosStyles(align: PosAlign.center, bold: true));
        printer.cut();
        printer.disconnect();
        return true;
      } else {
        debugPrint('Failed to connect to KOT printer: ${result.msg}');
        return false;
      }
    } catch (e) {
      debugPrint('Error connecting to KOT printer: $e');
      return false;
    }
  }

  // Get business information
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

  // Print kitchen ticket to KOT printer
  // static Future<bool> printKitchenTicket(MenuItem item) async {
  //   final kotEnabled = await isKotPrinterEnabled();
  //   if (!kotEnabled) {
  //     debugPrint('KOT printer is disabled');
  //     return true; // Return true to not block the process
  //   }

  //   final ip = await getKotPrinterIp();
  //   final port = await getKotPrinterPort();
    
  //   try {
  //     final profile = await CapabilityProfile.load();
  //     final printer = NetworkPrinter(PaperSize.mm80, profile);
      
  //     debugPrint('Connecting to KOT printer at $ip:$port for kitchen ticket');
  //     final PosPrintResult result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 5));
      
  //     if (result != PosPrintResult.success) {
  //       debugPrint('Failed to connect to KOT printer: ${result.msg}');
  //       return false;
  //     }
      
  //     // Check if Arabic content exists
  //     final hasArabic = _containsArabic(item.name) || _containsArabic(item.kitchenNote);
      
  //     // Set appropriate codepage
  //     if (hasArabic) {
  //       try {
  //         printer.setGlobalCodeTable(_getCodePage(hasArabic));
  //       } catch (e) {
  //         debugPrint('Could not set Arabic codepage: $e');
  //       }
  //     }
      
  //     // Print kitchen ticket header
  //     printer.text('KITCHEN ORDER', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
  //     printer.text(DateTime.now().toString().substring(0, 19), styles: const PosStyles(align: PosAlign.center));
  //     printer.hr();
      
  //     // Item details
  //     final processedName = _processTextForPrinting(item.name, hasArabic);
  //     printer.text(processedName, styles: PosStyles(
  //       align: _getTextAlign(item.name, PosAlign.center), 
  //       bold: true, 
  //       height: PosTextSize.size2
  //     ));
      
  //     // Quantity
  //     printer.text('QTY: ${item.quantity}', styles: const PosStyles(align: PosAlign.center, bold: true));
      
  //     // Kitchen note
  //     if (item.kitchenNote.isNotEmpty) {
  //       printer.text('', styles: const PosStyles(align: PosAlign.center));
  //       printer.text('SPECIAL INSTRUCTIONS:', styles: const PosStyles(align: PosAlign.left, bold: true));
        
  //       final processedNote = _processTextForPrinting(item.kitchenNote, hasArabic);
  //       printer.text(processedNote, styles: PosStyles(
  //         align: _getTextAlign(item.kitchenNote, PosAlign.left), 
  //         bold: true, 
  //         underline: true
  //       ));
  //     }
      
  //     printer.text('', styles: const PosStyles(align: PosAlign.center));
  //     printer.text('--------------------------------', styles: const PosStyles(align: PosAlign.center));
      
  //     printer.cut();
  //     printer.disconnect();
      
  //     return true;
  //   } catch (e) {
  //     debugPrint('Error printing kitchen ticket to KOT printer: $e');
  //     return false;
  //   }
  // }

  // Print order receipt to receipt printer (existing functionality)
  static Future<bool> printOrderReceipt({
    required String serviceType,
    required List<MenuItem> items,
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
    final effectiveTaxRate = taxRate ?? 0.0;
    final ip = await getPrinterIp();
    final port = await getPrinterPort();
    final businessInfo = await getBusinessInfo();
    
    try {
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      
      debugPrint('Connecting to receipt printer at $ip:$port for receipt');
      final PosPrintResult result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 5));
      
      if (result != PosPrintResult.success) {
        debugPrint('Failed to connect to receipt printer: ${result.msg}');
        return false;
      }

      // Check if ANY content contains Arabic (for codepage setting only)
      final hasArabicContent = _hasArabicContent(businessInfo, items, serviceType, personName);
      debugPrint('Arabic content detected: $hasArabicContent');

      // Set appropriate codepage only if Arabic content exists
      if (hasArabicContent) {
        try {
          printer.setGlobalCodeTable(_getCodePage(hasArabicContent));
          debugPrint('Set Arabic codepage for mixed content');
        } catch (e) {
          debugPrint('Could not set Arabic codepage: $e');
        }
      }

      final billNumber = orderNumber ?? (DateTime.now().millisecondsSinceEpoch % 10000).toString();
      
      // Print receipt header
      printer.text('RECEIPT', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size3));
      
      // Business name with smart alignment and processing
      final processedBusinessName = _processTextForPrinting(businessInfo['name']!, hasArabicContent);
      printer.text(processedBusinessName, styles: PosStyles(
        align: _getTextAlign(businessInfo['name']!, PosAlign.center), 
        bold: true, 
        height: PosTextSize.size3
      ));
      
      // Second business name (if exists)
      if (businessInfo['second_name']!.isNotEmpty) {
        final processedSecondName = _processTextForPrinting(businessInfo['second_name']!, hasArabicContent);
        printer.text(processedSecondName, styles: PosStyles(
          align: _getTextAlign(businessInfo['second_name']!, PosAlign.center), 
          bold: true, 
          height: PosTextSize.size2
        ));
      }

      printer.text('', styles: const PosStyles(align: PosAlign.center));
      
      // Address (if exists)
      if (businessInfo['address']!.isNotEmpty) {
        final processedAddress = _processTextForPrinting(businessInfo['address']!, hasArabicContent);
        printer.text(processedAddress, styles: PosStyles(
          align: _getTextAlign(businessInfo['address']!, PosAlign.center),
          height: PosTextSize.size2
        ));
      }
      
      // Phone (if exists)
      if (businessInfo['phone']!.isNotEmpty) {
        printer.text(businessInfo['phone']!, styles: const PosStyles(align: PosAlign.center,height: PosTextSize.size2));
      }

      // EDITED indicator
      if (isEdited) {
        printer.row([
          PosColumn(text: '', width: 3),
          PosColumn(
            text: ' EDITED ',
            width: 6,
            styles: const PosStyles(
              bold: true,
              align: PosAlign.center,
              height: PosTextSize.size1,
              width: PosTextSize.size1,
            ),
          ),
          PosColumn(text: '', width: 3),
        ]);
        printer.text('', styles: const PosStyles(align: PosAlign.center));
      }
      
      // Order number
      printer.text('ORDER #$billNumber', styles: const PosStyles(align: PosAlign.center, bold: true,height: PosTextSize.size1,
        width: PosTextSize.size1));
      
      // Date and time
      final now = DateTime.now();
      final formattedDate = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      printer.text('$formattedDate at $formattedTime', styles: const PosStyles(align: PosAlign.center));
      
      // Service type
      final processedServiceType = _processTextForPrinting(serviceType, hasArabicContent);
      printer.text('Service: $processedServiceType', styles: PosStyles(
        align: _getTextAlign(serviceType, PosAlign.center), 
        bold: true,height: PosTextSize.size1,
        width: PosTextSize.size1,
      ));
      
      // Customer name (if exists)
      if (personName != null) {
        final processedPersonName = _processTextForPrinting(personName, hasArabicContent);
        printer.text('Customer: $processedPersonName', styles: PosStyles(
          align: _getTextAlign(personName, PosAlign.center)
        ));
      }
      
      // Separator
      printer.text('=' * 48, styles: const PosStyles(align: PosAlign.center));

      // Item headers
      printer.row([
        PosColumn(text: 'Item', width: 5, styles: const PosStyles(bold: true,height: PosTextSize.size2,
        )),
        PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.center,height: PosTextSize.size2,
        )),
        PosColumn(text: 'Price', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right,height: PosTextSize.size2,
        )),
        PosColumn(text: 'Total', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right,height: PosTextSize.size2,
       )),
      ]);

      printer.text('=' * 48, styles: const PosStyles(align: PosAlign.center));
      
      // Items
      for (var item in items) {
        final processedItemName = _processTextForPrinting(item.name, hasArabicContent);
        
        printer.row([
          PosColumn(text: processedItemName, width: 5, styles: PosStyles(
            align: _getTextAlign(item.name, PosAlign.left),
            height: PosTextSize.size2,
          )),
          PosColumn(text: '${item.quantity}', width: 2, styles: const PosStyles(align: PosAlign.center,height: PosTextSize.size2,
          )),
          PosColumn(text: item.price.toStringAsFixed(3), width: 2, styles: const PosStyles(align: PosAlign.right,height: PosTextSize.size2,
          )),
          PosColumn(text: (item.price * item.quantity).toStringAsFixed(3), width: 3, styles: const PosStyles(align: PosAlign.right,height: PosTextSize.size2,
          )),
        ]);

        // Kitchen note
        if (item.kitchenNote.isNotEmpty) {
          final processedNote = _processTextForPrinting(item.kitchenNote, hasArabicContent);
          printer.text('Note: $processedNote', styles: PosStyles(
            align: _getTextAlign(item.kitchenNote, PosAlign.left),
            fontType: PosFontType.fontB,height: PosTextSize.size2,
        
          ));
        }
      }
      
      printer.text('=' * 48, styles: const PosStyles(align: PosAlign.center));

      // Totals
      printer.row([
        PosColumn(text: 'Subtotal:', width: 8, styles: const PosStyles(align: PosAlign.right, height: PosTextSize.size2,)),
        PosColumn(text: subtotal.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right,height: PosTextSize.size2,
        )),
      ]);
      printer.row([
        PosColumn(text: 'Tax (${effectiveTaxRate.toStringAsFixed(1)}%):', width: 8, styles: const PosStyles(align: PosAlign.right,height: PosTextSize.size2,
        )),
        PosColumn(text: tax.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right,height: PosTextSize.size2,
       )),
      ]);
      
      if (discount > 0) {
        printer.row([
          PosColumn(text: 'Discount:', width: 8, styles: const PosStyles(align: PosAlign.right,height: PosTextSize.size2,
        )),
          PosColumn(text: discount.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right,height: PosTextSize.size2,
        )),
        ]);
      }
      
      printer.text('=' * 48, styles: const PosStyles(align: PosAlign.center));

      printer.row([
        PosColumn(text: 'TOTAL:', width: 8, styles: const PosStyles(align: PosAlign.right, bold: true,height: PosTextSize.size3,
        )),
        PosColumn(text: total.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right, bold: true,height: PosTextSize.size3,
        )),
      ]);
            
      // Footer
      printer.text('Thank you for your visit!', styles: const PosStyles(align: PosAlign.center));
      printer.text('Please come again', styles: const PosStyles(align: PosAlign.center));

      // Cut paper
      await Future.delayed(const Duration(milliseconds: 500));
      printer.cut();
      await Future.delayed(const Duration(milliseconds: 1000));
    
      printer.disconnect();
      
      return true;
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      return false;
    }
  }

  // Print KOT receipt to KOT printer
  static Future<bool> printKotReceipt({
    required String serviceType,
    required List<MenuItem> items,
    String? tableInfo,
    String? orderNumber,
  }) async {
    final kotEnabled = await isKotPrinterEnabled();
    if (!kotEnabled) {
      debugPrint('KOT printer is disabled');
      return true; // Return true to not block the process
    }

    final ip = await getKotPrinterIp();
    final port = await getKotPrinterPort();
    
    try {
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      
      debugPrint('Connecting to KOT printer at $ip:$port for KOT receipt');
      final PosPrintResult result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 10));
      
      if (result != PosPrintResult.success) {
        debugPrint('Failed to connect to KOT printer: ${result.msg}');
        return false;
      }

      // Check if Arabic content exists in items or service type
      final hasArabic = _containsArabic(serviceType) || 
                       items.any((item) => _containsArabic(item.name) || _containsArabic(item.kitchenNote));
      
      debugPrint('KOT receipt - Arabic content detected: $hasArabic');

      // Set codepage only if Arabic content exists
      if (hasArabic) {
        try {
          printer.setGlobalCodeTable(_getCodePage(hasArabic));
        } catch (e) {
          debugPrint('Could not set Arabic codepage: $e');
        }
      }
      
      final billNumber = orderNumber ?? (DateTime.now().millisecondsSinceEpoch % 10000).toString();
      
      // Print header
      printer.text('KITCHEN ORDER', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      printer.text('ORDER #$billNumber', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1,width: PosTextSize.size1));

      // Date and time
      final now = DateTime.now();
      final formattedDate = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      printer.text('$formattedDate at $formattedTime', styles: const PosStyles(align: PosAlign.center));
      
      // Service type
      final processedServiceType = _processTextForPrinting(serviceType, hasArabic);
      printer.text('Service: $processedServiceType', styles: PosStyles(
        align: _getTextAlign(serviceType, PosAlign.center), 
        bold: true,
        height: PosTextSize.size1,
      ));
      
      printer.text('=' * 48, styles: const PosStyles(align: PosAlign.center));

      // Item headers
      printer.row([
        PosColumn(text: 'Item', width: 8, styles: const PosStyles(bold: true,height: PosTextSize.size2),),
        PosColumn(text: 'Qty', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right,height: PosTextSize.size2)),
      ]);
      
      printer.text('=' * 48, styles: const PosStyles(align: PosAlign.center));
      
      // Items
      for (var item in items) {
        final processedItemName = _processTextForPrinting(item.name, hasArabic);
        
        printer.row([
          PosColumn(text: processedItemName, width: 8, styles: PosStyles(
            align: _getTextAlign(item.name, PosAlign.left),height: PosTextSize.size2
          )),
          PosColumn(text: '${item.quantity}', width: 4, styles: const PosStyles(align: PosAlign.right,height: PosTextSize.size2)),
        ]);
        
        // Kitchen note
        if (item.kitchenNote.isNotEmpty) {
          final processedNote = _processTextForPrinting(item.kitchenNote, hasArabic);
          printer.text('NOTE: $processedNote', styles: PosStyles(
            align: _getTextAlign(item.kitchenNote, PosAlign.left),
            fontType: PosFontType.fontB, 
            bold: true,
            height: PosTextSize.size2
          ));
        }
        
        printer.text('', styles: const PosStyles(align: PosAlign.center));
      }
      
      printer.text('=' * 48, styles: const PosStyles(align: PosAlign.center));
      
      await Future.delayed(const Duration(milliseconds: 500));
      printer.cut();
      await Future.delayed(const Duration(milliseconds: 1000));
      
      printer.disconnect();
      
      return true;
    } catch (e) {
      debugPrint('Error printing KOT receipt: $e');
      return false;
    }
  }

  // Alias for backward compatibility
  static Future<bool> printKitchenReceipt({
    required String serviceType,
    required List<MenuItem> items,
    String? tableInfo,
    String? orderNumber,
  }) async {
    return await printKotReceipt(
      serviceType: serviceType,
      items: items,
      tableInfo: tableInfo,
      orderNumber: orderNumber,
    );
  }
}