
import 'dart:ui' as ui show Canvas, ImageByteFormat, Paint, PaintingStyle, PictureRecorder, Rect, TextDirection, instantiateImageCodec;
import 'dart:io';
import 'package:flutter/material.dart' show TextAlign, TextPainter, TextSpan, TextStyle, FontWeight, Colors, debugPrint;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:esc_pos_printer_plus/esc_pos_printer_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';
import '../models/order_item.dart';
import '../services/logo_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart'; // Import for compute
import 'windows_raw_printer.dart'; // Direct Windows RAW Printing


class ThermalPrinterService {
  // Printer settings constants
  static const String _defaultReceiptPrinterIp = '192.168.1.100';
  static const int _defaultReceiptPrinterPort = 9100;
  static const String _receiptPrinterIpKey = 'receipt_printer_ip';
  static const String _receiptPrinterPortKey = 'receipt_printer_port';
  
  static const String _defaultKotPrinterIp = '192.168.1.101';
  static const int _defaultKotPrinterPort = 9100;
  static const String _kotPrinterIpKey = 'kot_printer_ip';
  static const String _kotPrinterPortKey = 'kot_printer_port';
  static const String _kotPrinterEnabledKey = 'kot_printer_enabled';

  // NEW: Printer Type Settings
  static const String _receiptPrinterTypeKey = 'receipt_printer_type'; // 'network' or 'system'
  static const String _receiptSystemPrinterNameKey = 'receipt_system_printer_name';
  
  static const String _kotPrinterTypeKey = 'kot_printer_type'; // 'network' or 'system'
  static const String _kotSystemPrinterNameKey = 'kot_system_printer_name';

  static const String printerTypeNetwork = 'network';
  static const String printerTypeSystem = 'system';

  // Image generation constants - Fixed for proper 80mm thermal paper width
  static const double _thermalPrinterWidth = 512.0; // Changed from 576.0
  static const double _pixelRatio = 1.0; // Changed from 1.5 for cleaner printing
  static const double _fontSize = 32.0; // Keep original
  static const double _smallFontSize = 38.0; // Keep original
  static const double _largeFontSize = 52.0; // Keep original
  static const double _padding = 12.0; // Reduced from 16.0

  // Receipt Printer Settings
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

  // KOT Printer Settings
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

  // Printer Type Getters/Setters
  static Future<String> getReceiptPrinterType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_receiptPrinterTypeKey) ?? printerTypeNetwork;
  }

  static Future<void> setReceiptPrinterType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_receiptPrinterTypeKey, type);
  }

  static Future<String?> getReceiptSystemPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_receiptSystemPrinterNameKey);
  }

  static Future<void> setReceiptSystemPrinterName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_receiptSystemPrinterNameKey);
    } else {
      await prefs.setString(_receiptSystemPrinterNameKey, name);
    }
  }

  static Future<String> getKotPrinterType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kotPrinterTypeKey) ?? printerTypeNetwork;
  }

  static Future<void> setKotPrinterType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kotPrinterTypeKey, type);
  }

  static Future<String?> getKotSystemPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kotSystemPrinterNameKey);
  }

  static Future<void> setKotSystemPrinterName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_kotSystemPrinterNameKey);
    } else {
      await prefs.setString(_kotSystemPrinterNameKey, name);
    }
  }

  // Utility Methods
  static bool _containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

 static ui.TextDirection _getTextDirection(String text) {
  return _containsArabic(text) ? ui.TextDirection.rtl : ui.TextDirection.ltr;
}
  static String _getFontFamily(String text) {
    return _containsArabic(text) ? 'Cairo' : 'OpenSans';
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


  // Text Painter Creation - Fixed for proper width usage
  static TextPainter _createTextPainter(
    String text, {
    double fontSize = _fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.black,
    TextAlign textAlign = TextAlign.left,
    double maxWidth = _thermalPrinterWidth,
  }) {
    final textDirection = _getTextDirection(text);
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          fontFamily: _getFontFamily(text),
        ),
      ),
      textDirection: textDirection, // This should work now
      textAlign: textAlign,
      maxLines: null,
    );
    
    // Use full width minus minimal padding
    textPainter.layout(maxWidth: maxWidth - 32);
    return textPainter;
  }

  // Drawing Helper Methods
  static double _drawText(
    ui.Canvas canvas,
    String text, {
    required double x,
    required double y,
    double fontSize = _fontSize,
    FontWeight fontWeight = FontWeight.normal,
    TextAlign textAlign = TextAlign.left,
    double maxWidth = _thermalPrinterWidth,
  }) {
    if (text.isEmpty) return y + fontSize;
    
    final textPainter = _createTextPainter(
      text,
      fontSize: fontSize,
      fontWeight: fontWeight,
      textAlign: textAlign,
      maxWidth: maxWidth,
    );
    
    double drawX = x;
    if (textAlign == TextAlign.center) {
      drawX = (maxWidth - textPainter.width) / 2;
    } else if (textAlign == TextAlign.right) {
      drawX = maxWidth - textPainter.width - _padding;
    }
    
    textPainter.paint(canvas, Offset(drawX, y));
    return y + textPainter.height + 8;
  }

  static double _drawLine(ui.Canvas canvas, double y, {double thickness = 4.0}) {
    final paint = ui.Paint()
      ..color = Colors.black
      ..strokeWidth = thickness;
    
    canvas.drawLine(
      Offset(_padding, y),
      Offset(_thermalPrinterWidth - _padding, y),
      paint,
    );
    
    return y + thickness + 8;
  }

  static double _drawItemsHeader(ui.Canvas canvas, double y) {
    final headerY = y;
    
    // Optimized columns for 512px width
    final itemX = _padding;
    final qtyX = _thermalPrinterWidth * 0.40; 
    final priceX = _thermalPrinterWidth * 0.60;
    final totalX = _thermalPrinterWidth - 85;
    
    // Item
    final itemPainter = _createTextPainter(
      'Item',
      fontSize: _fontSize-4,
      fontWeight: FontWeight.bold,
    );
    itemPainter.paint(canvas, Offset(itemX, headerY));
    
    // Qty
    final qtyPainter = _createTextPainter(
      'Qty',
      fontSize: _fontSize-4,
      fontWeight: FontWeight.bold,
    );
    qtyPainter.paint(canvas, Offset(qtyX, headerY));
    
    // Price
    final pricePainter = _createTextPainter(
      'Price',
      fontSize: _fontSize-4,
      fontWeight: FontWeight.bold,
    );
    pricePainter.paint(canvas, Offset(priceX, headerY));
    
    // Total
    final totalPainter = _createTextPainter(
      'Total',
      fontSize: _fontSize-4,
      fontWeight: FontWeight.bold,
    );
    totalPainter.paint(canvas, Offset(totalX, headerY));
    
    return headerY + _fontSize - 4 + 10;
  }

  // FIXED: Item row layout for proper 80mm paper fit
  static double _drawItemRow(ui.Canvas canvas, MenuItem item, double y) {
    final itemX = _padding;
    final qtyX = _thermalPrinterWidth * 0.40;
    final priceX = _thermalPrinterWidth * 0.60;
    final totalX = _thermalPrinterWidth - 90;

    // Item name with proper width
    final itemPainter = _createTextPainter(
      item.name,
      fontSize: _fontSize - 4,
      maxWidth: _thermalPrinterWidth * 0.40, // More width for item names
    );
    
    itemPainter.paint(canvas, Offset(itemX, y));
    final rowHeight = itemPainter.height.clamp(_fontSize - 4, double.infinity);
    
    // Qty - centered
    final qtyPainter = _createTextPainter(
      '${item.quantity}',
      fontSize: _fontSize - 4,
      fontWeight: FontWeight.bold,
    );
    final qtyXCentered = qtyX + ((_thermalPrinterWidth * 0.12 - qtyPainter.width) / 2);
    qtyPainter.paint(canvas, Offset(qtyXCentered, y));
    
    // Price - right aligned
    final pricePainter = _createTextPainter(
      item.price.toStringAsFixed(3),
      fontSize: _fontSize - 4,
    );
    final priceXAligned = priceX + (_thermalPrinterWidth * 0.20 - 30 - pricePainter.width);
    pricePainter.paint(canvas, Offset(priceXAligned, y));
    
    // Total - right aligned
    final totalPrice = item.price * item.quantity;
    final totalPainter = _createTextPainter(
      totalPrice.toStringAsFixed(3),
      fontSize: _fontSize - 4,
      fontWeight: FontWeight.bold,
    ); 
    totalPainter.paint(canvas, Offset(totalX, y));
    
    return y + rowHeight + 8;
  }
