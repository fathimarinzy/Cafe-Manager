import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../repositories/local_order_repository.dart';
import '../repositories/local_expense_repository.dart';
import '../models/order.dart';
import '../services/thermal_printer_service.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/app_localization.dart';
import '../utils/service_type_utils.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'dart:convert'; // For utf8 encoding

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final LocalOrderRepository _orderRepo = LocalOrderRepository();
  final LocalExpenseRepository _expenseRepo = LocalExpenseRepository();
  
  bool _isLoading = false;
  Map<String, dynamic>? _reportData;
  String _selectedReportType = 'daily';
  DateTime _selectedDate = DateTime.now();
  
  // Cache to store previously loaded reports
  final Map<String, Map<String, dynamic>> _reportCache = {};
  
  // Date range for custom period reports
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isCustomDateRange = false;
  bool _isPrinting = false;
  bool _isSavingPdf = false; // Add PDF saving state

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime.now();
    _loadReport();
  }

  // Check if text contains Arabic characters
  static bool _containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  // Check if ANY content in the report contains Arabic
  // bool _hasArabicContent(Map<String, String> businessInfo, List<dynamic> serviceTypeSales) {
  //   // Check business info
  //   if (_containsArabic(businessInfo['name'] ?? '') ||
  //       _containsArabic(businessInfo['second_name'] ?? '') ||
  //       _containsArabic(businessInfo['address'] ?? '')) {
  //     return true;
  //   }

  //   // Check service type sales
  //   for (var service in serviceTypeSales) {
  //     final serviceType = service['serviceType']?.toString() ?? '';
  //     if (_containsArabic(serviceType)) {
  //       return true;
  //     }
  //   }

  //   return false;
  // }

  // Process text for printing (handle Arabic)
  // String _processTextForPrinting(String text, bool useArabicMode) {
  //   if (!_containsArabic(text) || !useArabicMode) {
  //     return text;
  //   }
  //   try {
  //     return text; // Most modern printers can handle UTF-8 with proper codepage
  //   } catch (e) {
  //     debugPrint('Error processing Arabic text: $e');
  //     return text;
  //   }
  // }

  // // Get appropriate text alignment for text
  // PosAlign _getTextAlign(String text, PosAlign defaultAlign) {
  //   if (_containsArabic(text)) {
  //     if (defaultAlign == PosAlign.left) return PosAlign.right;
  //     if (defaultAlign == PosAlign.right) return PosAlign.right;
  //     return defaultAlign;
  //   }
  //   return defaultAlign;
  // }

  // Load Arabic-compatible font for PDF
  Future<pw.Font?> _loadArabicFont() async {
    try {
      final fontData = await rootBundle.load("assets/fonts/cairo-regular.ttf");
      return pw.Font.ttf(fontData.buffer.asByteData());
    } catch (e) {
      try {
        final fontData = await rootBundle.load("assets/fonts/noto-sans-arabic.ttf");
        return pw.Font.ttf(fontData.buffer.asByteData());
      } catch (e2) {
        try {
          final fontData = await rootBundle.load("assets/fonts/amiri-regular.ttf");
          return pw.Font.ttf(fontData.buffer.asByteData());
        } catch (e3) {
          debugPrint('Could not load any Arabic font: $e3');
          return null;
        }
      }
    }
  }

  // Get appropriate text direction for Arabic text
  pw.TextDirection _getTextDirection(String text) {
    return _containsArabic(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  }

  // Create text widget with proper direction and font for PDF
  pw.Widget _createText(
    String text, {
    pw.Font? arabicFont,
    pw.Font? fallbackFont,
    pw.TextStyle? style,
    pw.TextAlign? textAlign,
  }) {
    final textDirection = _getTextDirection(text);
    final useArabicFont = _containsArabic(text) && arabicFont != null;
    
    return pw.Directionality(
      textDirection: textDirection,
      child: pw.Text(
        text,
        style: style?.copyWith(
          font: useArabicFont ? arabicFont : (style.font ?? fallbackFont),
        ) ?? pw.TextStyle(
          font: useArabicFont ? arabicFont : fallbackFont,
        ),
        textAlign: textAlign,
        textDirection: textDirection,
      ),
    );
  }

  // Save PDF directly method
  Future<void> _savePdfDirectly() async {
    if (_reportData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No report data available to save'.tr())),
      );
      return;
    }
    
    setState(() {
      _isSavingPdf = true;
    });

    try {
      final pdf = await _generateReportPdf();
      
      String filename;
      if (_selectedReportType == 'daily') {
        filename = 'Report_${DateFormat('dd-MM-yyyy').format(_selectedDate)}';
      } else if (_selectedReportType == 'monthly') {
        filename = 'Report_${DateFormat('MMMM_yyyy').format(_startDate)}';
      } else {
        filename = 'Report_${DateFormat('dd-MM-yyyy').format(_startDate)}_to_${DateFormat('dd-MM-yyyy').format(_endDate)}';
      }
      
      filename = filename.replaceAll(' ', '_');
      final saved = await _saveWithAndroidIntent(pdf, filename);

      if (mounted) {
        if (saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Report saved as PDF successfully'.tr())),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save report as PDF'.tr())),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PDF'.tr())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPdf = false;
        });
      }
    }
  }

  // Print report method
  Future<void> _printReport() async {
    if (_reportData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No report data available to print'.tr())),
      );
      return;
    }
    
    setState(() {
      _isPrinting = true;
    });

    try {
      final printed = await _printThermalReport();
      
      if (mounted) {
        if (printed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Report printed successfully'.tr())),
          );
        } else {
          final shouldSave = await _showPrintFailedDialog();
          if (shouldSave == true) {
            await _savePdfFallback();
          }
        }
      }
    } catch (e) {
      debugPrint('Error printing report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing report'.tr())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  // Show dialog when printing fails
  Future<bool?> _showPrintFailedDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Printer Not Available'.tr()),
          content: Text('Could not connect to the thermal printer. Would you like to save the report as a PDF instead?'.tr()),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'.tr()),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Save PDF'.tr()),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }
