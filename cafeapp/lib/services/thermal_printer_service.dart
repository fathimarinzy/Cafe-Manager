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
    String? orderNumber = null, 
  }) async {
    final ip = await getPrinterIp();
    final port = await getPrinterPort();
    
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
      printer.text('SIMS RESTO CAFE', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      printer.text('123 Cafe Street, City', styles: const PosStyles(align: PosAlign.center));
      printer.text('Tel: +1234567890', styles: const PosStyles(align: PosAlign.center));
      printer.text('', styles: const PosStyles(align: PosAlign.center));
      
      // Add EDITED indicator if order was edited
      if (isEdited) {
        printer.row([
          PosColumn(
            text: '',
            width: 3,
          ),
          PosColumn(
            text: ' EDITED ',
            width: 1,
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
            width: 2,
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
      
      if (tableInfo != null) {
        printer.text(tableInfo, styles: const PosStyles(align: PosAlign.center));
      }
      
      if (personName != null) {
        printer.text('Customer: $personName', styles: const PosStyles(align: PosAlign.center));
      }
      
      // Divider
      printer.hr();
      
      // Item headers
      printer.row([
        PosColumn(text: 'Item', width: 5, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 1, styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'Price', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'Total', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      printer.hr();
      
      // Items
      for (var item in items) {
        printer.row([
          PosColumn(text: item.name, width: 5),
          PosColumn(text: '${item.quantity}', width: 1, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: item.price.toStringAsFixed(3), width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: (item.price * item.quantity).toStringAsFixed(3), width: 2, styles: const PosStyles(align: PosAlign.right)),
        ]);
        
        // Add kitchen note if present
        if (item.kitchenNote.isNotEmpty) {
          // Use fontType instead of italic
          printer.text('Note: ${item.kitchenNote}', styles: const PosStyles(align: PosAlign.left, fontType: PosFontType.fontB));
        }
      }
      
      printer.hr();
      
      // Totals
      printer.row([
        PosColumn(text: 'Subtotal:', width: 6, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: subtotal.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      
      printer.row([
        PosColumn(text: 'Tax:', width: 6, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: tax.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      
      if (discount > 0) {
        printer.row([
          PosColumn(text: 'Discount:', width: 6, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: discount.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      
      printer.hr();
      
      // Grand total
      printer.row([
        PosColumn(text: 'TOTAL:', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
        PosColumn(text: total.toStringAsFixed(3), width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      
      printer.hr();
      
      // Footer
      printer.text('Thank you for your visit!', styles: const PosStyles(align: PosAlign.center));
      printer.text('Please come again', styles: const PosStyles(align: PosAlign.center));
      
      // Cut paper
      printer.cut();
      
      // Disconnect
      printer.disconnect();
      
      return true;
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      return false;
    }
  }
}