static double _drawTotalRow(ui.Canvas canvas, String label, String value, double y, {bool isTotal = false}) {
  final fontSize = isTotal ? _fontSize : _smallFontSize;
  final fontWeight = isTotal ? FontWeight.bold : FontWeight.normal;
  
  // Reduce font size more for subtotal/tax, keep total size normal
  final actualFontSize = isTotal ? fontSize - 2 : fontSize - 6; // Changed from -2 to -6
  
  // Label - positioned at 60% of width
  final labelPainter = _createTextPainter(
    label,
    fontSize: actualFontSize,
    fontWeight: fontWeight,
  );
  final labelX = _thermalPrinterWidth * 0.6 - labelPainter.width;
  labelPainter.paint(canvas, Offset(labelX, y));
  
  // Value - right aligned with proper margin
  final valuePainter = _createTextPainter(
    value,
    fontSize: actualFontSize,
    fontWeight: fontWeight,
  );
  final valueX = _thermalPrinterWidth - _padding - valuePainter.width;
  valuePainter.paint(canvas, Offset(valueX, y));
  
  return y + actualFontSize + 10;
}
static Future<double> _drawLogo(ui.Canvas canvas, double y) async {
  try {
    final logoEnabled = await LogoService.isLogoEnabled();
    if (!logoEnabled) return y;

    final logoBytes = await LogoService.getLogoForPrinting();
    if (logoBytes == null) return y;

    final image = img.decodeImage(logoBytes);
    if (image == null) return y;

    // Resize to fit thermal printer width (max 180px)
    final resized = img.copyResize(image, width: 180);
    
    // Convert to PNG bytes
    final pngBytes = img.encodePng(resized);
    
    // Decode as Flutter image
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(pngBytes));
    final frame = await codec.getNextFrame();
    final logoImage = frame.image;

    // Center the logo
    final logoX = (_thermalPrinterWidth - resized.width) / 2;
    
    // Draw the logo
    canvas.drawImage(
      logoImage,
      Offset(logoX, y),
      ui.Paint(),
    );

    // Return new Y position with spacing
    return y + resized.height + 12;
  } catch (e) {
    debugPrint('Error drawing logo: $e');
    return y;
  }
}
// Add this new helper method to calculate logo height WITHOUT drawing:
static Future<double> _calculateLogoHeight() async {
  try {
    final logoEnabled = await LogoService.isLogoEnabled();
    if (!logoEnabled) return 0;

    final logoBytes = await LogoService.getLogoForPrinting();
    if (logoBytes == null) return 0;

    final image = img.decodeImage(logoBytes);
    if (image == null) return 0;

    // Resize to fit thermal printer width (max 180px)
    final resized = img.copyResize(image, width: 180);
    
    // Return height with spacing (same as _drawLogo)
    return resized.height.toDouble() + 12;
  } catch (e) {
    debugPrint('Error calculating logo height: $e');
    return 0;
  }
}
  // Receipt Image Generation
