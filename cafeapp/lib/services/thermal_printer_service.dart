import 'package:flutter/material.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';

class ThermalPrinterService {
  // Printer settings
  static const String _defaultPrinterIp = '192.168.1.100'; // Change to your default printer IP
  static const int _defaultPrinterPort = 9100;             // Standard port for most thermal printers
  static const String _printerIpKey = 'thermal_printer_ip';
  static const String _printerPortKey = 'thermal_printer_port';

  // Get saved printer IP or use default
  static Future<String> getPrinterIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_printerIpKey) ?? _defaultPrinterIp;
  }

  // Get saved printer port or use default
  static Future<int> getPrinterPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_printerPortKey) ?? _defaultPrinterPort;
  }

  // Save printer IP
  static Future<void> savePrinterIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerIpKey, ip);
  }

  // Save printer port
  static Future<void> savePrinterPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_printerPortKey, port);
  }

  // Test printer connection
  static Future<bool> testConnection() async {
    final ip = await getPrinterIp();
    final port = await getPrinterPort();
    
    try {
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      
      debugPrint('Connecting to printer at $ip:$port');
      final PosPrintResult result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 3));
      
      if (result == PosPrintResult.success) {
        // Send a test command
        printer.text('Test connection successful', styles: const PosStyles(align: PosAlign.center, bold: true));
        printer.cut();
        printer.disconnect();
        return true;
      } else {
        debugPrint('Failed to connect to printer: ${result.msg}');
        return false;
      }
    } catch (e) {
      debugPrint('Error connecting to printer: $e');
      return false;
    }
  }
  // Add a method to get business information
  static Future<Map<String, String>> getBusinessInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('business_name') ?? 'SIMS CAFE',
      'address': prefs.getString('business_address') ?? '',
      'phone': prefs.getString('business_phone') ?? '',
      'footer': prefs.getString('receipt_footer') ?? 'Thank you for your visit! Please come again.',
    };
  }

  // Print kitchen ticket directly to network printer
  static Future<bool> printKitchenTicket(MenuItem item) async {
    final ip = await getPrinterIp();
    final port = await getPrinterPort();
    
    try {
      // Initialize printer
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      
      debugPrint('Connecting to printer at $ip:$port for kitchen ticket');
      final PosPrintResult result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 5));
      
      if (result != PosPrintResult.success) {
        debugPrint('Failed to connect to printer: ${result.msg}');
        return false;
      }
      
      // Print kitchen ticket
      
      // Header
      printer.text('KITCHEN ORDER', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      printer.text(DateTime.now().toString().substring(0, 19), styles: const PosStyles(align: PosAlign.center));
      
      // Divider
      printer.hr();
      
      // Item details
      printer.text(item.name, styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      printer.text('QTY: ${item.quantity}', styles: const PosStyles(align: PosAlign.center, bold: true));
      
      // Kitchen note if present
      if (item.kitchenNote.isNotEmpty) {
        printer.text('', styles: const PosStyles(align: PosAlign.center));
        printer.text('SPECIAL INSTRUCTIONS:', styles: const PosStyles(align: PosAlign.left, bold: true));
        printer.text(item.kitchenNote, styles: const PosStyles(align: PosAlign.left, bold: true, underline: true));
      }
      
      // Footer with dashed line
      printer.text('', styles: const PosStyles(align: PosAlign.center));
      printer.text('--------------------------------', styles: const PosStyles(align: PosAlign.center));
      
      // Cut paper
      printer.cut();
      
      // Disconnect
      printer.disconnect();
      
      return true;
    } catch (e) {
      debugPrint('Error printing kitchen ticket: $e');
      return false;
    }
  }

  // Print a full receipt with order details directly to the printer
  static Future<bool> printOrderReceipt({
    required String serviceType,
    required List<MenuItem> items,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    String? personName,
    String? tableInfo,
    bool isEdited = false, // Add parameter to indicate if order was edited
    String? orderNumber , 
    double? taxRate,
  }) async {
    // If tax rate is not provided, use a default
    final effectiveTaxRate = taxRate ?? 0.0;
    
    final ip = await getPrinterIp();
    final port = await getPrinterPort();
    final businessInfo = await getBusinessInfo();
    
    try {
      // Initialize printer
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      
      debugPrint('Connecting to printer at $ip:$port for receipt');
      final PosPrintResult result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 5));
      
      if (result != PosPrintResult.success) {
        debugPrint('Failed to connect to printer: ${result.msg}');
        return false;
      }
      
        // Use provided order number or generate a new one
        final billNumber = orderNumber ?? (DateTime.now().millisecondsSinceEpoch % 10000).toString();
      
      // Print receipt header
      printer.text('RECEIPT', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      await Future.delayed(const Duration(milliseconds: 300));
      printer.text(businessInfo['name']!, styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      await Future.delayed(const Duration(milliseconds: 150)); // Medium delay

      printer.text('', styles: const PosStyles(align: PosAlign.center));
      printer.text(businessInfo['address']!, styles: const PosStyles(align: PosAlign.center));
      printer.text('${businessInfo['phone']}', styles: const PosStyles(align: PosAlign.center));
      await Future.delayed(const Duration(milliseconds: 100)); // Single delay for group


      // Add EDITED indicator if order was edited
      if (isEdited) {
        printer.row([
          PosColumn(
            text: '',
            width: 3,
          ),
          PosColumn(
            text: ' EDITED ',
            width: 6,
            styles: const PosStyles(
              // reverse: true,  // Reverse colors (black background, white text)
              bold: true,
              align: PosAlign.left,
              height: PosTextSize.size1,  // Smaller height
              width: PosTextSize.size1,   // Smaller width
              
            ),
          ),
          PosColumn(
            text: '',
            width: 3,
          ),
        ]);
        printer.text('', styles: const PosStyles(align: PosAlign.center));
      }
      
      printer.text('ORDER #$billNumber', styles: const PosStyles(align: PosAlign.center, bold: true));
      
      // Current date and time
      final now = DateTime.now();
      final formattedDate = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      printer.text('$formattedDate at $formattedTime', styles: const PosStyles(align: PosAlign.center));
      
      // Service information
      printer.text('Service: $serviceType', styles: const PosStyles(align: PosAlign.center, bold: true));
      
      // if (tableInfo != null) {
      //   printer.text(tableInfo, styles: const PosStyles(align: PosAlign.center));
      // }
      
      if (personName != null) {
        printer.text('Customer: $personName', styles: const PosStyles(align: PosAlign.center));
      }
      
      // Divider
      printer.hr();
      await Future.delayed(const Duration(milliseconds: 200)); // CRITICAL

      // Item headers
      printer.row([
        PosColumn(text: 'Item', width: 5, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'Price', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'Total', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      printer.hr();
      await Future.delayed(const Duration(milliseconds: 200)); // CRITICAL

      
      // Items
      for (var item in items) {
        printer.row([
          PosColumn(text: item.name, width: 5),
          PosColumn(text: '${item.quantity}', width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: item.price.toStringAsFixed(3), width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: (item.price * item.quantity).toStringAsFixed(3), width: 3, styles: const PosStyles(align: PosAlign.right)),
        ]);
         await Future.delayed(const Duration(milliseconds: 80)); // CRITICAL

        // Add kitchen note if present
        if (item.kitchenNote.isNotEmpty) {
          // Use fontType instead of italic
          printer.text('Note: ${item.kitchenNote}', styles: const PosStyles(align: PosAlign.left, fontType: PosFontType.fontB));
          await Future.delayed(const Duration(milliseconds: 80)); // CRITICAL
        }
      }
      
      printer.hr();
      await Future.delayed(const Duration(milliseconds: 200)); // CRITICAL

      // Totals
      printer.row([
        PosColumn(text: 'Subtotal:', width: 8, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: subtotal.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      
       printer.row([
      PosColumn(text: 'Tax (${effectiveTaxRate.toStringAsFixed(1)}%):', width: 8, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(text: tax.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      
      if (discount > 0) {
        printer.row([
          PosColumn(text: 'Discount:', width: 8, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: discount.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      await Future.delayed(const Duration(milliseconds: 100)); // Group delay
      
      printer.hr();
     await Future.delayed(const Duration(milliseconds: 200)); // Group delay
      
      // Grand total
      printer.row([
        PosColumn(text: 'TOTAL:', width: 8, styles: const PosStyles(align: PosAlign.right, bold: true)),
        PosColumn(text: total.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      
       await Future.delayed(const Duration(milliseconds: 150));
      
      // Footer
      printer.text('Thank you for your visit!', styles: const PosStyles(align: PosAlign.center));
      printer.text('Please come again', styles: const PosStyles(align: PosAlign.center));
      await Future.delayed(const Duration(milliseconds: 200)); // DON'T REDUCE

      await Future.delayed(const Duration(milliseconds: 1000)); // DON'T REDUCE

      // Cut paper
      printer.cut();
      await Future.delayed(const Duration(milliseconds: 2000)); // DON'T REDUCE

      // Disconnect
      printer.disconnect();
      
      return true;
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      return false;
    }
  }

  // Print a kitchen receipt with simplified info (just item names, quantities, and notes)
static Future<bool> printKitchenReceipt({
  required String serviceType,
  required List<MenuItem> items,
  String? tableInfo,
  String? orderNumber,
}) async { 
  final ip = await getPrinterIp();
  final port = await getPrinterPort();
  
  try {
    // Initialize printer
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);
    
    debugPrint('Connecting to printer at $ip:$port for kitchen receipt');
    final PosPrintResult result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 15)); // ✅ Increased timeout
    
    if (result != PosPrintResult.success) {
      debugPrint('Failed to connect to printer: ${result.msg}');
      return false;
    }
    
    // Use provided order number or generate a new one
    final billNumber = orderNumber ?? (DateTime.now().millisecondsSinceEpoch % 10000).toString();
    
    // Print receipt header
    printer.text('KITCHEN ORDER', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    await Future.delayed(const Duration(milliseconds: 400)); // ✅ CRITICAL - Large text
    
    printer.text('ORDER #$billNumber', styles: const PosStyles(align: PosAlign.center, bold: true));
    await Future.delayed(const Duration(milliseconds: 300)); // ✅ IMPORTANT - Bold text
    
    // Current date and time
    final now = DateTime.now();
    final formattedDate = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    printer.text('$formattedDate at $formattedTime', styles: const PosStyles(align: PosAlign.center));
    await Future.delayed(const Duration(milliseconds: 200)); // ✅ IMPORTANT
    
    // Service information
    printer.text('Service: $serviceType', styles: const PosStyles(align: PosAlign.center, bold: true));
    await Future.delayed(const Duration(milliseconds: 200)); // ✅ IMPORTANT
    
    // // Extract and show table info if available
    // if (tableInfo != null && tableInfo.contains('Table')) {
    //   final tableNumber = tableInfo.split('Table ').last;
    //   printer.text('TABLE: $tableNumber', styles: const PosStyles(align: PosAlign.center, bold: true));
    //   await Future.delayed(const Duration(milliseconds: 200)); // ✅ IMPORTANT
    // }
    
    // Divider
    printer.hr();
    await Future.delayed(const Duration(milliseconds: 300)); // ✅ CRITICAL - Divider processing
    
    // Item headers - simplified for kitchen
    printer.row([
      PosColumn(text: 'Item', width: 8, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Qty', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    await Future.delayed(const Duration(milliseconds: 200)); // ✅ IMPORTANT
    
    printer.hr();
    await Future.delayed(const Duration(milliseconds: 300)); // ✅ CRITICAL
    
    // Items - with focus on name, quantity, and kitchen notes
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      debugPrint('Printing kitchen item ${i + 1}/${items.length}: ${item.name}');
      
      printer.row([
        PosColumn(text: item.name, width: 8),
        PosColumn(text: '${item.quantity}', width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      await Future.delayed(const Duration(milliseconds: 200)); // ✅ CRITICAL - Each item needs processing time
      
      // Add kitchen note if present - this is important for kitchen staff
      if (item.kitchenNote.isNotEmpty) {
        printer.text('NOTE: ${item.kitchenNote}', styles: const PosStyles(align: PosAlign.left, fontType: PosFontType.fontB, bold: true));
        await Future.delayed(const Duration(milliseconds: 150)); // ✅ IMPORTANT - Note processing
      }
      
      // Add a small space between items
      printer.text('', styles: const PosStyles(align: PosAlign.center));
      await Future.delayed(const Duration(milliseconds: 100)); // ✅ OPTIONAL - Spacing
      
      // Keep-alive every 3 items for long orders
      if ((i + 1) % 3 == 0 && items.length > 3) {
        debugPrint('Keep-alive after kitchen item ${i + 1}');
        await Future.delayed(const Duration(milliseconds: 250)); // ✅ CRITICAL - Prevent timeout
      }
    }
    
    printer.hr();
    await Future.delayed(const Duration(milliseconds: 300)); // ✅ CRITICAL
    
    // // Footer - show table number prominently for kitchen
    // if (tableInfo != null && tableInfo.contains('Table')) {
    //   final tableNumber = tableInfo.split('Table ').last;
    //   printer.text('TABLE $tableNumber', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    //   await Future.delayed(const Duration(milliseconds: 400)); // ✅ CRITICAL - Large text
    // }
    
    // Pre-cut delay - CRITICAL for kitchen receipts
    await Future.delayed(const Duration(milliseconds: 1000)); // ✅ CRITICAL - Ensure all data sent
    
    // Cut paper
    printer.cut();
    await Future.delayed(const Duration(milliseconds: 2000)); // ✅ CRITICAL - Cut completion
    
    // Disconnect
    printer.disconnect();
    
    debugPrint('Kitchen receipt completed successfully');
    return true;
  } catch (e) {
    debugPrint('Error printing kitchen receipt: $e');
    return false;
  }
}
 
}