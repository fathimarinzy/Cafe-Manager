import 'package:flutter/material.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import '../models/menu_item.dart';
import './thermal_printer_service.dart';

class KitchenPrintService {
  // Print a kitchen ticket with just the menu item and note - direct ESC/POS only
  static Future<bool> printKitchenTicket(MenuItem item) async {
    try {
      // Get printer configuration
      final ip = await ThermalPrinterService.getPrinterIp();
      final port = await ThermalPrinterService.getPrinterPort();
      
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
}