static Future<Uint8List?> _generateReceiptImage({
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
  double? depositAmount,
  double? deliveryCharge,
}) async {
  try {
    final businessInfo = await getBusinessInfo();
    final effectiveTaxRate = taxRate ?? 0.0;
    final now = DateTime.now();
    final billNumber = orderNumber ?? '${now.millisecondsSinceEpoch % 10000}';
    
    // Check for Arabic content
    bool hasArabicContent = _containsArabic(businessInfo['name']!) || 
                           _containsArabic(businessInfo['second_name']!) ||
                           _containsArabic(serviceType) ||
                           (personName != null && _containsArabic(personName)) ||
                           items.any((item) => _containsArabic(item.name) || _containsArabic(item.kitchenNote));
    
    // First pass: Calculate exact content height
    double contentHeight = _padding; // Top padding
    // ADD THIS LINE - Calculate logo height if enabled:
    contentHeight += await _calculateLogoHeight();

    final businessNamePainter = _createTextPainter(
      businessInfo['name']!,
      fontSize: _smallFontSize + 2,
      fontWeight: FontWeight.bold,
    );
    contentHeight += businessNamePainter.height + 2;
    
    // Second business name
    if (businessInfo['second_name']!.isNotEmpty) {
      final secondNamePainter = _createTextPainter(
        businessInfo['second_name']!,
        fontSize: _largeFontSize - 2,
        fontWeight: FontWeight.bold,
      );
      contentHeight += secondNamePainter.height + 2;
    }
    
    // Address
    if (businessInfo['address']!.isNotEmpty) {
      final addressPainter = _createTextPainter(
        businessInfo['address']!,
        fontSize: _fontSize - 4,
      );
      contentHeight += addressPainter.height + 1;
    }
    
    // Phone
    if (businessInfo['phone']!.isNotEmpty) {
      final phonePainter = _createTextPainter(
        businessInfo['phone']!,
        fontSize: _fontSize - 4,
      );
      contentHeight += phonePainter.height + 1;
    }
    
    contentHeight += 1; // Space after business info
    
    // Order details
    final orderPainter = _createTextPainter(
      'ORDER #$billNumber',
      fontSize: _fontSize - 4,
    );
    contentHeight += orderPainter.height + 1;
    
    final dateTime = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} at ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final datePainter = _createTextPainter(
      dateTime,
      fontSize: _fontSize - 4,
    );
    contentHeight += datePainter.height + 2;

    final servicePainter = _createTextPainter(
      'Service: $serviceType',
      fontSize: _fontSize - 4,
      fontWeight: FontWeight.bold,
    );
    contentHeight += servicePainter.height + 4;
    
    // Customer name
    if (personName != null && personName.isNotEmpty) {
      final customerPainter = _createTextPainter(
        'Customer: $personName',
        fontSize: _fontSize - 4,
      );
      contentHeight += customerPainter.height + 4;
    }
    
    contentHeight += 8; // Space before first line
    contentHeight += 2 + 6; // First line + spacing
    
    // Items header
    contentHeight += _smallFontSize + 10; // Header height
    contentHeight += 2 + 6; // Second line + spacing

    // Items
    for (final item in items) {
      final itemPainter = _createTextPainter(
        item.name,
        fontSize: _smallFontSize - 4,
        maxWidth: _thermalPrinterWidth * 0.65,
      );
      final rowHeight = itemPainter.height.clamp(_smallFontSize - 4, double.infinity);
      contentHeight += rowHeight + 8;
    
    } 
    
    contentHeight += 2 + 6; // Line after items
    
    // Totals section
    // Corrected height calculations based on _drawTotalRow and _drawLine implementations
    // _drawTotalRow(isTotal: false) returns approx 42 pixels (32 font + 10 padding)
    contentHeight += 42; // Subtotal
    contentHeight += 42; // Tax

    if (deliveryCharge != null && deliveryCharge > 0) {
      contentHeight += 42; // Delivery Charge
    }

    if (discount > 0) {
      contentHeight += 42; // Discount
    }
    
    contentHeight += 12; // Line before total (thickness 4 + 8)
    contentHeight += 40; // Total (isTotal: true, 30 font + 10 padding)
    
    // Add height for Deposit and Balance
    if (depositAmount != null && depositAmount > 0) {
       contentHeight += 5; // Explicit spacing added in draw phase
       contentHeight += 10; // Divider line (thickness 2 + 8)
       contentHeight += 42; // Advance Paid (isTotal: false)
       contentHeight += 40; // Balance Due (isTotal: true)
    }
    contentHeight += 2 + 6; // Line after total
    contentHeight += 8; // Space before footer
    
    // Footer
    final thankYouPainter = _createTextPainter(
      'Thank you for your visit!',
      fontSize: _smallFontSize - 8,
    );
    contentHeight += thankYouPainter.height + 4;
    
    final comeAgainPainter = _createTextPainter(
      'Please come again',
      fontSize: _smallFontSize - 8,
    );
    contentHeight += comeAgainPainter.height + 4;
    
    // Arabic footer
    if (hasArabicContent) {
      contentHeight += 4; // Extra spacing
      
      final arabicThanksPainter = _createTextPainter(
        'شكراً لزيارتكم!',
        fontSize: _smallFontSize - 8,
      );
      contentHeight += arabicThanksPainter.height + 4;
      
      final arabicComeAgainPainter = _createTextPainter(
        'نتطلع لزيارتكم مرة أخرى',
        fontSize: _smallFontSize - 8,
      );
      contentHeight += arabicComeAgainPainter.height ;
    }
    

    contentHeight += _padding;

    // Create recorder with exact calculated height
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, _thermalPrinterWidth, contentHeight));

    // White background
    final backgroundPaint = ui.Paint()..color = Colors.white;
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, _thermalPrinterWidth, contentHeight),
      backgroundPaint,
    );
    
    double currentY = _padding;
    // Draw logo if available
    currentY = await _drawLogo(canvas, currentY);
    
    // Business name
    currentY = _drawText(
      canvas,
      businessInfo['name']!,
      x: _padding,
      y: currentY, 
      fontSize: _smallFontSize,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
    );
      currentY -= 5; // Reduce space before phone by moving currentY up 5 pixels

    // Second business name
    if (businessInfo['second_name']!.isNotEmpty) {
      currentY = _drawText(
        canvas,
        businessInfo['second_name']!,
        x: _padding,
        y: currentY,
        fontSize: _fontSize,
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.center,
      );
    }
     currentY -= 5; // Reduce space before phone by moving currentY up 5 pixels

    // Address
    if (businessInfo['address']!.isNotEmpty) {
      currentY = _drawText(
        canvas,
        businessInfo['address']!,
        x: _padding,
        y: currentY,
        fontSize: _fontSize - 4,
        textAlign: TextAlign.center,
      );
        currentY -= 6; // Reduce space before phone by moving currentY up 6 pixels
    }
    
    // Phone
    if (businessInfo['phone']!.isNotEmpty) {
      currentY = _drawText(
        canvas,
        businessInfo['phone']!,
        x: _padding,
        y: currentY,
        fontSize: _fontSize - 4,
        textAlign: TextAlign.center,
      );
    }
    
    currentY += 6;
    
    // Order details
    currentY = _drawText(
      canvas,
      'ORDER #$billNumber',
      x: _padding,
      y: currentY,
      fontSize: _fontSize - 4,
      textAlign: TextAlign.center,
    );
      currentY -= 6; // Reduce space before phone by moving currentY up 6 pixels

    currentY = _drawText(
      canvas,
      dateTime,
      x: _padding,
      y: currentY,
      fontSize: _fontSize - 4,
      textAlign: TextAlign.center,
    );
      currentY -= 6; // Reduce space before phone by moving currentY up 6 pixels

    currentY = _drawText(
      canvas,
      'Service: $serviceType',
      x: _padding,
      y: currentY,
      fontSize: _fontSize - 4,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
    );
    
    if (personName != null && personName.isNotEmpty) {
      currentY = _drawText(
        canvas,
        'Customer: $personName',
        x: _padding,
        y: currentY,
        fontSize: _smallFontSize - 4,
        textAlign: TextAlign.center,
      );
    }
    
    currentY += 10;
    currentY = _drawLine(canvas, currentY);
    
    // Items
    currentY = _drawItemsHeader(canvas, currentY);
    currentY = _drawLine(canvas, currentY);
    
    for (final item in items) {
      currentY = _drawItemRow(canvas, item, currentY);
      
      currentY += 5;
    }
    
    currentY = _drawLine(canvas, currentY);
    
    // Totals
    currentY = _drawTotalRow(canvas, 'Subtotal:', subtotal.toStringAsFixed(3), currentY);
    currentY = _drawTotalRow(canvas, 'Tax (${effectiveTaxRate.toStringAsFixed(1)}%):', tax.toStringAsFixed(3), currentY);
    
    if (deliveryCharge != null && deliveryCharge > 0) {
       currentY = _drawTotalRow(canvas, 'Delivery Fee:', deliveryCharge.toStringAsFixed(3), currentY);
    }
    
    if (discount > 0) {
      currentY = _drawTotalRow(canvas, 'Discount:', discount.toStringAsFixed(3), currentY);
    }
    
    currentY = _drawLine(canvas, currentY);
    currentY = _drawTotalRow(canvas, 'TOTAL:', total.toStringAsFixed(3), currentY, isTotal: true);
    // Deposit and Balance
    if (depositAmount != null && depositAmount > 0) {
       currentY += 5;
       currentY = _drawLine(canvas, currentY, thickness: 2.0);
       currentY = _drawTotalRow(canvas, 'Advance Paid:', depositAmount.toStringAsFixed(3), currentY);
       
       final balance = total - depositAmount;
       currentY = _drawTotalRow(canvas, 'Balance Due:', balance.toStringAsFixed(3), currentY, isTotal: true);
    }
    // currentY = _drawLine(canvas, currentY);
    
    currentY += 10;
    
    // Footer
    currentY = _drawText(
      canvas,
      'Thank you for your visit!',
      x: _padding,
      y: currentY,
      fontSize: _smallFontSize - 8,
      textAlign: TextAlign.center,
    );
      currentY -= 5; // Reduce space before phone by moving currentY up 5 pixels

    currentY = _drawText(
      canvas,
      'Please come again',
      x: _padding,
      y: currentY,
      fontSize: _smallFontSize - 8,
      textAlign: TextAlign.center,
    );
    
    // Arabic footer if needed
    if (hasArabicContent) {
      currentY += 4;
      currentY = _drawText(
        canvas,
        'شكراً لزيارتكم!',
        x: _padding,
        y: currentY,
        fontSize: _smallFontSize - 8,
        textAlign: TextAlign.center,
      );
      currentY -= 6; // Reduce space before phone by moving currentY up 6 pixels

      currentY = _drawText(
        canvas,
        'نتطلع لزيارتكم مرة أخرى',
        x: _padding,
        y: currentY,
        fontSize: _smallFontSize - 8,
        textAlign: TextAlign.center,
      );
    }
    
    // Create final image with exact content height
    final picture = recorder.endRecording();
    final img = await picture.toImage(
      (_thermalPrinterWidth * _pixelRatio).round(),
      (contentHeight * _pixelRatio).round(), // Use pre-calculated exact height
    );

    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
    
  } catch (e) {
    debugPrint('Error generating receipt image: $e');
    return null;
  }
}

  // KOT Image Generation
