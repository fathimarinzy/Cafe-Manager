import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PrinterUtils {
  // Check if there are any available printers
  static Future<bool> hasPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      return printers.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking for printers: $e');
      return false;
    }
  }
  
  // Get the default printer if available
  static Future<Printer?> getDefaultPrinter() async {
    try {
      final printers = await Printing.listPrinters();
      if (printers.isNotEmpty) {
        return printers.firstWhere(
          (printer) => printer.isDefault, 
          orElse: () => printers.first
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting default printer: $e');
      return null;
    }
  }
}