// Method 1: Direct raw bytes approach (bypasses library validation)
Future<bool> _printArabicDirect(NetworkPrinter printer, String arabicText, {PosStyles? styles}) async {
  try {
    debugPrint('Printing Arabic text directly: "$arabicText"');
    
    // Set CP1256 codepage (your printer uses codepage 32 for CP1256)
    final List<int> setCP1256 = [0x1B, 0x74, 32]; // ESC t 32
    printer.rawBytes(Uint8List.fromList(setCP1256));
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Set right-to-left alignment for Arabic
    if (_containsArabic(arabicText)) {
      printer.rawBytes(Uint8List.fromList([0x1B, 0x61, 0x02])); // Right align
    } else if (styles?.align == PosAlign.center) {
      printer.rawBytes(Uint8List.fromList([0x1B, 0x61, 0x01])); // Center
    }
    
    // Apply bold formatting if needed
    if (styles?.bold == true) {
      printer.rawBytes(Uint8List.fromList([0x1B, 0x45, 0x01])); // Bold ON
    }
    
    // Convert Arabic text to CP1256 bytes
    final arabicBytes = _convertToCP1256(arabicText);
    if (arabicBytes != null) {
      printer.rawBytes(arabicBytes);
      printer.rawBytes(Uint8List.fromList([0x0A])); // Line feed
      
      // Reset formatting
      if (styles?.bold == true) {
        printer.rawBytes(Uint8List.fromList([0x1B, 0x45, 0x00])); // Bold OFF
      }
      printer.rawBytes(Uint8List.fromList([0x1B, 0x61, 0x00])); // Left align
      
      return true;
    }
    
    return false;
  } catch (e) {
    debugPrint('Arabic direct printing failed: $e');
    return false;
  }
}

// Enhanced CP1256 conversion based on your printer's codepage support
Uint8List? _convertToCP1256(String text) {
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
        // For unknown characters, use a space or question mark
        bytes.add(0x20); // Space
      }
    }
    
    return Uint8List.fromList(bytes);
  } catch (e) {
    debugPrint('Error converting to CP1256: $e');
    return null;
  }
}

