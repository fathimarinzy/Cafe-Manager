import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../repositories/local_order_repository.dart';
import '../repositories/local_expense_repository.dart';
import '../models/order.dart';
// import '../services/bill_service.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/app_localization.dart';
import '../utils/service_type_utils.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

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
  bool _isSavingPdf = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Set start date to first day of current month instead of previous month
    _startDate = DateTime(now.year, now.month, 1);
    
    // End date remains current date
    _endDate = DateTime.now();
    _loadReport();
  }

  // Helper method to get translated service type for display

String _getTranslatedServiceType(String serviceType) {
  // Handle English to current language
  if (serviceType.contains('Dining')) {
    // Extract table number if it exists
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
    // Extract table number if it exists
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
  
  // Generate and save PDF report
  Future<void> _generateAndSavePdf() async {
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
          SnackBar(content: Text('Error'.tr())),
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
  
  // Generate PDF report from report data
  Future<pw.Document> _generateReportPdf() async {
    final pdf = pw.Document();
    
    pw.Font? ttf;
    try {
      final fontData = await rootBundle.load("assets/fonts/open-sans.regular.ttf");
      ttf = pw.Font.ttf(fontData.buffer.asByteData());
    } catch (e) {
      debugPrint('Could not load font, using default: $e');
    }
    // Get restaurant name from SettingsProvider instead of BillService
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final restaurantName = settingsProvider.businessName.isNotEmpty 
      ? settingsProvider.businessName 
      : 'SIMS CAFE'; // Fallback name
    
    // final businessInfo = await BillService.getBusinessInfo();
    
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
              pw.Text(
                restaurantName,               
                 style: pw.TextStyle(
                  font: ttf,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                reportTitle,
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                dateRangeText,
                style: pw.TextStyle(font: ttf, fontSize: 12),
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
              pw.Text(
                'Generated on ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.grey700),
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
                  pw.Text(
                    'Cash and Bank Sales'.tr(),
                    style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              'Payment Method'.tr(),
                              style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              'Revenue'.tr(),
                              style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              'Expenses'.tr(),
                              style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      _buildPdfPaymentRow('Cash Sales', 'cash', paymentTotals, currencyFormat, ttf),
                      _buildPdfPaymentRow('Bank Sales', 'bank', paymentTotals, currencyFormat, ttf),
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              'Total'.tr(),
                              style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              currencyFormat.format(_getPaymentValue(paymentTotals, 'total', 'sales')),
                              style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              currencyFormat.format(_getPaymentValue(paymentTotals, 'total', 'expenses')),
                              style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                   // Add Balance Row as separate widget
                  _buildPdfBalanceRow(paymentTotals, currencyFormat, ttf),   
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
                  pw.Text(
                    'Total Sales'.tr(),
                    style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  serviceTypeSales.isEmpty
                    ? pw.Center(child: pw.Text('No sales data available'.tr(), style: pw.TextStyle(font: ttf)))
                    : pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300),
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text(
                                  'Service Type'.tr(),
                                  style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text(
                                  'Orders'.tr(),
                                  style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text(
                                  'Revenue'.tr(),
                                  style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          ...serviceTypeSales.map((service) => _buildPdfServiceTypeRow(service, currencyFormat, ttf)),
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
                  pw.Text(
                    'Revenue Breakdown'.tr(),
                    style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    children: [
                      _buildPdfRevenueRow('Subtotal'.tr(), revenue['subtotal'] as double? ?? 0.0, currencyFormat, ttf),
                      _buildPdfRevenueRow('Tax'.tr(), revenue['tax'] as double? ?? 0.0, currencyFormat, ttf),
                      _buildPdfRevenueRow('Discounts'.tr(), revenue['discounts'] as double? ?? 0.0, currencyFormat, ttf),
                      pw.TableRow(children: [pw.SizedBox(height: 5), pw.SizedBox(height: 5)]),
                      _buildPdfRevenueRow('Total Revenue'.tr(), revenue['total'] as double? ?? 0.0, currencyFormat, ttf, isTotal: true),
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
  pw.Widget _buildPdfBalanceRow(Map<String, dynamic> paymentTotals, NumberFormat formatter, pw.Font? font) {
  // Calculate balance (Total Revenue - Total Expenses)
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
        pw.Text(
          'Balance'.tr(),
          style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          formatter.format(balance),
          style: pw.TextStyle(
            font: font, 
            fontWeight: pw.FontWeight.bold, 
            color: balance >= 0 ? PdfColors.green800 : PdfColors.red800
          ),
        ),
      ],
    ),
  );
}
 
  pw.TableRow _buildPdfPaymentRow(String label, String method, Map<String, dynamic> paymentTotals, NumberFormat formatter, pw.Font? font) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            label,
            style: pw.TextStyle(font: font),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            formatter.format(_getPaymentValue(paymentTotals, method, 'sales')),
            style: pw.TextStyle(font: font, color: PdfColors.green800),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            formatter.format(_getPaymentValue(paymentTotals, method, 'expenses')),
            style: pw.TextStyle(font: font, color: PdfColors.red800),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }
  
  pw.TableRow _buildPdfServiceTypeRow(Map<String, dynamic> service, NumberFormat formatter, pw.Font? font) {
    final serviceType = service['serviceType']?.toString() ?? '';
    final totalOrders = service['totalOrders'] as int? ?? 0;
    final totalRevenue = service['totalRevenue'] as double? ?? 0.0;
    
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            serviceType,
            style: pw.TextStyle(font: font),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            '$totalOrders',
            style: pw.TextStyle(font: font),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            formatter.format(totalRevenue),
            style: pw.TextStyle(font: font),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }
  
  pw.TableRow _buildPdfRevenueRow(String label, double amount, NumberFormat formatter, pw.Font? font, {bool isTotal = false}) {
    return pw.TableRow(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font, 
            fontWeight: isTotal ? pw.FontWeight.bold : null,
          ),
        ),
        pw.Text(
          formatter.format(amount),
          style: pw.TextStyle(
            font: font, 
            fontWeight: isTotal ? pw.FontWeight.bold : null,
          ),
          textAlign: pw.TextAlign.right,
        ),
      ],
    );
  }
  
    
  String _getCacheKey(String reportType, DateTime date, {DateTime? endDate}) {
    if (reportType == 'daily') {
      return 'daily_${DateFormat('yyyy-MM-dd').format(date)}';
    } else if (reportType == 'monthly') {
      return 'monthly_${DateFormat('yyyy-MM').format(date)}';
    } else {
      return 'custom_${DateFormat('yyyy-MM-dd').format(date)}_${DateFormat('yyyy-MM-dd').format(endDate ?? date)}';
    }
  }
  
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
  
  double _getPaymentValue(Map<String, dynamic> paymentTotals, String method, String type) {
    try {
      return (paymentTotals[method] as Map<String, dynamic>?)?[type] as double? ?? 0.0;
    } catch (e) {
      return 0.0;
    }
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
                  icon: const Icon(Icons.save_alt),
                  tooltip: 'Save as PDF'.tr(),
                  onPressed: _reportData == null ? null : _generateAndSavePdf,
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
                    // Expanded(
                    //   child: _buildReportTypeCard(
                    //     'monthly',
                    //     'Monthly Report',
                    //     Icons.date_range,
                    //     _selectedReportType == 'monthly',
                    //   ),
                    // ),
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
  
  // Calculate balance (Total Revenue - Total Expenses)
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
            
            // Add Balance Row
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
          flex: 4, // Spans across both Revenue and Expenses columns
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
  // Helper method to normalize service types for grouping
String _normalizeServiceType(String serviceType) {
  return ServiceTypeUtils.normalize(serviceType);
}

// // Helper method to get translated service type for display
// String _getTranslatedServiceType(String serviceType) {
//   return ServiceTypeUtils.getTranslated(serviceType);
// }

IconData _getServiceTypeIcon(String serviceType) {
  return ServiceTypeUtils.getIcon(serviceType);
}

Color _getServiceTypeColor(String serviceType) {
  return ServiceTypeUtils.getColor(serviceType);
}


  
}