static Future<Uint8List?> _generateKotImage({
  required List<MenuItem> items,
  required String serviceType,
  String? tableInfo,
  String? orderNumber,
  bool isEdited = false,
  List<OrderItem>? originalItems,
}) async {
  try {
    final now = DateTime.now();
    final billNumber = orderNumber ?? '${now.millisecondsSinceEpoch % 10000}';
    
    // OPTIMIZATION: Yield to event loop to keep UI responsive
    await Future.delayed(Duration.zero);

    // First pass: Calculate the exact content height
    double contentHeight = _padding; // Start with top padding
    
    // Header content
    final headerPainter1 = _createTextPainter(
      'KITCHEN ORDER',
      fontSize: _largeFontSize - 6,
      fontWeight: FontWeight.bold,
    );
    contentHeight += headerPainter1.height + 8; // Title + spacing

    // EDITED marker if order was edited
    if (isEdited) {
      final editedPainter = _createTextPainter(
        'EDITED',
        fontSize: _fontSize - 2,
        fontWeight: FontWeight.bold,
      );
      contentHeight += editedPainter.height + 16; // Extra space for border
    }
    
    final headerPainter2 = _createTextPainter(
      'ORDER #$billNumber',
      fontSize: _fontSize,
      fontWeight: FontWeight.bold,
    );
    contentHeight += headerPainter2.height + 8; // Order number + spacing
    
    final dateTime = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} at ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final headerPainter3 = _createTextPainter(
      dateTime,
      fontSize: _fontSize - 4,
    );
    contentHeight += headerPainter3.height + 8; // Date + spacing
    
    final headerPainter4 = _createTextPainter(
      'Service: $serviceType',
      fontSize: _fontSize,
      fontWeight: FontWeight.bold,
    );
    contentHeight += headerPainter4.height + 8; // Service + spacing
    
    contentHeight += 10 + 4; // Space + line

    // Items header
    contentHeight += _smallFontSize + 8; // Item/Qty header + spacing
    contentHeight += 4; // Second line thickness

    // If edited, handle cancelled and new items
    if (isEdited && originalItems != null) {
      // Find cancelled items
      final cancelledItems = originalItems.where((original) {
        return !items.any((current) => 
          current.id == original.id.toString() && 
          current.quantity >= original.quantity
        );
      }).toList();
      
      // Find new items (items that weren't in original order)
      final newItems = items.where((current) {
        return !originalItems.any((original) => 
          original.id.toString() == current.id
        );
      }).toList();
      
      // Find increased quantity items and create modified copies showing only the increase
      final increasedItems = items.where((current) {
        final original = originalItems.firstWhere(
          (orig) => orig.id.toString() == current.id,
          orElse: () => OrderItem(id: 0, name: '', price: 0, quantity: 0, kitchenNote: ''),
        );
        return original.id != 0 && current.quantity > original.quantity;
      }).map((current) {
        // Find the original quantity
        final original = originalItems.firstWhere(
          (orig) => orig.id.toString() == current.id,
        );
        // Create a copy with only the increased quantity
        return MenuItem(
          id: current.id,
          name: current.name,
          price: current.price,
          quantity: current.quantity - original.quantity, // Show only the increase
          imageUrl: current.imageUrl,
          category: current.category,
          kitchenNote: current.kitchenNote,
        );
      }).toList();
      
      // Show cancelled items section if there are any
      if (cancelledItems.isNotEmpty) {
        final cancelledHeaderPainter = _createTextPainter(
          'CANCELLED:',
          fontSize: _fontSize - 2,
          fontWeight: FontWeight.bold,
        );
        contentHeight += cancelledHeaderPainter.height + 8;
        
        for (final item in cancelledItems) {
          final itemPainter = _createTextPainter(
            item.name,
            fontSize: _smallFontSize,
            maxWidth: _thermalPrinterWidth * 0.7,
          );
          contentHeight += itemPainter.height + 20;
        }
        
        contentHeight += 10;
      }
      
      // Show "NEW ITEMS:" header if there are changes
      if (newItems.isNotEmpty || increasedItems.isNotEmpty) {
        final newItemsHeaderPainter = _createTextPainter(
          'NEW ITEMS:',
          fontSize: _fontSize - 2,
          fontWeight: FontWeight.bold,
        );
        contentHeight += newItemsHeaderPainter.height + 8;
        
        // Calculate height for only new and increased items
        for (final item in [...newItems, ...increasedItems]) {
          final itemNamePainter = _createTextPainter(
            item.name,
            fontSize: _smallFontSize,
            maxWidth: _thermalPrinterWidth * 0.7,
          );
          contentHeight += itemNamePainter.height + 8;
          
          if (item.kitchenNote.isNotEmpty) {
            final notePainter = _createTextPainter(
              'NOTE: ${item.kitchenNote}',
              fontSize: _smallFontSize - 2,
              maxWidth: _thermalPrinterWidth * 0.8,
            );
            contentHeight += notePainter.height + 8;
          }
          
          contentHeight += 10;
        }
      }
    } else {
      // Not edited - calculate for all items normally
      for (final item in items) {
        final itemNamePainter = _createTextPainter(
          item.name,
          fontSize: _smallFontSize,
          maxWidth: _thermalPrinterWidth * 0.7,
        );
        contentHeight += itemNamePainter.height + 8;
        
        if (item.kitchenNote.isNotEmpty) {
          final notePainter = _createTextPainter(
            'NOTE: ${item.kitchenNote}',
            fontSize: _smallFontSize - 2,
            maxWidth: _thermalPrinterWidth * 0.8,
          );
          contentHeight += notePainter.height + 8;
        }
        
        contentHeight += 10;
      }
    }

      
    contentHeight += 4; // Final line thickness only (no extra spacing)
    
    // Create the canvas with exact height
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, _thermalPrinterWidth, contentHeight));

    final backgroundPaint = ui.Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _thermalPrinterWidth, contentHeight),
      backgroundPaint,
    );
    
    double currentY = _padding;
    
    // Header
    currentY = _drawText(
      canvas,
      'KITCHEN ORDER',
      x: _padding,
      y: currentY,
      fontSize: _largeFontSize - 6,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
    );
        // EDITED marker
    if (isEdited) {
      final editedPainter = _createTextPainter(
        'EDITED',
        fontSize: _fontSize - 2,
        fontWeight: FontWeight.bold,
      );
      final editedX = (_thermalPrinterWidth - editedPainter.width) / 2;
      final borderRect = Rect.fromLTWH(
        editedX - 10,
        currentY - 5,
        editedPainter.width + 20,
        editedPainter.height + 10,
      );

      final borderPaint = ui.Paint()
        ..color = Colors.black
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.0;
      
      canvas.drawRect(borderRect, borderPaint);
      
      currentY = _drawText(
        canvas,
        'EDITED',
        x: _padding,
        y: currentY,
        fontSize: _fontSize - 2,
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.center,
      );
    }
    
    currentY = _drawText(
      canvas,
      'ORDER #$billNumber',
      x: _padding,
      y: currentY,
      fontSize: _fontSize,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
    );
    
    currentY = _drawText(
      canvas,
      dateTime,
      x: _padding,
      y: currentY,
      fontSize: _fontSize - 4,
      textAlign: TextAlign.center,
    );
    
    currentY = _drawText(
      canvas,
      'Service: $serviceType',
      x: _padding,
      y: currentY,
      fontSize: _fontSize,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
    );
    
    currentY += 10;
    currentY = _drawLine(canvas, currentY);
    
    // KOT Items header
    final itemPainter = _createTextPainter(
      'Item',
      fontSize: _smallFontSize,
      fontWeight: FontWeight.bold,
    );
    itemPainter.paint(canvas, Offset(_padding, currentY));
    
    final qtyPainter = _createTextPainter(
      'Qty',
      fontSize: _smallFontSize,
      fontWeight: FontWeight.bold,
    );
    qtyPainter.paint(canvas, Offset(_thermalPrinterWidth - _padding - qtyPainter.width, currentY));

    currentY += _smallFontSize + 8;
    currentY = _drawLine(canvas, currentY);

    // Show cancelled items if edited
    if (isEdited && originalItems != null) {
      final cancelledItems = originalItems.where((original) {
        return !items.any((current) => 
          current.id == original.id.toString() && 
          current.quantity >= original.quantity
        );
      }).toList();
      
      // Find new items (not in original order)
      final newItems = items.where((current) {
        return !originalItems.any((original) => 
          original.id.toString() == current.id
        );
      }).toList();
      
      // Find increased quantity items and create modified copies showing only the increase
      final increasedItems = items.where((current) {
        final original = originalItems.firstWhere(
          (orig) => orig.id.toString() == current.id,
          orElse: () => OrderItem(id: 0, name: '', price: 0, quantity: 0, kitchenNote: ''),
        );
        return original.id != 0 && current.quantity > original.quantity;
      }).map((current) {
        // Find the original quantity
        final original = originalItems.firstWhere(
          (orig) => orig.id.toString() == current.id,
        );
        // Create a copy with only the increased quantity
        return MenuItem(
          id: current.id,
          name: current.name,
          price: current.price,
          quantity: current.quantity - original.quantity, // Show only the increase
          imageUrl: current.imageUrl,
          category: current.category,
          kitchenNote: current.kitchenNote,
        );
      }).toList();
      
      // Draw cancelled items if any
      if (cancelledItems.isNotEmpty) {
        currentY = _drawText(
          canvas,
          'CANCELLED:',
          x: _padding,
          y: currentY,
          fontSize: _fontSize - 2,
          fontWeight: FontWeight.bold,
          textAlign: TextAlign.left,
        );
        
        for (final item in cancelledItems) {
          final itemNamePainter = _createTextPainter(
            item.name,
            fontSize: _smallFontSize,
            maxWidth: _thermalPrinterWidth * 0.7,
          );
          
          final boxRect = Rect.fromLTWH(
            _padding - 5,
            currentY - 3,
            _thermalPrinterWidth - (_padding * 2) + 10,
            itemNamePainter.height + 6,
          );
          
          final boxPaint = ui.Paint()
            ..color = Colors.black
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 1.0;
          
          canvas.drawRect(boxRect, boxPaint);
          
          itemNamePainter.paint(canvas, Offset(_padding, currentY));
          
          final qtyValuePainter = _createTextPainter(
            '${item.quantity}',
            fontSize: _smallFontSize,
            fontWeight: FontWeight.bold,
          );
          qtyValuePainter.paint(canvas, Offset(_thermalPrinterWidth - _padding - qtyValuePainter.width, currentY));
          
          currentY += itemNamePainter.height + 12;
        }
        
        currentY += 10;
      }
      
      // Show "NEW ITEMS:" and draw only new/increased items
      if (newItems.isNotEmpty || increasedItems.isNotEmpty) {
        currentY = _drawText(
          canvas,
          'NEW ITEMS:',
          x: _padding,
          y: currentY,
          fontSize: _fontSize - 2,
          fontWeight: FontWeight.bold,
          textAlign: TextAlign.left,
        );
        
        // Combine new and increased items
        final itemsToDraw = [...newItems, ...increasedItems];
        
        for (final item in itemsToDraw) {
          final itemNamePainter = _createTextPainter(
            item.name,
            fontSize: _smallFontSize,
            maxWidth: _thermalPrinterWidth * 0.7,
          );
          itemNamePainter.paint(canvas, Offset(_padding, currentY));
          
          final qtyValuePainter = _createTextPainter(
            '${item.quantity}',
            fontSize: _smallFontSize,
            fontWeight: FontWeight.bold,
          );
          qtyValuePainter.paint(canvas, Offset(_thermalPrinterWidth - _padding - qtyValuePainter.width, currentY));
          
          currentY += itemNamePainter.height + 8;
          
          if (item.kitchenNote.isNotEmpty) {
            currentY = _drawText(
              canvas,
              'NOTE: ${item.kitchenNote}',
              x: _padding * 1.5,
              y: currentY,
              fontSize: _smallFontSize - 2,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.left,
            );
          }
          
          currentY += 10;
        }
      }
    } else {
      // Not edited - draw all items normally
      for (final item in items) {
        final itemNamePainter = _createTextPainter(
          item.name,
          fontSize: _smallFontSize,
          maxWidth: _thermalPrinterWidth * 0.7,
        );
        itemNamePainter.paint(canvas, Offset(_padding, currentY));
        
        final qtyValuePainter = _createTextPainter(
          '${item.quantity}',
          fontSize: _smallFontSize,
          fontWeight: FontWeight.bold,
        );
        qtyValuePainter.paint(canvas, Offset(_thermalPrinterWidth - _padding - qtyValuePainter.width, currentY));
        
        currentY += itemNamePainter.height + 8;
        
        if (item.kitchenNote.isNotEmpty) {
          currentY = _drawText(
            canvas,
            'NOTE: ${item.kitchenNote}',
            x: _padding * 1.5,
            y: currentY,
            fontSize: _smallFontSize - 2,
            fontWeight: FontWeight.bold,
            textAlign: TextAlign.left,
          );
        }
        
        currentY += 10;
      }
    }
    // Draw final line manually without extra spacing
    final paint = ui.Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0;
    
    canvas.drawLine(
      Offset(_padding, currentY),
      Offset(_thermalPrinterWidth - _padding, currentY),
      paint,
    );
    
    // Create the final image with the exact calculated height
    final picture = recorder.endRecording();
    final img = await picture.toImage(
      (_thermalPrinterWidth * _pixelRatio).round(),
      (contentHeight * _pixelRatio).round(), // Use the pre-calculated height
    );

    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
    
  } catch (e) {
    debugPrint('Error generating KOT image: $e');
    return null;
  }
}

  // Direct RAW Printing using Windows Spooler (Fix for truncation)
  static Future<bool> _printToUsb(Uint8List imageBytes, {bool isKot = false}) async {
    // Only works on Windows for now (user's target OS)
    if (!Platform.isWindows) return false;

    try {
      debugPrint('Attempting Direct RAW Print...');
      
      // 1. Get the configured System Printer Name
      // We reuse the same printer selected in settings, but send RAW bytes instead of PDF
      final printerName = isKot 
          ? await getKotSystemPrinterName() 
          : await getReceiptSystemPrinterName();
          
      if (printerName == null) {
        debugPrint('No system printer configured for RAW print');
        return false;
      }

      debugPrint('Targeting printer for RAW output: $printerName');

      // Check for Windows offline status specifically for RAW print
      // This is crucial to prevent spooling jobs when the printer is physically disconnected
      final isReady = await _isWindowsPrinterReady(printerName);
      if (!isReady) {
        debugPrint('Windows RAW printer check failed: $printerName is offline or not ready');
        return false;
      }

      // 2. Purge existing jobs if any (Anti-Spooling safeguard)
      // If the printer was offline and just came online, it might have old jobs stuck.
      // We clear them to ensure only the CURRENT job prints.
      try {
        debugPrint('Purging stale jobs for: $printerName');
        await Process.run('powershell', [
          '-Command', 
          'Get-Printer -Name "$printerName" | Get-PrintJob | Remove-PrintJob'
        ]);
      } catch (e) {
        debugPrint('Warning: Failed to purge jobs: $e');
      }

      // 3. Generate ESC/POS Raster Bytes
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // Reset
      bytes += generator.reset();

      // Process Image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('Failed to decode image for RAW print');
        return false;
      }

      // Resize and Grayscale (consistent with network print)
      // 512 width is safe for 80mm
      final resized = img.copyResize(image, width: 512); 
      final bw = img.grayscale(resized);

      // Raster Image Command
      bytes += generator.image(bw);
      bytes += generator.cut();

      // 3. Send Bytes via Win32 Spooler API
      final success = WindowsRawPrinter.printBytes(
        printerName: printerName,
        bytes: bytes,
        jobName: isKot ? "Sims Cafe KOT (RAW)" : "Sims Cafe Receipt (RAW)"
      );
      
      if (success) {
        debugPrint('Direct Windows RAW Print sent to spooler. Verifying execution...');
        
        // 4. Post-Print Verification (Fix for "Spooling when offline")
        // Windows might accept the job to spooler even if offline.
        // We wait briefly and check if the job is still stuck in the queue.
        await Future.delayed(const Duration(seconds: 2));
        
        // Check JobCount
        final jobCountResult = await Process.run('powershell', [
          '-Command', 
          'Get-Printer -Name "$printerName" | Select-Object -ExpandProperty JobCount'
        ]);
        
        int jobCount = 0;
        try {
           jobCount = int.parse(jobCountResult.stdout.toString().trim());
        } catch (e) {
           // If parsing fails, assume 0 or handle safe
        }
        
        if (jobCount > 0) {
           debugPrint('Job stuck in spooler (JobCount: $jobCount). Printer likely offline properly.');
           debugPrint('PURGING stuck job to prevent ghost printing...');
           
           // PURGE again to cancel the stuck job
           await Process.run('powershell', [
              '-Command', 
              'Get-Printer -Name "$printerName" | Get-PrintJob | Remove-PrintJob'
           ]);
           
           return false; // Treat as failed so fallback dialog appears
        }
        
        debugPrint('Job cleared from queue (Printed successfully).');
        return true;
      } else {
        debugPrint('Failed to send RAW bytes to printer');
        return false;
      }
    } catch (e) {
      debugPrint('Error in _printToUsb: $e');
      return false;
    }
  }

  // Helper to check precise Windows printer status using PowerShell
  static Future<bool> _isWindowsPrinterReady(String printerName) async {
    try {
      // Execute PowerShell command to get printer status
      // We check for 'WorkOffline' and 'PrinterStatus'
      final result = await Process.run('powershell', [
        '-Command', 
        'Get-Printer -Name "$printerName" | Select-Object WorkOffline, PrinterStatus | ConvertTo-Json'
      ]);

      if (result.exitCode != 0) {
        debugPrint('Failed to check printer status: ${result.stderr}');
        // If we can't check, we default to seeing if standard isAvailable worked (which it did to get here)
        // But to be safe for this specific "offline spooling" bug, maybe return false? 
        // Let's allow it but log warning, as aggressive blocking might break things if PS fails.
        return true; 
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty) return true;

      // Simple string parsing to avoid full JSON import for just this
      // JSON example: { "WorkOffline": true, "PrinterStatus": 1 }
      
      final isOffline = output.contains('"WorkOffline":true') || output.contains('"WorkOffline": true');
      
      // PrinterStatus 3 = Idle, 4 = Printing, 5 = Warming Up. Others are error states.
      // 1 = Other, 2 = Unknown, 6 = Stopped, 7 = Offline
      // We'll trust WorkOffline mostly, but also check for explicit error status codes if needed.
      // For now, WorkOffline is the main flag set when USB is unplugged.
      
      if (isOffline) {
        debugPrint('Windows Printer Check: Printer is marked WorkOffline');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error checking Windows printer status: $e');
      return true; // Fallback to allowing it if check fails
    }
  }

  // Print Image to System Printer (USB/Bluetooth/Driver)
  static Future<bool> _printToSystemPrinter(Uint8List imageBytes, {bool isKot = false, String? overridePrinterName}) async {
    try {
      // Create a completer to handle the timeout logic wrapper
      // We wrap the entire process in a Future.timeout to ensure we don't hang indefinitely
      return await Future<bool>(() async {
        final printerName = overridePrinterName ?? (isKot 
            ? await getKotSystemPrinterName() 
            : await getReceiptSystemPrinterName());
        
        if (printerName == null) {
          debugPrint('No system printer selected for ${isKot ? 'KOT' : 'receipt'}');
          return false;
        }

        // Find the printer
        final printers = await Printing.listPrinters();
        Printer? printer;
        try {
          printer = printers.firstWhere((p) => p.name == printerName);
        } catch (e) {
          printer = null;
        }

        if (printer == null) {
          debugPrint('Printer not found: $printerName');
          return false;
        }

        if (!printer.isAvailable) {
          debugPrint('Printer is not available: $printerName');
          return false;
        }

        // Check for Windows offline status specifically
        // This prevents spooling jobs when the printer is physically disconnected
        if (Platform.isWindows) {
          final isReady = await _isWindowsPrinterReady(printer.name);
          if (!isReady) {
            debugPrint('Windows printer check failed: ${printer.name} is offline or not ready');
            return false;
          }
        }

        // Create PDF document
        final doc = pw.Document();
        final image = pw.MemoryImage(imageBytes);

        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image),
            );
          },
        ));

        // Print
        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: '${isKot ? 'KOT' : 'Receipt'}_${DateTime.now().millisecondsSinceEpoch}',
          format: PdfPageFormat.roll80,
        );

        debugPrint('${isKot ? 'KOT' : 'Receipt'} sent to system printer: $printerName');
        return true;
      }).timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('System printing timed out after 5 seconds');
        return false; 
      });
    } catch (e) {
      debugPrint('Error printing to system printer: $e');
      return false;
    }
  }

  // Print Image to Printer - Fixed width handling
  static Future<bool> _printImage(Uint8List imageBytes, {bool isKot = false}) async {
    try {
      // Check printer type preference
      final printerType = isKot 
          ? await getKotPrinterType() 
          : await getReceiptPrinterType();

      // Route to appropriate method
      if (printerType == printerTypeSystem) {
         // Smart Routing: Try Direct USB First for Receipt (non-KOT) to fix truncation
         // Or just try RAW first for both if enabled settings (defaulting to try RAW first for system printers on Windows)
         // We pass isKot to help identify correct printer
         if (Platform.isWindows) {
            final usbSuccess = await _printToUsb(imageBytes, isKot: isKot);
            if (usbSuccess) {
              return true; // Successfully printed via direct RAW
            }
            debugPrint('Direct RAW print failed, falling back to System Driver (PDF)');
         }
         
        return await _printToSystemPrinter(imageBytes, isKot: isKot);
      }

      // Network Printing Logic (Existing) with Timeout Wrapper
      return await Future<bool>(() async {
        final prefs = await SharedPreferences.getInstance();
        String ip;
        int port;
        
        if (isKot) {
          ip = prefs.getString(_kotPrinterIpKey) ?? _defaultKotPrinterIp;
          port = prefs.getInt(_kotPrinterPortKey) ?? _defaultKotPrinterPort;
        } else {
          ip = prefs.getString(_receiptPrinterIpKey) ?? _defaultReceiptPrinterIp;
          port = prefs.getInt(_receiptPrinterPortKey) ?? _defaultReceiptPrinterPort;
        }
        
        final profile = await CapabilityProfile.load();
        final printer = NetworkPrinter(PaperSize.mm80, profile);
        
        debugPrint('Connecting to ${isKot ? 'KOT' : 'receipt'} printer at $ip:$port');
        
        // We use a shorter inner timeout for connection to allow the overall timeout to catch prolonged operations
        final result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 4));
        
        if (result != PosPrintResult.success) {
          debugPrint('Failed to connect to printer: ${result.msg}');
          return false;
        }

        final image = img.decodeImage(imageBytes);
        if (image == null) {
          debugPrint('Failed to decode image');
          printer.disconnect();
          return false;
        }

        // Resize to proper thermal printer width (512 pixels for 80mm at 8 dots/mm)
        final resized = img.copyResize(image, width: 512);
        
        // Convert to black and white for better contrast
        final bw = img.grayscale(resized);
        
        printer.image(bw);
        printer.cut();
        
        // Reduced delay to fit within timeout
        await Future.delayed(const Duration(milliseconds: 200));
        printer.disconnect();
        
        debugPrint('${isKot ? 'KOT' : 'Receipt'} printed successfully');
        return true;
      }).timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('Network printing timed out after 5 seconds');
        return false;
      });
      
    } catch (e) {
      debugPrint('Error printing image: $e');
      return false;
    }
  }

  // Main Public Methods
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
    double? depositAmount,
    double? deliveryCharge,
  }) async {
    debugPrint('Printing order receipt as image');
    
    final imageBytes = await _generateReceiptImage(
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
      taxRate: taxRate,
      depositAmount: depositAmount,
      deliveryCharge: deliveryCharge,
    );
    
    if (imageBytes == null) {
      debugPrint('Failed to generate receipt image');
      return false;
    }
    
    return await _printImage(imageBytes, isKot: false);
  }

  static Future<bool> printKotReceipt({
    required String serviceType,
    required List<MenuItem> items,
    String? tableInfo,
    String? orderNumber,
    bool isEdited = false,
    List<OrderItem>? originalItems,
  }) async {
    final kotEnabled = await isKotPrinterEnabled();
    if (!kotEnabled) {
      debugPrint('KOT printer is disabled');
      return true;
    }
    
    debugPrint('Printing KOT as image');
    
    final imageBytes = await _generateKotImage(
      items: items,
      serviceType: serviceType,
      tableInfo: tableInfo,
      orderNumber: orderNumber,
      isEdited: isEdited,
      originalItems: originalItems,
    );
    
    if (imageBytes == null) {
      debugPrint('Failed to generate KOT image');
      return false;
    }
    
    return await _printImage(imageBytes, isKot: true);
  }

  // Alias for backward compatibility
  static Future<bool> printKitchenReceipt({
    required String serviceType,
    required List<MenuItem> items,
    String? tableInfo,
    String? orderNumber,
    bool isEdited = false,
    List<OrderItem>? originalItems,
  }) async {
    return await printKotReceipt(
      serviceType: serviceType,
      items: items,
      tableInfo: tableInfo,
      orderNumber: orderNumber,
      isEdited: isEdited,
      originalItems: originalItems,
    );
  }

  // Test Methods
  static Future<bool> testConnection({
    String? type,
    String? ip,
    int? port,
    String? systemPrinterName,
  }) async {
    try {
      final effectiveType = type ?? await getReceiptPrinterType();

      if (effectiveType == printerTypeSystem) {
        final name = systemPrinterName ?? await getReceiptSystemPrinterName();
        if (name == null) return false;
        
        // For system printers, we test by printing a small image
        final testImage = await _generateTestImage();
        if (testImage == null) return false;
        
        return await _printToSystemPrinter(testImage, isKot: false, overridePrinterName: name);
      }

      // Network logic
      final effectiveIp = ip ?? await getPrinterIp();
      final effectivePort = port ?? await getPrinterPort();
      
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      
      final result = await printer.connect(effectiveIp, port: effectivePort, timeout: const Duration(seconds: 3));
      
      if (result == PosPrintResult.success) {
        // Generate test image
        final testImage = await _generateTestImage();
        if (testImage != null) {
          final image = img.decodeImage(testImage);
          if (image != null) {
            final resized = img.copyResize(image, width: 512); // Fixed width
            printer.image(resized);
            printer.cut();
          }
        }
        printer.disconnect();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Test connection error: $e');
      return false;
    }
  }

  static Future<bool> testKotConnection({
    String? type,
    String? ip,
    int? port,
    String? systemPrinterName,
  }) async {
    try {
      final effectiveType = type ?? await getKotPrinterType();

      if (effectiveType == printerTypeSystem) {
        final name = systemPrinterName ?? await getKotSystemPrinterName();
        if (name == null) return false;
        
        final testImage = await _generateTestImage(isKot: true);
        if (testImage == null) return false;
        
        return await _printToSystemPrinter(testImage, isKot: true, overridePrinterName: name);
      }

      // Network logic
      final effectiveIp = ip ?? await getKotPrinterIp();
      final effectivePort = port ?? await getKotPrinterPort();
      
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      
      final result = await printer.connect(effectiveIp, port: effectivePort, timeout: const Duration(seconds: 3));
      
      if (result == PosPrintResult.success) {
        final testImage = await _generateTestImage(isKot: true);
        if (testImage != null) {
          final image = img.decodeImage(testImage);
          if (image != null) {
            final resized = img.copyResize(image, width: 512); // Fixed width
            printer.image(resized);
            printer.cut();
          }
        }
        printer.disconnect();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('KOT test connection error: $e');
      return false;
    }
  }

  // Generate test image
  static Future<Uint8List?> _generateTestImage({bool isKot = false}) async {
    try {
      const double height = 300;
      
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, _thermalPrinterWidth, height));

      final backgroundPaint = ui.Paint()..color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, _thermalPrinterWidth, height),
        backgroundPaint,
      );
      
      double currentY = _padding;
      
      if (isKot) {
        currentY = _drawText(
          canvas,
          'KOT PRINTER TEST',
          x: _padding,
          y: currentY,
          fontSize: _fontSize,
          fontWeight: FontWeight.bold,
          textAlign: TextAlign.center,
        );
      } else {
        currentY = _drawText(
          canvas,
          'RECEIPT PRINTER TEST',
          x: _padding,
          y: currentY,
          fontSize: _fontSize,
          fontWeight: FontWeight.bold,
          textAlign: TextAlign.center,
        );
      }
      
      currentY += 20;
      
      currentY = _drawText(
        canvas,
        'Connection successful!',
        x: _padding,
        y: currentY,
        fontSize: _fontSize,
        textAlign: TextAlign.center,
      );
      
      currentY = _drawText(
        canvas,
        'Arabic test: مرحبا',
        x: _padding,
        y: currentY,
        fontSize: _fontSize,
        textAlign: TextAlign.center,
      );
      
      currentY = _drawText(
        canvas,
        'English test: Hello',
        x: _padding,
        y: currentY,
        fontSize: _fontSize,
        textAlign: TextAlign.center,
      );
      
      final now = DateTime.now();
      final dateTime = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      currentY = _drawText(
        canvas,
        dateTime,
        x: _padding,
        y: currentY,
        fontSize: _fontSize - 4,
        textAlign: TextAlign.center,
      );
      
      final picture = recorder.endRecording();
      final img = await picture.toImage(
        (_thermalPrinterWidth * _pixelRatio).round(),
        (height * _pixelRatio).round(),
      );
      
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
      
    } catch (e) {
      debugPrint('Error generating test image: $e');
      return null;
    }
  }
  // Generate Report Image for thermal printing
  static Future<Uint8List?> _generateReportImage({
    required Map<String, dynamic> reportData,
    required String reportTitle,
    required String dateRange,
    required Map<String, String> businessInfo,
  }) async {
    try {
      final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
      final revenue = reportData['revenue'] ?? {};
      final paymentTotals = reportData['paymentTotals'] as Map<String, dynamic>? ?? {};
      final serviceTypeSales = reportData['serviceTypeSales'] as List? ?? [];
      
      // Check for Arabic content
      bool hasArabicContent = _containsArabic(businessInfo['name']!) || 
                            _containsArabic(businessInfo['second_name']!) ||
                            _containsArabic(reportTitle) ||
                            serviceTypeSales.any((service) => _containsArabic(service['serviceType']?.toString() ?? ''));

        // Calculate exact content height with more padding
        double contentHeight = _padding ; // Start with more top padding
           // ADD THIS LINE - Calculate logo height if enabled:
          contentHeight += await _calculateLogoHeight();
        // Business header
        final businessNamePainter = _createTextPainter(
          businessInfo['name']!,
          fontSize: _largeFontSize - 4,
          fontWeight: FontWeight.bold,
        );
        contentHeight += businessNamePainter.height + 8; // Increased spacing

        if (businessInfo['second_name']!.isNotEmpty) {
          final secondNamePainter = _createTextPainter(
            businessInfo['second_name']!,
            fontSize: _fontSize + 2,
            fontWeight: FontWeight.bold,
          );
          contentHeight += secondNamePainter.height + 8; // Increased
        }

        contentHeight += 12; // More space after business info

        // Report title
        final titlePainter = _createTextPainter(
          reportTitle,
          fontSize: _fontSize ,
          fontWeight: FontWeight.bold,
        );
        contentHeight += titlePainter.height + 8; // Increased

        // Date range
        final datePainter = _createTextPainter(
          dateRange,
          fontSize: _fontSize - 2,
        );
        contentHeight += datePainter.height + 12; // Increased

        contentHeight += 2 + 12; // Line + more space

        // Cash and Bank Sales Section
        final cashBankHeaderPainter = _createTextPainter(
          'Cash and Bank Sales',
          fontSize: _fontSize - 2,
          fontWeight: FontWeight.bold,
        );
        contentHeight += cashBankHeaderPainter.height + 10; // Increased

        contentHeight += 2 + 8; // Line + space

        // Payment table header and all rows - be more generous
        contentHeight += (_fontSize - 2) + 8; // Header row
        contentHeight += 2 + 6; // Line + space
        contentHeight += ((_fontSize - 2) + 10) * 4; // 4 payment rows with more space
        contentHeight += 2 + 15; // Line + more space

        // Total Sales Section
        final totalSalesHeaderPainter = _createTextPainter(
          'Total Sales',
          fontSize: _fontSize - 2,
          fontWeight: FontWeight.bold,
        );
        contentHeight += totalSalesHeaderPainter.height + 10; // Increased

        contentHeight += 2 + 8; // Line + space

        // Service type header
        contentHeight += (_fontSize - 2) + 8; // Header with more space
        contentHeight += 2 + 6; // Line + space

        // Service type rows - calculate with more generous spacing
        if (serviceTypeSales.isNotEmpty) {
          for (var service in serviceTypeSales) {
            final serviceTypePainter = _createTextPainter(
              service['serviceType']?.toString() ?? '',
              fontSize: _fontSize - 4,
              maxWidth: _thermalPrinterWidth * 0.5,
            );
            contentHeight += serviceTypePainter.height + 8; // More space per row
          }
        } else {
          contentHeight += (_fontSize - 2) + 10; // "No sales data" message
        }

        contentHeight += 2 + 15; // Line + generous space

        // Revenue Breakdown Section  
        final revenueHeaderPainter = _createTextPainter(
          'Revenue Breakdown',
          fontSize: _fontSize - 2,
          fontWeight: FontWeight.bold,
        );
        contentHeight += revenueHeaderPainter.height + 10; // Increased

        contentHeight += 2 + 8; // Line + space

        // Revenue rows (Subtotal, Tax, Discounts, Total) - generous spacing
        contentHeight += ((_fontSize - 2) + 8) * 4; // 4 revenue rows with more space

        contentHeight += 2 + 12; // Line + space

        // Footer - generous spacing
        // contentHeight += (_fontSize - 2) + 8; // "End of Report"
        // final generateTimePainter = _createTextPainter(
        //   'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
        //   fontSize: _fontSize - 4,
        // );
        // contentHeight += generateTimePainter.height + 10;

        // Arabic footer if needed
        if (hasArabicContent) {
          contentHeight += 12;
          final arabicEndPainter = _createTextPainter(
            'نهاية التقرير',
            fontSize: _fontSize - 2,
          );
          contentHeight += arabicEndPainter.height + 10;
        }

        contentHeight += _padding * 26; // Much more bottom padding to ensure everything fits
      // Create canvas
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, _thermalPrinterWidth, contentHeight));

      // White background
      final backgroundPaint = ui.Paint()..color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, _thermalPrinterWidth, contentHeight),
        backgroundPaint,
      );
      
      double currentY = _padding;
      
      // Draw logo if available
      currentY = await _drawLogo(canvas, currentY);

      // Draw business header
      currentY = _drawText(
        canvas,
        businessInfo['name']!,
        x: _padding,
        y: currentY,
        fontSize: _largeFontSize - 4,
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.center,
      );
      
      if (businessInfo['second_name']!.isNotEmpty) {
        currentY = _drawText(
          canvas,
          businessInfo['second_name']!,
          x: _padding,
          y: currentY,
          fontSize: _fontSize + 2,
          fontWeight: FontWeight.bold,
          textAlign: TextAlign.center,
        );
      }
      
      currentY += 6;
      
      // Report title and date
      currentY = _drawText(
        canvas,
        reportTitle,
        x: _padding,
        y: currentY,
        fontSize: _fontSize,
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.center,
      );
      
      currentY = _drawText(
        canvas,
        dateRange,
        x: _padding,
        y: currentY,
        fontSize: _fontSize - 2,
        textAlign: TextAlign.center,
      );
      
      currentY += 6;
      currentY = _drawLine(canvas, currentY);
      
      // Cash and Bank Sales Section
      currentY = _drawText(
        canvas,
        'Cash and Bank Sales',
        x: _padding,
        y: currentY,
        fontSize: _fontSize - 2,
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.center,
      );
      
      currentY = _drawLine(canvas, currentY);
      
      // Payment table header
      currentY = _drawReportRow(canvas, [
        {'text': 'Method', 'width': 0.33, 'bold': true},
        {'text': 'Revenue', 'width': 0.33, 'bold': true, 'align': 'right'},
        {'text': 'Expenses', 'width': 0.35, 'bold': true, 'align': 'right'},
      ], currentY);
      
      currentY = _drawLine(canvas, currentY);
      
      // Payment rows
      currentY = _drawReportRow(canvas, [
        {'text': 'Cash Sales', 'width': 0.33},
        {'text': currencyFormat.format(_getPaymentValue(paymentTotals, 'cash', 'sales')), 'width': 0.33, 'align': 'right'},
        {'text': currencyFormat.format(_getPaymentValue(paymentTotals, 'cash', 'expenses')), 'width': 0.35, 'align': 'right'},
      ], currentY);
      
      currentY = _drawReportRow(canvas, [
        {'text': 'Bank Sales', 'width': 0.33},
        {'text': currencyFormat.format(_getPaymentValue(paymentTotals, 'bank', 'sales')), 'width': 0.33, 'align': 'right'},
        {'text': currencyFormat.format(_getPaymentValue(paymentTotals, 'bank', 'expenses')), 'width': 0.35, 'align': 'right'},
      ], currentY);
      
      currentY = _drawLine(canvas, currentY);
      
      currentY = _drawReportRow(canvas, [
        {'text': 'Total', 'width': 0.33, 'bold': true},
        {'text': currencyFormat.format(_getPaymentValue(paymentTotals, 'total', 'sales')), 'width': 0.33, 'align': 'right', 'bold': true},
        {'text': currencyFormat.format(_getPaymentValue(paymentTotals, 'total', 'expenses')), 'width': 0.35, 'align': 'right', 'bold': true},
      ], currentY);
      
      // Balance
      final totalRevenue = _getPaymentValue(paymentTotals, 'total', 'sales');
      final totalExpenses = _getPaymentValue(paymentTotals, 'total', 'expenses');
      final balance = totalRevenue - totalExpenses;
      
      currentY = _drawReportRow(canvas, [
        {'text': 'Balance', 'width': 0.66, 'bold': true},
        {'text': currencyFormat.format(balance), 'width': 0.34, 'align': 'right', 'bold': true},
      ], currentY);
      
      currentY +=8;
      
      // Total Sales Section
      currentY = _drawText(
        canvas,
        'Total Sales',
        x: _padding,
        y: currentY,
        fontSize: _fontSize - 2,
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.center,
      );
      
      currentY = _drawLine(canvas, currentY);
      
      if (serviceTypeSales.isNotEmpty) {
        // Service type header
        currentY = _drawReportRow(canvas, [
          {'text': 'Service Type', 'width': 0.33, 'bold': true},
          {'text': 'Orders', 'width': 0.33, 'bold': true, 'align': 'center'},
          {'text': 'Revenue', 'width': 0.34, 'bold': true, 'align': 'right'},
        ], currentY);
        
        currentY = _drawLine(canvas, currentY);
        
        for (var service in serviceTypeSales) {
          final serviceType = service['serviceType']?.toString() ?? '';
          final totalOrders = service['totalOrders'] as int? ?? 0;
          final totalRevenue = service['totalRevenue'] as double? ?? 0.0;
          
          currentY = _drawReportRow(canvas, [
            {'text': serviceType, 'width': 0.33},
            {'text': '$totalOrders', 'width': 0.33, 'align': 'center'},
            {'text': currencyFormat.format(totalRevenue), 'width': 0.34, 'align': 'right'},
          ], currentY);
        }
      } else {
        currentY = _drawText(
          canvas,
          'No sales data available',
          x: _padding,
          y: currentY,
          fontSize: _fontSize - 2,
          textAlign: TextAlign.center,
        );
      }
      
      currentY += 8;
      
      // Revenue Breakdown Section
      currentY = _drawText(
        canvas,
        'Revenue Breakdown',
        x: _padding,
        y: currentY,
        fontSize: _fontSize - 2,
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.center,
      );
      
      currentY = _drawLine(canvas, currentY);
      
      // Revenue rows
      currentY = _drawReportRow(canvas, [
        {'text': 'Subtotal:', 'width': 0.66, 'align': 'right'},
        {'text': currencyFormat.format(revenue['subtotal'] as double? ?? 0.0), 'width': 0.34, 'align': 'right'},
      ], currentY);
      
      currentY = _drawReportRow(canvas, [
        {'text': 'Tax:', 'width': 0.66, 'align': 'right'},
        {'text': currencyFormat.format(revenue['tax'] as double? ?? 0.0), 'width': 0.34, 'align': 'right'},
      ], currentY);
      
      currentY = _drawReportRow(canvas, [
        {'text': 'Discounts:', 'width': 0.66, 'align': 'right'},
        {'text': currencyFormat.format(revenue['discounts'] as double? ?? 0.0), 'width': 0.34, 'align': 'right'},
      ], currentY);
      
      currentY = _drawLine(canvas, currentY);
      
      currentY = _drawReportRow(canvas, [
        {'text': 'Total Revenue:', 'width': 0.66, 'align': 'right', 'bold': true},
        {'text': currencyFormat.format(revenue['total'] as double? ?? 0.0), 'width': 0.34, 'align': 'right', 'bold': true},
      ], currentY);
      
      // Footer
      currentY += 8;
      currentY = _drawLine(canvas, currentY);
      
      currentY = _drawText(
        canvas,
        'End of Report',
        x: _padding,
        y: currentY,
        fontSize: _fontSize - 2,
        textAlign: TextAlign.center,
      );
      
      // currentY = _drawText(
      //   canvas,
      //   'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
      //   x: _padding,
      //   y: currentY,
      //   fontSize: _fontSize - 4,
      //   textAlign: TextAlign.center,
      // );
      
      // Arabic footer if needed
      // if (hasArabicContent) {
      //   currentY += 6;
      //   currentY = _drawText(
      //     canvas,
      //     'نهاية التقرير',
      //     x: _padding,
      //     y: currentY,
      //     fontSize: _fontSize - 2,
      //     textAlign: TextAlign.center,
      //   );
      // }
      
      // Create final image
      final picture = recorder.endRecording();
      final img = await picture.toImage(
        (_thermalPrinterWidth * _pixelRatio).round(),
        (contentHeight * _pixelRatio).round(),
      );

      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
      
    } catch (e) {
      debugPrint('Error generating report image: $e');
      return null;
    }
  }

  // Helper method to draw report rows
  static double _drawReportRow(ui.Canvas canvas, List<Map<String, dynamic>> columns, double y) {
    double currentX = _padding;
    double maxHeight = 0;
    
    for (var column in columns) {
      final text = column['text'] as String;
      final width = column['width'] as double;
      final bold = column['bold'] as bool? ?? false;
      final align = column['align'] as String? ?? 'left';
      
      final columnWidth = (_thermalPrinterWidth - (_padding * 2)) * width;
      
      final textPainter = _createTextPainter(
        text,
        fontSize: _fontSize - 2,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        maxWidth: columnWidth,
      );
      
      double drawX = currentX;
      if (align == 'center') {
        drawX = currentX + (columnWidth - textPainter.width) / 2;
      } else if (align == 'right') {
        drawX = currentX + columnWidth - textPainter.width;
      }
      
      textPainter.paint(canvas, Offset(drawX, y));
      
      maxHeight = maxHeight > textPainter.height ? maxHeight : textPainter.height;
      currentX += columnWidth;
    }
    
    return y + maxHeight + 6;
  }
  // Helper method to get payment values (add this if not already present)
  static double _getPaymentValue(Map<String, dynamic> paymentTotals, String method, String type) {
    try {
      return (paymentTotals[method] as Map<String, dynamic>?)?[type] as double? ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }
  // Main report printing method
  static Future<bool> printThermalReport({
    required Map<String, dynamic> reportData,
    required String reportTitle,
    required String dateRange,
  }) async {
    try {
      debugPrint('Printing thermal report as image');
      
      final businessInfo = await getBusinessInfo();
      
      final imageBytes = await _generateReportImage(
        reportData: reportData,
        reportTitle: reportTitle,
        dateRange: dateRange,
        businessInfo: businessInfo,
      );
      
      if (imageBytes == null) {
        debugPrint('Failed to generate report image');
        return false;
      }
      
      return await _printImage(imageBytes, isKot: false);
      
    } catch (e) {
      debugPrint('Error printing thermal report: $e');
      return false;
    }
  }
  // Process image in a separate isolate to avoid blocking the UI thread
  // static img.Image? _processImageOnIsolate(Uint8List imageBytes) {
  //   try {
  //     final image = img.decodeImage(imageBytes);
  //     if (image == null) return null;

  //     // Resize to proper thermal printer width (512 pixels for 80mm at 8 dots/mm)
  //     final resized = img.copyResize(image, width: 512);
      
  //     // Convert to black and white for better contrast
  //     return img.grayscale(resized);
  //   } catch (e) {
  //     debugPrint('Error processing image on isolate: $e');
  //     return null;
  //   }
  // }

}