// Safe text printing method that bypasses library validation
Future<bool> _safePrintText(NetworkPrinter printer, String text, {PosStyles? styles}) async {
  try {
    // Check if text contains Arabic
    if (_containsArabic(text)) {
      debugPrint('Text contains Arabic, using direct printing: "$text"');
      return await _printArabicDirect(printer, text, styles: styles);
    }
    
    // For non-Arabic text, use normal library method
    String cleanText = _cleanTextForPrinting(text);
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

// Enhanced row printing with raw bytes fallback
Future<bool> _safePrintRow(NetworkPrinter printer, List<PosColumn> columns) async {
  try {
    // Check if any column contains Arabic
    bool hasArabic = columns.any((col) => _containsArabic(col.text));
    
    if (hasArabic) {
      debugPrint('Row contains Arabic, using manual spacing');
      
      // Calculate total width (assuming 48 characters for 80mm paper)
      const int totalWidth = 48;
      String rowText = '';
      
      for (int i = 0; i < columns.length; i++) {
        final column = columns[i];
        final columnWidth = (column.width * totalWidth / 12).round(); // Convert to actual characters
        
        String text = _cleanTextForPrinting(column.text);
        
        // Handle Arabic text alignment
        if (_containsArabic(text)) {
          // For Arabic, we'll print it separately with right alignment
          if (rowText.isNotEmpty) {
            await _safePrintText(printer, rowText.trimRight());
            rowText = '';
          }
          
          // Print Arabic text with proper alignment
          await _printArabicDirect(printer, text, styles: column.styles);
          continue;
        } else {
          // For English text, add to row with spacing
          if (column.styles.align == PosAlign.right) {
            text = text.padLeft(columnWidth);
          } else if (column.styles.align == PosAlign.center) {
            final padding = (columnWidth - text.length) ~/ 2;
            text = text.padLeft(text.length + padding).padRight(columnWidth);
          } else {
            text = text.padRight(columnWidth);
          }
          
          rowText += text;
        }
      }
      
      // Print any remaining English text
      if (rowText.isNotEmpty) {
        await _safePrintText(printer, rowText.trimRight());
      }
      
      return true;
    } else {
      // No Arabic, try normal row printing first
      try {
        List<PosColumn> cleanColumns = columns.map((col) {
          return PosColumn(
            text: _cleanTextForPrinting(col.text),
            width: col.width,
            styles: col.styles,
          );
        }).toList();
        
        printer.row(cleanColumns);
        return true;
      } catch (e) {
        debugPrint('Normal row printing failed, using fallback: $e');
        
        // Fallback to manual spacing
        String rowText = '';
        const int totalWidth = 48;
        
        for (final column in columns) {
          final columnWidth = (column.width * totalWidth / 12).round();
          String text = _cleanTextForPrinting(column.text);
          
          if (column.styles.align == PosAlign.right) {
            text = text.padLeft(columnWidth);
          } else if (column.styles.align == PosAlign.center) {
            final padding = (columnWidth - text.length) ~/ 2;
            text = text.padLeft(text.length + padding).padRight(columnWidth);
          } else {
            text = text.padRight(columnWidth);
          }
          
          rowText += text;
        }
        
        await _safePrintText(printer, rowText.trimRight());
        return true;
      }
    }
  } catch (e) {
    debugPrint('All row printing methods failed: $e');
    return false;
  }
}

// Enhanced printer setup for EVERYCOM
Future<bool> _setupArabicPrinter(NetworkPrinter printer) async {
  try {
    debugPrint('Setting up EVERYCOM printer for Arabic support');
    
    // Initialize printer
    printer.rawBytes(Uint8List.fromList([0x1B, 0x40])); // ESC @ - Initialize
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Set CP1256 codepage (your printer supports this as codepage 32)
    printer.rawBytes(Uint8List.fromList([0x1B, 0x74, 32])); // ESC t 32 (CP1256)
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Set international character set to Arabic
    printer.rawBytes(Uint8List.fromList([0x1B, 0x52, 0x0D])); // ESC R 13 (Arabic)
    await Future.delayed(const Duration(milliseconds: 100));
    
    debugPrint('EVERYCOM printer setup completed for Arabic');
    return true;
  } catch (e) {
    debugPrint('Arabic printer setup failed: $e');
    return false;
  }
}
 // Replace the _printThermalReport method in your ReportScreen class
 Future<bool> _printThermalReport() async {
  try {
    final ip = await ThermalPrinterService.getPrinterIp();
    final port = await ThermalPrinterService.getPrinterPort();
    final businessInfo = await ThermalPrinterService.getBusinessInfo();
    
    // Initialize printer
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);
    
    debugPrint('Connecting to  printer at $ip:$port for report');
    final PosPrintResult result = await printer.connect(ip, port: port, timeout: const Duration(seconds: 5));
    
    if (result != PosPrintResult.success) {
      debugPrint('Failed to connect to printer: ${result.msg}');
      return false;
    }

    // Setup printer for Arabic
    await _setupArabicPrinter(printer);
    
    // Print business header
    await _safePrintText(printer, businessInfo['name']!, styles: PosStyles(
      align: _containsArabic(businessInfo['name']!) ? PosAlign.right : PosAlign.center,
      bold: true, 
      height: PosTextSize.size2
    ));
    
    if (businessInfo['second_name']!.isNotEmpty) {
      await _safePrintText(printer, businessInfo['second_name']!, styles: PosStyles(
        align: _containsArabic(businessInfo['second_name']!) ? PosAlign.right : PosAlign.center,
        bold: true, 
        height: PosTextSize.size1
      ));
    }
    
    await _safePrintText(printer, '');
    
    // Get report data
    String reportTitle;
    String dateRangeText;
    
    if (_selectedReportType == 'daily') {
      reportTitle = 'Daily Report'.tr();
      dateRangeText = DateFormat('dd MMM yyyy').format(_selectedDate);
    } else if (_selectedReportType == 'monthly') {
      reportTitle = 'Monthly Report'.tr();
      dateRangeText = DateFormat('MMMM yyyy').format(_startDate);
    } else {
      reportTitle = 'Monthly Report'.tr();
      dateRangeText = '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}';
    }
    
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
    final revenue = _reportData!['revenue'] ?? {};
    final paymentTotals = _reportData!['paymentTotals'] as Map<String, dynamic>? ?? {};
    final serviceTypeSales = _reportData!['serviceTypeSales'] as List? ?? [];
    
    // Print report title and date
    await _safePrintText(printer, reportTitle, styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1));
    await _safePrintText(printer, dateRangeText, styles: const PosStyles(align: PosAlign.center));
    
    // Print separator
    printer.rawBytes(Uint8List.fromList(List.filled(32, '='.codeUnitAt(0)) + [0x0A]));
    
    // Cash and Bank Sales Section
    await _safePrintText(printer, 'Cash and Bank Sales'.tr(), styles: const PosStyles(align: PosAlign.center, bold: true));
    printer.rawBytes(Uint8List.fromList(List.filled(32, '='.codeUnitAt(0)) + [0x0A]));

    // Table headers
    await _safePrintRow(printer, [
      PosColumn(text: 'Method'.tr(), width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Revenue'.tr(), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
      PosColumn(text: 'Expenses'.tr(), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    
    printer.rawBytes(Uint8List.fromList(List.filled(32, '='.codeUnitAt(0)) + [0x0A]));

    // Cash row
    await _safePrintRow(printer, [
      PosColumn(text: 'Cash Sales'.tr(), width: 4),
      PosColumn(text: currencyFormat.format(_getPaymentValue(paymentTotals, 'cash', 'sales')), width: 4, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(text: currencyFormat.format(_getPaymentValue(paymentTotals, 'cash', 'expenses')), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    
    // Bank row
    await _safePrintRow(printer, [
      PosColumn(text: 'Bank Sales'.tr(), width: 4),
      PosColumn(text: currencyFormat.format(_getPaymentValue(paymentTotals, 'bank', 'sales')), width: 4, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(text: currencyFormat.format(_getPaymentValue(paymentTotals, 'bank', 'expenses')), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    
    printer.rawBytes(Uint8List.fromList(List.filled(32, '='.codeUnitAt(0)) + [0x0A]));
    
    // Total row
    await _safePrintRow(printer, [
      PosColumn(text: 'Total'.tr(), width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: currencyFormat.format(_getPaymentValue(paymentTotals, 'total', 'sales')), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
      PosColumn(text: currencyFormat.format(_getPaymentValue(paymentTotals, 'total', 'expenses')), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    
    // Balance row
    final totalRevenue = _getPaymentValue(paymentTotals, 'total', 'sales');
    final totalExpenses = _getPaymentValue(paymentTotals, 'total', 'expenses');
    final balance = totalRevenue - totalExpenses;
    
    await _safePrintRow(printer, [
      PosColumn(text: 'Balance'.tr(), width: 8, styles: const PosStyles(bold: true)),
      PosColumn(text: currencyFormat.format(balance), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    
    await _safePrintText(printer, '');
    
    // Service Type Sales Section
    await _safePrintText(printer, 'Total Sales'.tr(), styles: const PosStyles(align: PosAlign.center, bold: true));
    printer.rawBytes(Uint8List.fromList(List.filled(32, '='.codeUnitAt(0)) + [0x0A]));
    
    if (serviceTypeSales.isNotEmpty) {
      // Service type headers
      await _safePrintRow(printer, [
        PosColumn(text: 'Service Type'.tr(), width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Orders'.tr(), width: 3, styles: const PosStyles(bold: true, align: PosAlign.center)),
        PosColumn(text: 'Revenue'.tr(), width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      
      printer.rawBytes(Uint8List.fromList(List.filled(32, '='.codeUnitAt(0)) + [0x0A]));

      for (var service in serviceTypeSales) {
        final serviceType = service['serviceType']?.toString() ?? '';
        final totalOrders = service['totalOrders'] as int? ?? 0;
        final totalRevenue = service['totalRevenue'] as double? ?? 0.0;
        
        final translatedServiceType = _getTranslatedServiceType(serviceType);
        
        await _safePrintRow(printer, [
          PosColumn(
            text: translatedServiceType, 
            width: 6, 
            styles: PosStyles(
              align: _containsArabic(translatedServiceType) ? PosAlign.right : PosAlign.left
            )
          ),
          PosColumn(text: '$totalOrders', width: 3, styles: const PosStyles(align: PosAlign.center)),
          PosColumn(text: currencyFormat.format(totalRevenue), width: 3, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
    } else {
      await _safePrintText(printer, 'No sales data available'.tr(), styles: const PosStyles(align: PosAlign.center));
    }
    
    await _safePrintText(printer, '');
    
    // Revenue Breakdown Section
    await _safePrintText(printer, 'Revenue Breakdown'.tr(), styles: const PosStyles(align: PosAlign.center, bold: true));
    printer.rawBytes(Uint8List.fromList(List.filled(32, '='.codeUnitAt(0)) + [0x0A]));
    
    // Revenue breakdown rows
    await _safePrintRow(printer, [
      PosColumn(text: 'Subtotal:'.tr(), width: 8, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(text: currencyFormat.format(revenue['subtotal'] as double? ?? 0.0), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    
    await _safePrintRow(printer, [
      PosColumn(text: 'Tax:'.tr(), width: 8, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(text: currencyFormat.format(revenue['tax'] as double? ?? 0.0), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    
    await _safePrintRow(printer, [
      PosColumn(text: 'Discounts:'.tr(), width: 8, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(text: currencyFormat.format(revenue['discounts'] as double? ?? 0.0), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    
    printer.rawBytes(Uint8List.fromList(List.filled(32, '='.codeUnitAt(0)) + [0x0A]));
    
    await _safePrintRow(printer, [
      PosColumn(text: 'Total Revenue:'.tr(), width: 8, styles: const PosStyles(align: PosAlign.right, bold: true)),
      PosColumn(text: currencyFormat.format(revenue['total'] as double? ?? 0.0), width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    
    // Footer
    await _safePrintText(printer, '');
    printer.rawBytes(Uint8List.fromList(List.filled(32, '='.codeUnitAt(0)) + [0x0A]));
    
    await _safePrintText(printer, 'End of Report', styles: const PosStyles(align: PosAlign.center));
    await _safePrintText(printer, 'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}', styles: const PosStyles(align: PosAlign.center));

    // Cut paper
    await Future.delayed(const Duration(milliseconds: 800));
    printer.cut();
    await Future.delayed(const Duration(milliseconds: 1500));
    
    printer.disconnect();
    
    return true;
  } catch (e) {
    debugPrint('Error printing thermal report: $e');
    return false;
  }
}

// Also update the PDF generation method
Future<pw.Document> _generateReportPdf() async {
  final pdf = pw.Document();
  
  // Load fonts
  final arabicFont = await _loadArabicFont();
  pw.Font? fallbackFont;
  try {
    final fontData = await rootBundle.load("assets/fonts/open-sans.regular.ttf");
    fallbackFont = pw.Font.ttf(fontData.buffer.asByteData());
  } catch (e) {
    debugPrint('Could not load fallback font, using default: $e');
  }

  // Get business info
  if (!mounted) return pdf;
  final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
  final restaurantName = settingsProvider.businessName.isNotEmpty 
      ? settingsProvider.businessName 
      : 'SIMS CAFE';
  final secondBusinessName = settingsProvider.secondBusinessName.isNotEmpty 
      ? settingsProvider.secondBusinessName 
      : '';


  String reportTitle;
  String dateRangeText;
  
  if (_selectedReportType == 'daily') {
    reportTitle = 'Daily Report'.tr();
    dateRangeText = DateFormat('dd MMM yyyy').format(_selectedDate);
  } else if (_selectedReportType == 'monthly') {
    reportTitle = 'Monthly Report'.tr();
    dateRangeText = DateFormat('MMMM yyyy').format(_startDate);
  } else {
    reportTitle = 'Monthly Report'.tr();
    dateRangeText = '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}';
  }
  
  final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
  final revenue = _reportData!['revenue'] ?? {};
  final paymentTotals = _reportData!['paymentTotals'] as Map<String, dynamic>? ?? {};
  final serviceTypeSales = _reportData!['serviceTypeSales'] as List? ?? [];
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            _createText(
              restaurantName,
              arabicFont: arabicFont,
              fallbackFont: fallbackFont,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 3),
            if (secondBusinessName.isNotEmpty)
              _createText(
                secondBusinessName,
                arabicFont: arabicFont,
                fallbackFont: fallbackFont,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            pw.SizedBox(height: 10),
            _createText(
              reportTitle,
              arabicFont: arabicFont,
              fallbackFont: fallbackFont,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            _createText(
              dateRangeText,
              arabicFont: arabicFont,
              fallbackFont: fallbackFont,
              style: pw.TextStyle(fontSize: 12),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 5),
            pw.Divider(thickness: 1),
          ],
        );
      },
      footer: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 5),
            _createText(
              'Generated on ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
              arabicFont: arabicFont,
              fallbackFont: fallbackFont,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 5),
            _createText(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              arabicFont: arabicFont,
              fallbackFont: fallbackFont,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
          ],
        );
      },
      build: (pw.Context context) {
        return [
          pw.SizedBox(height: 15),
          
          // Payment Totals Section
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _createText(
                  'Cash and Bank Sales'.tr(),
                  arabicFont: arabicFont,
                  fallbackFont: fallbackFont,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    // Headers
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: _createText(
                            'Payment Method'.tr(),
                            arabicFont: arabicFont,
                            fallbackFont: fallbackFont,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: _createText(
                            'Revenue'.tr(),
                            arabicFont: arabicFont,
                            fallbackFont: fallbackFont,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: _createText(
                            'Expenses'.tr(),
                            arabicFont: arabicFont,
                            fallbackFont: fallbackFont,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    _buildPdfPaymentRow('Cash Sales'.tr(), 'cash', paymentTotals, currencyFormat, arabicFont, fallbackFont),
                    _buildPdfPaymentRow('Bank Sales'.tr(), 'bank', paymentTotals, currencyFormat, arabicFont, fallbackFont),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: _createText(
                            'Total'.tr(),
                            arabicFont: arabicFont,
                            fallbackFont: fallbackFont,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: _createText(
                            currencyFormat.format(_getPaymentValue(paymentTotals, 'total', 'sales')),
                            arabicFont: arabicFont,
                            fallbackFont: fallbackFont,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: _createText(
                            currencyFormat.format(_getPaymentValue(paymentTotals, 'total', 'expenses')),
                            arabicFont: arabicFont,
                            fallbackFont: fallbackFont,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _buildPdfBalanceRow(paymentTotals, currencyFormat, arabicFont, fallbackFont),   
              ],
            ),
          ),
          
          pw.SizedBox(height: 15),
          
          // Service Type Sales Section
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _createText(
                  'Total Sales'.tr(),
                  arabicFont: arabicFont,
                  fallbackFont: fallbackFont,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                serviceTypeSales.isEmpty
                  ? pw.Center(child: _createText(
                      'No sales data available'.tr(), 
                      arabicFont: arabicFont,
                      fallbackFont: fallbackFont,
                    ))
                  : pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: _createText(
                                'Service Type'.tr(),
                                arabicFont: arabicFont,
                                fallbackFont: fallbackFont,
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: _createText(
                                'Orders'.tr(),
                                arabicFont: arabicFont,
                                fallbackFont: fallbackFont,
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: _createText(
                                'Revenue'.tr(),
                                arabicFont: arabicFont,
                                fallbackFont: fallbackFont,
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        ...serviceTypeSales.map((service) => _buildPdfServiceTypeRow(service, currencyFormat, arabicFont, fallbackFont)),
                      ],
                    ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 15),
          
          // Revenue Breakdown Section
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _createText(
                  'Revenue Breakdown'.tr(),
                  arabicFont: arabicFont,
                  fallbackFont: fallbackFont,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  children: [
                    _buildPdfRevenueRow('Subtotal'.tr(), revenue['subtotal'] as double? ?? 0.0, currencyFormat, arabicFont, fallbackFont),
                    _buildPdfRevenueRow('Tax'.tr(), revenue['tax'] as double? ?? 0.0, currencyFormat, arabicFont, fallbackFont),
                    _buildPdfRevenueRow('Discounts'.tr(), revenue['discounts'] as double? ?? 0.0, currencyFormat, arabicFont, fallbackFont),
                    pw.TableRow(children: [pw.SizedBox(height: 5), pw.SizedBox(height: 5)]),
                    _buildPdfRevenueRow('Total Revenue'.tr(), revenue['total'] as double? ?? 0.0, currencyFormat, arabicFont, fallbackFont, isTotal: true),
                  ],
                ),
              ],
            ),
          ),
        ];
      },
    ),
  );
  
  return pdf;
}

// Update the PDF balance row helper to not use hasArabic parameter
pw.Widget _buildPdfBalanceRow(Map<String, dynamic> paymentTotals, NumberFormat formatter, pw.Font? arabicFont, pw.Font? fallbackFont) {
  final totalRevenue = _getPaymentValue(paymentTotals, 'total', 'sales');
  final totalExpenses = _getPaymentValue(paymentTotals, 'total', 'expenses');
  final balance = totalRevenue - totalExpenses;
  
  return pw.Container(
    padding: const pw.EdgeInsets.all(5),
    decoration: pw.BoxDecoration(
      color: balance >= 0 ? PdfColors.green50 : PdfColors.red50,
      border: pw.Border.all(color: PdfColors.grey300),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _createText(
          'Balance'.tr(),
          arabicFont: arabicFont,
          fallbackFont: fallbackFont,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        _createText(
          formatter.format(balance),
          arabicFont: arabicFont,
          fallbackFont: fallbackFont,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold, 
            color: balance >= 0 ? PdfColors.green800 : PdfColors.red800
          ),
        ),
      ],
    ),
  );
}

  pw.TableRow _buildPdfPaymentRow(String label, String method, Map<String, dynamic> paymentTotals, NumberFormat formatter, pw.Font? arabicFont, pw.Font? fallbackFont) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: _createText(
            label,
            arabicFont: arabicFont,
            fallbackFont: fallbackFont,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: _createText(
            formatter.format(_getPaymentValue(paymentTotals, method, 'sales')),
            arabicFont: arabicFont,
            fallbackFont: fallbackFont,
            style: pw.TextStyle(color: PdfColors.green800),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: _createText(
            formatter.format(_getPaymentValue(paymentTotals, method, 'expenses')),
            arabicFont: arabicFont,
            fallbackFont: fallbackFont,
            style: pw.TextStyle(color: PdfColors.red800),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  pw.TableRow _buildPdfServiceTypeRow(Map<String, dynamic> service, NumberFormat formatter, pw.Font? arabicFont, pw.Font? fallbackFont) {
    final serviceType = service['serviceType']?.toString() ?? '';
    final totalOrders = service['totalOrders'] as int? ?? 0;
    final totalRevenue = service['totalRevenue'] as double? ?? 0.0;
    
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: _createText(
            _getTranslatedServiceType(serviceType),
            arabicFont: arabicFont,
            fallbackFont: fallbackFont,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: _createText(
            '$totalOrders',
            arabicFont: arabicFont,
            fallbackFont: fallbackFont,
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: _createText(
            formatter.format(totalRevenue),
            arabicFont: arabicFont,
            fallbackFont: fallbackFont,
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  pw.TableRow _buildPdfRevenueRow(String label, double amount, NumberFormat formatter, pw.Font? arabicFont, pw.Font? fallbackFont, {bool isTotal = false}) {
    return pw.TableRow(
      children: [
        _createText(
          label,
          arabicFont: arabicFont,
          fallbackFont: fallbackFont,
          style: pw.TextStyle(
            fontWeight: isTotal ? pw.FontWeight.bold : null,
          ),
        ),
        _createText(
          formatter.format(amount),
          arabicFont: arabicFont,
          fallbackFont: fallbackFont,
          style: pw.TextStyle(
            fontWeight: isTotal ? pw.FontWeight.bold : null,
          ),
          textAlign: pw.TextAlign.right,
        ),
      ],
    );
  }

  // Rest of your existing methods remain the same...
  Future<void> _savePdfFallback() async {
    setState(() {
      _isPrinting = true;
    });

    try {
      final pdf = await _generateReportPdf();
      
      String filename;
      if (_selectedReportType == 'daily') {
        filename = 'Report_${DateFormat('dd-MM-yyyy').format(_selectedDate)}';
      } else if (_selectedReportType == 'monthly') {
        filename = 'Report_${DateFormat('MMMM_yyyy').format(_startDate)}';
      } else {
        filename = 'Report_${DateFormat('dd-MM-yyyy').format(_startDate)}_to_${DateFormat('dd-MM-yyyy').format(_endDate)}';
      }
      
      filename = filename.replaceAll(' ', '_');
      final saved = await _saveWithAndroidIntent(pdf, filename);

      if (mounted) {
        if (saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Report saved as PDF'.tr())),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save report as PDF'.tr())),
          );
        }
      }
    } catch (e) {
      debugPrint('Error generating or saving PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PDF'.tr())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  Future<bool> _saveWithAndroidIntent(pw.Document pdf, String filename) async {
    try {
      if (!Platform.isAndroid) {
        debugPrint('This method only works on Android');
        return false;
      }
      
      final tempDir = await getTemporaryDirectory();
      final tempFilename = 'temp_$filename.pdf';
      final tempFile = File('${tempDir.path}/$tempFilename');
      
      await tempFile.writeAsBytes(await pdf.save());
      
      const platform = MethodChannel('com.simsrestocafe/file_picker');
      
      final result = await platform.invokeMethod('createDocument', {
        'path': tempFile.path,
        'mimeType': 'application/pdf',
        'fileName': '$filename.pdf',
      });
      
      return result == true;
    } catch (e) {
      debugPrint('Error saving PDF with Android intent: $e');
      return false;
    }
  }

  // Helper method for orders count text
  String getOrdersCountText(int count) {
    if (count == 1) {
      return '1 ${'order'.tr()}';
    } else {
      return '$count ${'orders'.tr()}';
    }
  }

  // Helper method for sold items count text
  String getSoldCountText(int count) {
    if (count == 1) {
      return '1 ${'sold'.tr()}';
    } else {
      return '$count ${'sold'.tr()}';
    }
  }

  // Helper method to get translated service type for display
  String _getTranslatedServiceType(String serviceType) {
    // Handle English to current language
    if (serviceType.contains('Dining')) {
      final tableMatch = RegExp(r'Table (\d+)').firstMatch(serviceType);
      if (tableMatch != null) {
        final tableNumber = tableMatch.group(1);
        return '${'Dining'.tr()} - ${'Table'.tr()} $tableNumber';
      }
      return 'Dining'.tr();
    } else if (serviceType.contains('Takeout')) {
      return 'Takeout'.tr();
    } else if (serviceType.contains('Delivery')) {
      return 'Delivery'.tr();
    } else if (serviceType.contains('Drive')) {
      return 'Drive Through'.tr();
    } else if (serviceType.contains('Catering')) {
      return 'Catering'.tr();
    } 
    
    // Handle Arabic to current language (for consistency)
    else if (serviceType.contains('تناول الطعام')) {
      final tableMatch = RegExp(r'الطاولة (\d+)').firstMatch(serviceType);
      if (tableMatch != null) {
        final tableNumber = tableMatch.group(1);
        return '${'Dining'.tr()} - ${'Table'.tr()} $tableNumber';
      }
      return 'Dining'.tr();
    } else if (serviceType.contains('طلب خارجي')) {
      return 'Takeout'.tr();
    } else if (serviceType.contains('توصيل')) {
      return 'Delivery'.tr();
    } else if (serviceType.contains('السيارة')) {
      return 'Drive Through'.tr();
    } else if (serviceType.contains('تموين')) {
      return 'Catering'.tr();
    } else {
      return serviceType; // Fallback to original
    }
  }

  // All the remaining helper and UI methods remain the same as your original code...
  String _getCacheKey(String reportType, DateTime date, {DateTime? endDate}) {
    if (reportType == 'daily') {
      return 'daily_${DateFormat('yyyy-MM-dd').format(date)}';
    } else if (reportType == 'monthly') {
      return 'monthly_${DateFormat('yyyy-MM').format(date)}';
    } else {
      return 'custom_${DateFormat('yyyy-MM-dd').format(date)}_${DateFormat('yyyy-MM-dd').format(endDate ?? date)}';
    }
  }

  double _getPaymentValue(Map<String, dynamic> paymentTotals, String method, String type) {
    try {
      return (paymentTotals[method] as Map<String, dynamic>?)?[type] as double? ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // Helper method to clean text for printing (removes unsupported characters, trims, etc.)
  String _cleanTextForPrinting(String text) {
    // Remove control characters and trim whitespace
    return text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
  }

  // All remaining methods (UI building, data loading, etc.) remain exactly the same...
  Future<void> _loadReport() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      DateTime startDate, endDate;
      
      if (_selectedReportType == 'daily') {
        startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      } else if (_selectedReportType == 'monthly') {
        startDate = DateTime(_startDate.year, _startDate.month, 1);
        if (_startDate.month < 12) {
          endDate = DateTime(_startDate.year, _startDate.month + 1, 0, 23, 59, 59);
        } else {
          endDate = DateTime(_startDate.year + 1, 1, 0, 23, 59, 59);
        }
      } else {
        startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
        endDate = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      }
      
      final String cacheKey = _getCacheKey(
        _selectedReportType, 
        startDate,
        endDate: endDate
      );
      
      debugPrint('Loading report for date range: ${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}');
      
      if (_reportCache.containsKey(cacheKey)) {
        setState(() {
          _reportData = _reportCache[cacheKey];
          _isLoading = false;
        });
        return;
      }

      final reportData = await _generateLocalReport(startDate, endDate);
      _reportCache[cacheKey] = reportData;
      
      if (mounted) {
        setState(() {
          _reportData = reportData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report'.tr())),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _generateLocalReport(DateTime startDate, DateTime endDate) async {
    final List<Order> allOrders = await _orderRepo.getAllOrders();
    final List<Map<String, dynamic>> allExpenses = await _expenseRepo.getAllExpenses();
    
    List<Order> filteredOrders = _filterOrdersByDateRange(allOrders, startDate, endDate);
    List<Map<String, dynamic>> filteredExpenses = _filterExpensesByDateRange(allExpenses, startDate, endDate);
    
    final reportData = _createReportFromData(filteredOrders, filteredExpenses);
    return reportData;
  }

  List<Order> _filterOrdersByDateRange(List<Order> orders, DateTime startDate, DateTime endDate) {
    return orders.where((order) {
      if (order.createdAt == null) return false;
      
      DateTime orderDate;
      try {
        if (order.createdAt!.contains('local_')) {
          final parts = order.createdAt!.split('_');
          if (parts.length > 1) {
            final timestamp = int.parse(parts.last);
            orderDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else {
            orderDate = DateTime.now();
            return false;
          }
        } else {
          orderDate = DateTime.parse(order.createdAt!);
        }
        
        return (orderDate.isAfter(startDate.subtract(const Duration(seconds: 1))) || 
                orderDate.isAtSameMomentAs(startDate)) && 
               (orderDate.isBefore(endDate.add(const Duration(seconds: 1))) || 
                orderDate.isAtSameMomentAs(endDate));
               
      } catch (e) {
        debugPrint('Error parsing date for order ${order.id}: ${order.createdAt} - $e');
        return false;
      }
    }).toList();
  }

  List<Map<String, dynamic>> _filterExpensesByDateRange(
    List<Map<String, dynamic>> expenses, 
    DateTime startDate, 
    DateTime endDate
  ) {
    return expenses.where((expense) {
      final dateStr = expense['date'] as String;
      
      DateTime expenseDate;
      try {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          expenseDate = DateTime(year, month, day);
          
          return (expenseDate.isAfter(startDate.subtract(const Duration(days: 1))) || 
                  expenseDate.isAtSameMomentAs(startDate)) && 
                 (expenseDate.isBefore(endDate.add(const Duration(days: 1))) || 
                  expenseDate.isAtSameMomentAs(endDate));
        }
      } catch (e) {
        debugPrint('Error parsing expense date: $dateStr - $e');
      }
      return false;
    }).toList();
  }

  Map<String, dynamic> _createReportFromData(List<Order> orders, List<Map<String, dynamic>> expenses) {
    debugPrint('Creating report from ${orders.length} orders and ${expenses.length} expenses');
    
    final totalOrders = orders.length;
    final totalRevenue = orders.fold(0.0, (sum, order) => sum + order.total);
    final totalItemsSold = orders.fold(0, (sum, order) => sum + order.items.length);

    final Map<String, List<Order>> ordersByServiceType = {};
    for (final order in orders) {
      String normalizedServiceType = _normalizeServiceType(order.serviceType);
      ordersByServiceType.putIfAbsent(normalizedServiceType, () => []).add(order);
    }  
    final subtotal = orders.fold(0.0, (sum, order) => sum + order.subtotal);
    final tax = orders.fold(0.0, (sum, order) => sum + order.tax);
    final discount = orders.fold(0.0, (sum, order) => sum + order.discount);
    
    final Map<String, Map<String, double>> paymentTotals = {
      'cash': {'sales': 0.0, 'expenses': 0.0, 'net': 0.0},
      'bank': {'sales': 0.0, 'expenses': 0.0, 'net': 0.0},
      'other': {'sales': 0.0, 'expenses': 0.0, 'net': 0.0},
      'total': {'sales': 0.0, 'expenses': 0.0, 'net': 0.0},
    };
    
    for (final order in orders) {
      final paymentMethod = (order.paymentMethod ?? 'cash').toLowerCase();
      if (paymentMethod == 'cash') {
        paymentTotals['cash']!['sales'] = (paymentTotals['cash']!['sales'] ?? 0.0) + order.total;
      } else if (paymentMethod == 'bank') {
        paymentTotals['bank']!['sales'] = (paymentTotals['bank']!['sales'] ?? 0.0) + order.total;
      } else {
        paymentTotals['other']!['sales'] = (paymentTotals['other']!['sales'] ?? 0.0) + order.total;
      }
      paymentTotals['total']!['sales'] = (paymentTotals['total']!['sales'] ?? 0.0) + order.total;
    }
    
    for (final expense in expenses) {
      final accountType = (expense['accountType'] as String? ?? '').toLowerCase();
      final total = (expense['grandTotal'] as num? ?? 0).toDouble();
      
      if (accountType.contains('cash')) {
        paymentTotals['cash']!['expenses'] = (paymentTotals['cash']!['expenses'] ?? 0.0) + total;
      } else if (accountType.contains('bank')) {
        paymentTotals['bank']!['expenses'] = (paymentTotals['bank']!['expenses'] ?? 0.0) + total;
      } else {
        paymentTotals['other']!['expenses'] = (paymentTotals['other']!['expenses'] ?? 0.0) + total;
      }
      paymentTotals['total']!['expenses'] = (paymentTotals['total']!['expenses'] ?? 0.0) + total;
    }
    
    for (final key in paymentTotals.keys) {
      paymentTotals[key]!['net'] = (paymentTotals[key]!['sales'] ?? 0.0) - (paymentTotals[key]!['expenses'] ?? 0.0);
    }
    
    final Map<String, Map<String, dynamic>> itemSales = {};
    
    for (final order in orders) {
      for (final item in order.items) {
        final itemId = item.id.toString();
        final itemName = item.name;
        
        if (!itemSales.containsKey(itemId)) {
          itemSales[itemId] = {
            'name': itemName,
            'quantity': 0,
            'price': item.price,
            'total_revenue': 0.0,
          };
        }
        
        itemSales[itemId]!['quantity'] = (itemSales[itemId]!['quantity'] as int) + item.quantity;
        itemSales[itemId]!['total_revenue'] = (itemSales[itemId]!['total_revenue'] as double) + (item.price * item.quantity);
      }
    }
    
    final topItems = itemSales.values.toList()
      ..sort((a, b) => (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));
    
    final serviceTypeSales = ordersByServiceType.entries.map((entry) {
      final serviceType = entry.key;
      final orders = entry.value;
      final totalOrders = orders.length;
      final totalRevenue = orders.fold(0.0, (sum, order) => sum + order.total);
      
      return {
        'serviceType': serviceType,
        'totalOrders': totalOrders,
        'totalRevenue': totalRevenue,
      };
    }).toList();
    
    return {
      'summary': {
        'totalOrders': totalOrders,
        'totalRevenue': totalRevenue,
        'totalItemsSold': totalItemsSold,
      },
      'revenue': {
        'subtotal': subtotal,
        'tax': tax,
        'discounts': discount,
        'total': totalRevenue,
      },
      'paymentTotals': paymentTotals,
      'serviceTypeSales': serviceTypeSales,
      'topItems': topItems,
      'orders': orders.map((order) => {
        'id': order.id,
        'serviceType': order.serviceType,
        'total': order.total,
        'status': order.status,
        'createdAt': order.createdAt,
      }).toList(),
    };
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isCustomDateRange = false;
      });
      _loadReport();
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue,
            colorScheme: const ColorScheme.light(primary: Colors.blue),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _isCustomDateRange = true;
        _selectedReportType = 'custom';
      });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Save PDF button
          _isSavingPdf
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Save as PDF'.tr(),
                  onPressed: _reportData == null ? null : _savePdfDirectly,
                ),
          // Print button  
          _isPrinting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'Print Report'.tr(),
                  onPressed: _reportData == null ? null : _printReport,
                ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildReportTypeCard(
                        'daily',
                        'Daily Report'.tr(),
                        Icons.today,
                        _selectedReportType == 'daily',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildReportTypeCard(
                        'custom',
                        'Monthly Report'.tr(),
                        Icons.calendar_month,
                        _selectedReportType == 'custom',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (_selectedReportType == 'daily')
                  _buildDateSelector()
                else if (_selectedReportType == 'monthly')
                  _buildMonthSelector()
                else
                  _buildDateRangeSelector(),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reportData == null
                    ? Center(child: Text('No data available'.tr()))
                    : _buildReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTypeCard(String type, String title, IconData icon, bool isSelected) {
    return InkWell(
      onTap: () {
        if (_selectedReportType != type) {
          setState(() {
            _selectedReportType = type;
            if (type == 'daily') {
              _isCustomDateRange = false;
            } else if (type == 'monthly') {
              _isCustomDateRange = false;
              final now = DateTime.now();
              _startDate = DateTime(now.year, now.month, 1);
            } else if (type == 'custom') {
              _isCustomDateRange = true;
            }
          });
          _loadReport();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '${'Selected Date:'.tr()} ${DateFormat('dd-MM-yyyy').format(_selectedDate)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return InkWell(
      onTap: _selectMonth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '${'Month'.tr()}: ${DateFormat('MMMM yyyy').format(_startDate)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, 1);
        _isCustomDateRange = false;
      });
      _loadReport();
    }
  }

  Widget _buildDateRangeSelector() {
    return InkWell(
      onTap: _selectDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: _isCustomDateRange ? Colors.blue.shade300 : Colors.grey.shade300,
            width: _isCustomDateRange ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: _isCustomDateRange ? Colors.blue.shade50 : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${'From:'.tr()} ${DateFormat('dd MMM yyyy').format(_startDate)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${'To:'.tr()} ${DateFormat('dd MMM yyyy').format(_endDate)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    if (_reportData == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummarySection(),
          const SizedBox(height: 24),
          _buildPaymentTotalsSection(),
          const SizedBox(height: 24),
          _buildServiceTypeSalesSection(),
          const SizedBox(height: 24),
          _buildRevenueSection(),
          const SizedBox(height: 24),
          if (_reportData!['topItems'] != null)
            _buildTopItemsSection(),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final summary = _reportData!['summary'] ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Orders'.tr(),
                '${summary['totalOrders'] ?? 0}',
                Icons.receipt_long,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                'Total Revenue'.tr(),
                (summary['totalRevenue'] as double? ?? 0.0).toStringAsFixed(3),
                Icons.attach_money,
                Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                'Items Sold'.tr(),
                '${summary['totalItemsSold'] ?? 0}',
                Icons.inventory,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        border: Border.all(color: color.withAlpha(77)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withAlpha(204),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTypeSalesSection() {
    final serviceTypeSales = _reportData!['serviceTypeSales'] as List? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Sales'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: serviceTypeSales.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text('No sales data found'.tr())),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: serviceTypeSales.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final serviceType = serviceTypeSales[index] as Map<String, dynamic>;
                    final serviceTypeName = serviceType['serviceType']?.toString() ?? '';
                    final totalOrders = serviceType['totalOrders'] as int? ?? 0;
                    final totalRevenue = serviceType['totalRevenue'] as double? ?? 0.0;
                    
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _getServiceTypeColor(serviceTypeName).withAlpha(51),
                                  child: Icon(
                                    _getServiceTypeIcon(serviceTypeName),
                                    color: _getServiceTypeColor(serviceTypeName),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getTranslatedServiceType(serviceTypeName),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        getOrdersCountText(totalOrders),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  totalRevenue.toStringAsFixed(3),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRevenueSection() {
    final revenue = _reportData!['revenue'] ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue Breakdown'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildRevenueRow('Subtotal'.tr(), revenue['subtotal'] as double? ?? 0.0),
              const SizedBox(height: 8),
              _buildRevenueRow('Tax'.tr(), revenue['tax'] as double? ?? 0.0),
              const SizedBox(height: 8),
              _buildRevenueRow('Discounts'.tr(), revenue['discounts'] as double? ?? 0.0),
              const Divider(),
              _buildRevenueRow('Total Revenue'.tr(), revenue['total'] as double? ?? 0.0, isTotal: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          amount.toStringAsFixed(3),
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTopItemsSection() {
    final topItems = _reportData!['topItems'] as List? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Selling Items'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: topItems.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text('No items data available'.tr())),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topItems.length > 5 ? 5 : topItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = topItems[index] as Map<String, dynamic>;
                    final name = item['name']?.toString() ?? '';
                    final quantity = item['quantity'] as int? ?? 0;
                    final price = item['price'] as double? ?? 0.0;
                    final totalRevenue = item['total_revenue'] as double? ?? 0.0;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text('${'Price'.tr()}: ${price.toStringAsFixed(3)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            getSoldCountText(quantity),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            totalRevenue.toStringAsFixed(3),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPaymentTotalsSection() {
    if (_reportData == null) return const SizedBox();
    
    final paymentTotals = _reportData!['paymentTotals'] as Map<String, dynamic>?;
    
    if (paymentTotals == null) {
      return Center(child: Text('Payment data not available'.tr()));
    }
    
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
    
    final totalRevenue = _getPaymentValue(paymentTotals, 'total', 'sales');
    final totalExpenses = _getPaymentValue(paymentTotals, 'total', 'expenses');
    final balance = totalRevenue - totalExpenses;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cash and Bank Sales'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade800,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    topRight: Radius.circular(7),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Payment Method'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Revenue'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Expenses'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              
              _buildPaymentRow(
                'Total Cash Sales'.tr(), 
                _getPaymentValue(paymentTotals, 'cash', 'sales'),
                _getPaymentValue(paymentTotals, 'cash', 'expenses'),
                currencyFormat,
                Colors.grey.shade100,
              ),
              
              _buildPaymentRow(
                'Total Bank Sales'.tr(), 
                _getPaymentValue(paymentTotals, 'bank', 'sales'),
                _getPaymentValue(paymentTotals, 'bank', 'expenses'),
                currencyFormat,
                Colors.white,
              ),
              
              Divider(height: 1, color: Colors.grey.shade300),
              
              _buildPaymentRow(
                'Total'.tr(), 
                totalRevenue,
                totalExpenses,
                currencyFormat,
                Colors.blue.shade50,
                isTotal: true,
              ),
              
              _buildBalanceRow(
                'Balance'.tr(),
                balance,
                currencyFormat,
                balance >= 0 ? Colors.green.shade50 : Colors.red.shade50,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceRow(
    String label, 
    double balance, 
    NumberFormat formatter,
    Color backgroundColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: backgroundColor,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              formatter.format(balance),
              style: TextStyle(
                color: balance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(
    String method, 
    double sales, 
    double expenses, 
    NumberFormat formatter,
    Color backgroundColor,
    {bool isTotal = false}
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: backgroundColor,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              method,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatter.format(sales),
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatter.format(expenses),
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeServiceType(String serviceType) {
    return ServiceTypeUtils.normalize(serviceType);
  }

  IconData _getServiceTypeIcon(String serviceType) {
    return ServiceTypeUtils.getIcon(serviceType);
  }

  Color _getServiceTypeColor(String serviceType) {
    return ServiceTypeUtils.getColor(serviceType);
  }
}