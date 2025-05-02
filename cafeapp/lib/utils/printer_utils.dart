import 'package:flutter/material.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import '../services/thermal_printer_service.dart';

class PrinterUtils {
  // Check if there are any available network printers
  static Future<bool> hasPrinters() async {
    try {
      // Get the saved printer IP and port
      final ip = await ThermalPrinterService.getPrinterIp();
      final port = await ThermalPrinterService.getPrinterPort();
      
      // Try to connect to the printer
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      
      // Attempt to connect with a short timeout
      final result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 2));
      
      // If connection successful, disconnect and return true
      if (result == PosPrintResult.success) {
        printer.disconnect();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking for printers: $e');
      return false;
    }
  }
  
  // Get printer details if available
  static Future<Map<String, dynamic>?> getDefaultPrinter() async {
    try {
      // Get the saved printer IP and port
      final ip = await ThermalPrinterService.getPrinterIp();
      final port = await ThermalPrinterService.getPrinterPort();
      
      // Try to connect to the printer
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      
      // Attempt to connect with a short timeout
      final result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 2));
      
      // If connection successful, return printer details
      if (result == PosPrintResult.success) {
        printer.disconnect();
        
        return {
          'ip': ip,
          'port': port,
          'isDefault': true,
          'name': 'Thermal Printer',
          'connected': true,
        };
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting default printer: $e');
      return null;
    }
  }

  // Check the printer status
  static Future<String> checkPrinterStatus() async {
    try {
      final ip = await ThermalPrinterService.getPrinterIp();
      final port = await ThermalPrinterService.getPrinterPort();
      
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      
      final result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 2));
      
      if (result == PosPrintResult.success) {
        printer.disconnect();
        return 'Connected';
      } else {
        return 'Error: ${result.msg}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
}