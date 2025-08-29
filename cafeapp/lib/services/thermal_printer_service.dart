
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';

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

  // Utility Methods
  static bool _containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  static TextDirection _getTextDirection(String text) {
    return _containsArabic(text) ? TextDirection.rtl : TextDirection.ltr;
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
      textDirection: textDirection,
      textAlign: textAlign,
      maxLines: null,
    );
    
    // Use full width minus minimal padding
    textPainter.layout(maxWidth: maxWidth - 32);
    return textPainter;
  }

  // Drawing Helper Methods
  static double _drawText(
    Canvas canvas,
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

  static double _drawLine(Canvas canvas, double y, {double thickness = 4.0}) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = thickness;
    
    canvas.drawLine(
      Offset(_padding, y),
      Offset(_thermalPrinterWidth - _padding, y),
      paint,
    );
    
    return y + thickness + 8;
  }

  static double _drawItemsHeader(Canvas canvas, double y) {
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
  static double _drawItemRow(Canvas canvas, MenuItem item, double y) {
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
static double _drawTotalRow(Canvas canvas, String label, String value, double y, {bool isTotal = false}) {
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
    
    // Header section
    final receiptPainter = _createTextPainter(
      'RECEIPT',
      fontSize: _largeFontSize - 6,
      fontWeight: FontWeight.bold,
    );
    contentHeight += receiptPainter.height + 2; // Title + spacing + extra
    
    final businessNamePainter = _createTextPainter(
      businessInfo['name']!,
      fontSize: _largeFontSize - 2,
      fontWeight: FontWeight.bold,
    );
    contentHeight += businessNamePainter.height + 2;
    
    // Second business name
    if (businessInfo['second_name']!.isNotEmpty) {
      final secondNamePainter = _createTextPainter(
        businessInfo['second_name']!,
        fontSize: _smallFontSize + 2,
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
    
    // EDITED marker
    if (isEdited) {
      final editedPainter = _createTextPainter(
        'EDITED',
        fontSize: _fontSize - 4,
        fontWeight: FontWeight.bold,
      );
      contentHeight += editedPainter.height + 6 + 2; // Text + border padding + spacing
    }
    
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
    contentHeight += _fontSize - 4 + 8; // Subtotal
    contentHeight += _fontSize - 4 + 8; // Tax

    if (discount > 0) {
      contentHeight += _fontSize - 4 + 8; // Discount
    }
    
    contentHeight += 2 + 6; // Line before total
    contentHeight += _fontSize + 8; // Total
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
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, _thermalPrinterWidth, contentHeight));
    
    // White background
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _thermalPrinterWidth, contentHeight),
      backgroundPaint,
    );
    
    double currentY = _padding;
    
    // Header
    currentY = _drawText(
      canvas,
      'RECEIPT',
      x: _padding,
      y: currentY,
      fontSize: _largeFontSize - 6,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
    );
    
    currentY -= 5;
    
    // Business name
    currentY = _drawText(
      canvas,
      businessInfo['name']!,
      x: _padding,
      y: currentY,
      fontSize: _fontSize,
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
        fontSize: _smallFontSize,
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
    
    // EDITED marker
    if (isEdited) {
      final editedPainter = _createTextPainter(
        'EDITED',
        fontSize: _fontSize - 4,
        fontWeight: FontWeight.bold,
      );
      
      final editedX = (_thermalPrinterWidth - editedPainter.width) / 2;
      final borderRect = Rect.fromLTWH(
        editedX - 10,
        currentY - 5,
        editedPainter.width + 20,
        editedPainter.height + 10,
      );
      
      final borderPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      canvas.drawRect(borderRect, borderPaint);
      
      currentY = _drawText(
        canvas,
        'EDITED',
        x: _padding,
        y: currentY,
        fontSize: _fontSize - 4,
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.center,
      );

      currentY -= 6;
    }
    
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
    
    if (discount > 0) {
      currentY = _drawTotalRow(canvas, 'Discount:', discount.toStringAsFixed(3), currentY);
    }
    
    currentY = _drawLine(canvas, currentY);
    currentY = _drawTotalRow(canvas, 'TOTAL:', total.toStringAsFixed(3), currentY, isTotal: true);
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
}) async {
  try {
    final now = DateTime.now();
    final billNumber = orderNumber ?? '${now.millisecondsSinceEpoch % 10000}';
    
    // First pass: Calculate the exact content height
    double contentHeight = _padding; // Start with top padding
    
    // Header content
    final headerPainter1 = _createTextPainter(
      'KITCHEN ORDER',
      fontSize: _largeFontSize - 6,
      fontWeight: FontWeight.bold,
    );
    contentHeight += headerPainter1.height + 8; // Title + spacing
    
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
    
    contentHeight += 10; // Space before first line
    contentHeight += 4; // First line thickness
    
    // Items header
    contentHeight += _smallFontSize + 8; // Item/Qty header + spacing
    contentHeight += 4; // Second line thickness
    
    // Calculate items height precisely
    for (final item in items) {
      final itemNamePainter = _createTextPainter(
        item.name,
        fontSize: _smallFontSize,
        maxWidth: _thermalPrinterWidth * 0.7,
      );
      contentHeight += itemNamePainter.height + 8; // Item name + spacing
      
      if (item.kitchenNote.isNotEmpty) {
        final notePainter = _createTextPainter(
          'NOTE: ${item.kitchenNote}',
          fontSize: _smallFontSize - 2,
          maxWidth: _thermalPrinterWidth * 0.8,
        );
        contentHeight += notePainter.height + 8; // Kitchen note + spacing
      }
      
      contentHeight += 10; // Space between items
    }
    
    contentHeight += 4; // Final line thickness only (no extra spacing)
    
    // Create the canvas with exact height
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, _thermalPrinterWidth, contentHeight));
    
    final backgroundPaint = Paint()..color = Colors.white;
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
    
    // Items
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
    
    // Draw final line manually without extra spacing
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0;
    
    canvas.drawLine(
      Offset(_padding, currentY),
      Offset(_thermalPrinterWidth - _padding, currentY),
      paint,
    );
    
    // Don't add any extra spacing after the final line

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

  // Print Image to Printer - Fixed width handling
  static Future<bool> _printImage(Uint8List imageBytes, {bool isKot = false}) async {
    try {
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
      final result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 5));
      
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
      
      await Future.delayed(const Duration(milliseconds: 500));
      printer.disconnect();
      
      debugPrint('${isKot ? 'KOT' : 'Receipt'} printed successfully');
      return true;
      
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
  }) async {
    return await printKotReceipt(
      serviceType: serviceType,
      items: items,
      tableInfo: tableInfo,
      orderNumber: orderNumber,
    );
  }

  // Test Methods
  static Future<bool> testConnection() async {
    try {
      final ip = await getPrinterIp();
      final port = await getPrinterPort();
      
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      
      final result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 3));
      
      if (result == PosPrintResult.success) {
        // Generate test image
        final testImage = await _generateTestImage();
        if (testImage != null) {
          final image = img.decodeImage(testImage);
          if (image != null) {
            final resized = img.copyResize(image, width: 576);
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

  static Future<bool> testKotConnection() async {
    try {
      final ip = await getKotPrinterIp();
      final port = await getKotPrinterPort();
      
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      
      final result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 3));
      
      if (result == PosPrintResult.success) {
        final testImage = await _generateTestImage(isKot: true);
        if (testImage != null) {
          final image = img.decodeImage(testImage);
          if (image != null) {
            final resized = img.copyResize(image, width: 576);
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
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, _thermalPrinterWidth, height));
      
      final backgroundPaint = Paint()..color = Colors.white;
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
          fontSize: _largeFontSize,
          fontWeight: FontWeight.bold,
          textAlign: TextAlign.center,
        );
      } else {
        currentY = _drawText(
          canvas,
          'RECEIPT PRINTER TEST',
          x: _padding,
          y: currentY,
          fontSize: _largeFontSize,
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
        fontSize: _smallFontSize,
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
}