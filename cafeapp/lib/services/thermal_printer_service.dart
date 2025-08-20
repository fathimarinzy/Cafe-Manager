import 'package:flutter/material.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:convert';
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

  // Enhanced CP1256 conversion with better Arabic support
  static Uint8List? _convertToCP1256(String text) {
    try {
      // Complete CP1256 (Windows-1256) character mapping
      final Map<int, int> unicodeToCP1256 = {
        // Basic Latin (0x00-0x7F) - unchanged
        
        // Arabic letters
        0x0621: 0xC1, // ء Hamza
        0x0622: 0xC2, // آ Alef with Madda above
        0x0623: 0xC3, // أ Alef with Hamza above
        0x0624: 0xC4, // ؤ Waw with Hamza above
        0x0625: 0xC5, // إ Alef with Hamza below
        0x0626: 0xC6, // ئ Yeh with Hamza above
        0x0627: 0xC7, // ا Alef
        0x0628: 0xC8, // ب Beh
        0x0629: 0xC9, // ة Teh Marbuta
        0x062A: 0xCA, // ت Teh
        0x062B: 0xCB, // ث Theh
        0x062C: 0xCC, // ج Jeem
        0x062D: 0xCD, // ح Hah
        0x062E: 0xCE, // خ Khah
        0x062F: 0xCF, // د Dal
        0x0630: 0xD0, // ذ Thal
        0x0631: 0xD1, // ر Reh
        0x0632: 0xD2, // ز Zain
        0x0633: 0xD3, // س Seen
        0x0634: 0xD4, // ش Sheen
        0x0635: 0xD5, // ص Sad
        0x0636: 0xD6, // ض Dad
        0x0637: 0xD7, // ط Tah
        0x0638: 0xD8, // ظ Zah
        0x0639: 0xD9, // ع Ain
        0x063A: 0xDA, // غ Ghain
        0x0640: 0xE0, // ـ Arabic Tatweel
        0x0641: 0xE1, // ف Feh
        0x0642: 0xE2, // ق Qaf
        0x0643: 0xE3, // ك Kaf
        0x0644: 0xE4, // ل Lam
        0x0645: 0xE5, // م Meem
        0x0646: 0xE6, // ن Noon
        0x0647: 0xE7, // ه Heh
        0x0648: 0xE8, // و Waw
        0x0649: 0xE9, // ى Alef Maksura
        0x064A: 0xEA, // ي Yeh
        
        // Arabic diacritics (tashkeel)
        0x064B: 0xEB, // ً Fathatan
        0x064C: 0xEC, // ٌ Dammatan
        0x064D: 0xED, // ٍ Kasratan
        0x064E: 0xEE, // َ Fatha
        0x064F: 0xEF, // ُ Damma
        0x0650: 0xF0, // ِ Kasra
        0x0651: 0xF1, // ّ Shadda
        0x0652: 0xF2, // ْ Sukun
        
        // Arabic-Indic digits
        0x0660: 0xF0, // ٠
        0x0661: 0xF1, // ١
        0x0662: 0xF2, // ٢
        0x0663: 0xF3, // ٣
        0x0664: 0xF4, // ٤
        0x0665: 0xF5, // ٥
        0x0666: 0xF6, // ٦
        0x0667: 0xF7, // ٧
        0x0668: 0xF8, // ٨
        0x0669: 0xF9, // ٩
        
        // Additional CP1256 characters
        0x060C: 0xA1, // ، Arabic comma
        0x061B: 0xBA, // ؛ Arabic semicolon
        0x061F: 0xBF, // ؟ Arabic question mark
        0x0679: 0x8A, // ٹ Tteh
        0x067E: 0x81, // پ Peh
        0x0686: 0x8D, // چ Tcheh
        0x0688: 0x8F, // ڈ Ddal
        0x0691: 0x9A, // ڑ Rreh
        0x0698: 0x8E, // ژ Jeh
        0x06A9: 0x98, // ک Keheh
        0x06AF: 0x90, // گ Gaf
        0x06BA: 0x9F, // ں Noon Ghunna
        0x06BE: 0xAA, // ہ Heh Doachashmee
        0x06C1: 0xC0, // ہ Heh Goal
        0x06D2: 0xFF, // ے Yeh Barree
      };

      List<int> bytes = [];
      for (int codeUnit in text.runes) {
        if (unicodeToCP1256.containsKey(codeUnit)) {
          bytes.add(unicodeToCP1256[codeUnit]!);
        } else if (codeUnit <= 0x7F) {
          // ASCII characters (0-127) remain unchanged
          bytes.add(codeUnit);
        } else {
          // For unknown characters, use a space
          bytes.add(0x20); // Space
        }
      }
      
      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('Error converting to CP1256: $e');
      return null;
    }
  }

  // Setup printer for Arabic support
  static Future<bool> _setupArabicPrinter(NetworkPrinter printer) async {
    try {
      debugPrint('Setting up printer for Arabic support');
      
      // Initialize printer
      printer.rawBytes(Uint8List.fromList([0x1B, 0x40])); // ESC @ - Initialize
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Set CP1256 codepage (Arabic)
      printer.rawBytes(Uint8List.fromList([0x1B, 0x74, 32])); // ESC t 32 (CP1256)
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Set international character set to Arabic
      printer.rawBytes(Uint8List.fromList([0x1B, 0x52, 0x0D])); // ESC R 13 (Arabic)
      await Future.delayed(const Duration(milliseconds: 100));
      
      debugPrint('Arabic printer setup completed');
      return true;
    } catch (e) {
      debugPrint('Arabic printer setup failed: $e');
      return false;
    }
  }

  // Print Arabic text directly using raw bytes
  static Future<bool> _printArabicDirect(NetworkPrinter printer, String text, {PosStyles? styles}) async {
    try {
      debugPrint('Printing Arabic text directly: "$text"');
      
      // Apply text formatting
      if (styles?.bold == true) {
        printer.rawBytes(Uint8List.fromList([0x1B, 0x45, 0x01])); // Bold ON
      }
      
      // Set alignment for Arabic (right-to-left)
      if (_containsArabic(text)) {
        printer.rawBytes(Uint8List.fromList([0x1B, 0x61, 0x02])); // Right align
      } else if (styles?.align == PosAlign.center) {
        printer.rawBytes(Uint8List.fromList([0x1B, 0x61, 0x01])); // Center
      } else if (styles?.align == PosAlign.left) {
        printer.rawBytes(Uint8List.fromList([0x1B, 0x61, 0x00])); // Left
      }
      
      // Set text size
      if (styles?.height == PosTextSize.size2) {
        printer.rawBytes(Uint8List.fromList([0x1D, 0x21, 0x11])); // Double height and width
      } else if (styles?.height == PosTextSize.size3) {
        printer.rawBytes(Uint8List.fromList([0x1D, 0x21, 0x22])); // Triple height and width
      }
      
      // Convert text to CP1256 and print
      final arabicBytes = _convertToCP1256(text);
      if (arabicBytes != null) {
        printer.rawBytes(arabicBytes);
        printer.rawBytes(Uint8List.fromList([0x0A])); // Line feed
      } else {
        // Fallback to UTF-8 if conversion fails
        final utf8Bytes = utf8.encode(text);
        printer.rawBytes(Uint8List.fromList(utf8Bytes));
        printer.rawBytes(Uint8List.fromList([0x0A])); // Line feed
      }
      
      // Reset formatting
      printer.rawBytes(Uint8List.fromList([0x1D, 0x21, 0x00])); // Reset text size
      if (styles?.bold == true) {
        printer.rawBytes(Uint8List.fromList([0x1B, 0x45, 0x00])); // Bold OFF
      }
      printer.rawBytes(Uint8List.fromList([0x1B, 0x61, 0x00])); // Left align (reset)
      
      return true;
    } catch (e) {
      debugPrint('Arabic direct printing failed: $e');
      return false;
    }
  }

  // Safe text printing method that handles both Arabic and English
  static Future<bool> _safePrintText(NetworkPrinter printer, String text, {PosStyles? styles}) async {
    try {
      // Check if text contains Arabic
      if (_containsArabic(text)) {
        debugPrint('Text contains Arabic, using direct printing: "$text"');
        return await _printArabicDirect(printer, text, styles: styles);
      }
      
      // For non-Arabic text, use normal library method
      String cleanText = text.trim();
      debugPrint('Printing non-Arabic text: "$cleanText"');
      
      try {
        printer.text(cleanText, styles: styles ?? const PosStyles());
        return true;
      } catch (e) {
        debugPrint('Library text printing failed, trying raw approach: $e');
        
        // Fallback: use raw bytes even for English
        final bytes = utf8.encode(cleanText);
        
        // Apply styles if needed
        if (styles?.bold == true) {
          printer.rawBytes(Uint8List.fromList([0x1B, 0x45, 0x01])); // Bold ON
        }
        if (styles?.align == PosAlign.center) {
          printer.rawBytes(Uint8List.fromList([0x1B, 0x61, 0x01])); // Center
        } else if (styles?.align == PosAlign.right) {
          printer.rawBytes(Uint8List.fromList([0x1B, 0x61, 0x02])); // Right
        }
        
        printer.rawBytes(Uint8List.fromList(bytes));
        printer.rawBytes(Uint8List.fromList([0x0A])); // Line feed
        
        // Reset styles
        if (styles?.bold == true) {
          printer.rawBytes(Uint8List.fromList([0x1B, 0x45, 0x00])); // Bold OFF
        }
        if (styles?.align != null) {
          printer.rawBytes(Uint8List.fromList([0x1B, 0x61, 0x00])); // Left align
        }
        
        return true;
      }
    } catch (e) {
      debugPrint('All text printing methods failed: $e');
      return false;
    }
  }

  // Enhanced row printing with Arabic support
  static Future<bool> _safePrintRow(NetworkPrinter printer, List<PosColumn> columns) async {
    try {
      // Check if any column contains Arabic
      bool hasArabic = columns.any((col) => _containsArabic(col.text));
      
      if (hasArabic) {
        debugPrint('Row contains Arabic, using manual spacing');
        
        // For mixed content rows, print each column separately
        for (int i = 0; i < columns.length; i++) {
          final column = columns[i];
          
          if (_containsArabic(column.text)) {
            // Print Arabic text with proper alignment
            await _printArabicDirect(printer, column.text, styles: column.styles);
          } else {
            // Print English text normally
            await _safePrintText(printer, column.text, styles: column.styles);
          }
        }
        
        return true;
      } else {
        // No Arabic, try normal row printing first
        try {
          printer.row(columns);
          return true;
        } catch (e) {
          debugPrint('Normal row printing failed, using fallback: $e');
          
          // Fallback to printing each column separately
          for (final column in columns) {
            await _safePrintText(printer, column.text, styles: column.styles);
          }
          
          return true;
        }
      }
    } catch (e) {
      debugPrint('All row printing methods failed: $e');
      return false;
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
        await _setupArabicPrinter(printer);
        await _safePrintText(printer, 'Receipt printer test successful', styles: const PosStyles(align: PosAlign.center, bold: true));
        await _safePrintText(printer, 'اختبار الطابعة نجح', styles: const PosStyles(align: PosAlign.center, bold: true));
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
        await _setupArabicPrinter(printer);
        await _safePrintText(printer, 'KOT printer test successful', styles: const PosStyles(align: PosAlign.center, bold: true));
        await _safePrintText(printer, 'اختبار طابعة المطبخ نجح', styles: const PosStyles(align: PosAlign.center, bold: true));
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

  // Print order receipt to receipt printer with enhanced Arabic support
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

      // Setup printer for Arabic
      await _setupArabicPrinter(printer);
      
      final billNumber = orderNumber ?? (DateTime.now().millisecondsSinceEpoch % 10000).toString();
      
      // Print receipt header
      await _safePrintText(printer, 'RECEIPT', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      
      // Business name
      await _safePrintText(printer, businessInfo['name']!, styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      
      // Second business name (if exists)
      if (businessInfo['second_name']!.isNotEmpty) {
        await _safePrintText(printer, businessInfo['second_name']!, styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1));
      }

      await _safePrintText(printer, '');
      
      // Address (if exists)
      if (businessInfo['address']!.isNotEmpty) {
        await _safePrintText(printer, businessInfo['address']!, styles: const PosStyles(align: PosAlign.center));
      }
      
      // Phone (if exists)
      if (businessInfo['phone']!.isNotEmpty) {
        await _safePrintText(printer, businessInfo['phone']!, styles: const PosStyles(align: PosAlign.center));
      }

      // EDITED indicator
      if (isEdited) {
        await _safePrintText(printer, ' EDITED ', styles: const PosStyles(align: PosAlign.center, bold: true));
        await _safePrintText(printer, '');
      }
      
      // Order number
      await _safePrintText(printer, 'ORDER #$billNumber', styles: const PosStyles(align: PosAlign.center, bold: true));
      
      // Date and time
      final now = DateTime.now();
      final formattedDate = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await _safePrintText(printer, '$formattedDate at $formattedTime', styles: const PosStyles(align: PosAlign.center));
      
      // Service type
      await _safePrintText(printer, 'Service: $serviceType', styles: const PosStyles(align: PosAlign.center, bold: true));
      
      // Customer name (if exists)
      if (personName != null && personName.isNotEmpty) {
        await _safePrintText(printer, 'Customer: $personName', styles: const PosStyles(align: PosAlign.center));
      }
      
      // Separator
      await _safePrintText(printer, '=' * 48, styles: const PosStyles(align: PosAlign.center));

      // Item headers
      await _safePrintRow(printer, [
        PosColumn(text: 'Item', width: 5, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.center)),
        PosColumn(text: 'Price', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'Total', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);

      await _safePrintText(printer, '=' * 48, styles: const PosStyles(align: PosAlign.center));
      
      // Items - each item will be printed in its original language
      for (var item in items) {
        await _safePrintRow(printer, [
          PosColumn(text: item.name, width: 5),
          PosColumn(text: '${item.quantity}', width: 2, styles: const PosStyles(align: PosAlign.center)),
          PosColumn(text: item.price.toStringAsFixed(3), width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: (item.price * item.quantity).toStringAsFixed(3), width: 3, styles: const PosStyles(align: PosAlign.right)),
        ]);

        // Kitchen note - will be printed in its original language
        if (item.kitchenNote.isNotEmpty) {
          await _safePrintText(printer, 'Note: ${item.kitchenNote}', styles: const PosStyles(fontType: PosFontType.fontB));
        }
      }
      
      await _safePrintText(printer, '=' * 48, styles: const PosStyles(align: PosAlign.center));

      // Totals
      await _safePrintRow(printer, [
        PosColumn(text: 'Subtotal:', width: 8, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: subtotal.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      await _safePrintRow(printer, [
        PosColumn(text: 'Tax (${effectiveTaxRate.toStringAsFixed(1)}%):', width: 8, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: tax.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      
      if (discount > 0) {
        await _safePrintRow(printer, [
          PosColumn(text: 'Discount:', width: 8, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: discount.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      
      await _safePrintText(printer, '=' * 48, styles: const PosStyles(align: PosAlign.center));

      await _safePrintRow(printer, [
        PosColumn(text: 'TOTAL:', width: 8, styles: const PosStyles(align: PosAlign.right, bold: true)),
        PosColumn(text: total.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
            
      // Footer
      await _safePrintText(printer, 'Thank you for your visit!', styles: const PosStyles(align: PosAlign.center));
      await _safePrintText(printer, 'Please come again', styles: const PosStyles(align: PosAlign.center));
      
      // If there's Arabic content, also print Arabic footer
      bool hasArabicContent = _containsArabic(businessInfo['name']!) || 
                             _containsArabic(businessInfo['second_name']!) ||
                             _containsArabic(serviceType) ||
                             (personName != null && _containsArabic(personName)) ||
                             items.any((item) => _containsArabic(item.name) || _containsArabic(item.kitchenNote));
      
      if (hasArabicContent) {
        await _safePrintText(printer, 'شكراً لزيارتكم!', styles: const PosStyles(align: PosAlign.center));
        await _safePrintText(printer, 'نتطلع لزيارتكم مرة أخرى', styles: const PosStyles(align: PosAlign.center));
      }

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

  // Print KOT receipt to KOT printer with enhanced Arabic support
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

      // Setup printer for Arabic
      await _setupArabicPrinter(printer);
      
      final billNumber = orderNumber ?? (DateTime.now().millisecondsSinceEpoch % 10000).toString();
      
      // Print header
      await _safePrintText(printer, 'KITCHEN ORDER', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      await _safePrintText(printer, 'ORDER #$billNumber', styles: const PosStyles(align: PosAlign.center, bold: true));

      // Date and time
      final now = DateTime.now();
      final formattedDate = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await _safePrintText(printer, '$formattedDate at $formattedTime', styles: const PosStyles(align: PosAlign.center));
      
      // Service type - will be printed in its original language
      await _safePrintText(printer, 'Service: $serviceType', styles: const PosStyles(align: PosAlign.center, bold: true));
      
      await _safePrintText(printer, '=' * 48, styles: const PosStyles(align: PosAlign.center));

      // Item headers
      await _safePrintRow(printer, [
        PosColumn(text: 'Item', width: 8, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      
      await _safePrintText(printer, '=' * 48, styles: const PosStyles(align: PosAlign.center));
      
      // Items - each item will be printed in its original language (Arabic or English)
      for (var item in items) {
        await _safePrintRow(printer, [
          PosColumn(text: item.name, width: 8),
          PosColumn(text: '${item.quantity}', width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
        
        // Kitchen note - will be printed in its original language
        if (item.kitchenNote.isNotEmpty) {
          await _safePrintText(printer, 'NOTE: ${item.kitchenNote}', styles: const PosStyles(fontType: PosFontType.fontB, bold: true));
        }
        
        await _safePrintText(printer, '');
      }
      
      await _safePrintText(printer, '=' * 48, styles: const PosStyles(align: PosAlign.center));
      
      // Add Arabic header if any item contains Arabic
      bool hasArabicContent = _containsArabic(serviceType) || 
                             items.any((item) => _containsArabic(item.name) || _containsArabic(item.kitchenNote));
      
      if (hasArabicContent) {
        await _safePrintText(printer, 'طلب المطبخ', styles: const PosStyles(align: PosAlign.center, bold: true));
        await _safePrintText(printer, '');
      }
      
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