import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../repositories/local_order_repository.dart';
import '../repositories/local_expense_repository.dart';
import '../models/order.dart';
import '../services/bill_service.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/app_localization.dart';

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
    // Set the start date to the same day in the previous month
    final now = DateTime.now();
    
    // Calculate previous month's date (handle edge cases like January)
    if (now.month == 1) {
      // If current month is January, go to December of previous year
      _startDate = DateTime(now.year - 1, 12, now.day);
    } else {
      // Normal case - previous month, same day
      _startDate = DateTime(now.year, now.month - 1, now.day);
    }
    
    // Handle edge cases where the previous month might have fewer days
    // (e.g., March 31 -> February 28/29)
    final daysInPreviousMonth = _getDaysInMonth(_startDate.year, _startDate.month);
    if (_startDate.day > daysInPreviousMonth) {
      _startDate = DateTime(_startDate.year, _startDate.month, daysInPreviousMonth);
    }
    
    _endDate = DateTime.now();
    

    _loadReport();
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
    // Generate PDF document
    final pdf = await _generateReportPdf();
    
    // Create a descriptive filename based on report type and date
    String filename;
    if (_selectedReportType == 'daily') {
      filename = 'Report_${DateFormat('dd-MM-yyyy').format(_selectedDate)}';
    } else if (_selectedReportType == 'monthly') {
      filename = 'Report_${DateFormat('MMMM_yyyy').format(_startDate)}';
    } else {
      // Custom date range
      filename = 'Report_${DateFormat('dd-MM-yyyy').format(_startDate)}_to_${DateFormat('dd-MM-yyyy').format(_endDate)}';
    }
    
    // Remove any invalid filename characters
    filename = filename.replaceAll(' ', '_');
    
    // Save PDF using Android intent with custom filename
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
    
    // First save PDF to a temporary file
    final tempDir = await getTemporaryDirectory();
    final tempFilename = 'temp_$filename.pdf';
    final tempFile = File('${tempDir.path}/$tempFilename');
    
    // Write PDF to temporary file
    await tempFile.writeAsBytes(await pdf.save());
    
    // Create platform channel for intent
    const platform = MethodChannel('com.simsrestocafe/file_picker');
    
    // Call the native method with file path and custom filename
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
    
    // Try to load custom font if available
    pw.Font? ttf;
    try {
      final fontData = await rootBundle.load("assets/fonts/open-sans.regular.ttf");
      ttf = pw.Font.ttf(fontData.buffer.asByteData());
    } catch (e) {
      debugPrint('Could not load font, using default: $e');
      // Continue without custom font
    }
    
    // Get business info for header
    final businessInfo = await BillService.getBusinessInfo();
    
    // Format date range for title
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
    
    // Format currency
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
    
    // Extract report sections
    // final summary = _reportData!['summary'] ?? {};
    final revenue = _reportData!['revenue'] ?? {};
    final paymentTotals = _reportData!['paymentTotals'] as Map<String, dynamic>? ?? {};
    final serviceTypeSales = _reportData!['serviceTypeSales'] as List? ?? [];
    // final topItems = _reportData!['topItems'] as List? ?? [];
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                businessInfo['name']!,
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              // pw.SizedBox(height: 5),
              // pw.Text(
              //   businessInfo['address']!,
              //   style: pw.TextStyle(font: ttf, fontSize: 10),
              //   textAlign: pw.TextAlign.center,
              // ),
              // pw.Text(
              //   'Tel: ${businessInfo['phone']}',
              //   style: pw.TextStyle(font: ttf, fontSize: 10),
              //   textAlign: pw.TextAlign.center,
              // ),
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
            // Summary Section
            // pw.Container(
            //   padding: const pw.EdgeInsets.all(10),
            //   decoration: pw.BoxDecoration(
            //     border: pw.Border.all(color: PdfColors.grey300),
            //     borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            //   ),
            //   child: pw.Column(
            //     crossAxisAlignment: pw.CrossAxisAlignment.start,
            //     // children: [
            //     //   pw.Text(
            //     //     'Summary',
            //     //     style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
            //     //   ),
            //     //   pw.SizedBox(height: 10),
            //     //   pw.Row(
            //     //     mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            //     //     children: [
            //     //       _buildPdfSummaryItem(
            //     //         'Total Orders', 
            //     //         '${summary['totalOrders'] ?? 0}', 
            //     //         ttf
            //     //       ),
            //     //       _buildPdfSummaryItem(
            //     //         'Total Revenue', 
            //     //         currencyFormat.format(summary['totalRevenue'] ?? 0.0), 
            //     //         ttf
            //     //       ),
            //     //       _buildPdfSummaryItem(
            //     //         'Items Sold', 
            //     //         '${summary['totalItemsSold'] ?? 0}', 
            //     //         ttf
            //     //       ),
            //     //     ],
            //     //   ),
            //     // ],
            //   ),
            // ),
            
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
                      // Header row
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
                      // Cash row
                      _buildPdfPaymentRow('Cash Sales', 'cash', paymentTotals, currencyFormat, ttf),
                      // Bank row
                      _buildPdfPaymentRow('Bank Sales', 'bank', paymentTotals, currencyFormat, ttf),
                      // Total row
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
                          // Header row
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
                          // Service type rows
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
                      _buildPdfRevenueRow('Subtotal', revenue['subtotal'] as double? ?? 0.0, currencyFormat, ttf),
                      _buildPdfRevenueRow('Tax', revenue['tax'] as double? ?? 0.0, currencyFormat, ttf),
                      _buildPdfRevenueRow('Discounts', revenue['discounts'] as double? ?? 0.0, currencyFormat, ttf),
                      pw.TableRow(children: [pw.SizedBox(height: 5), pw.SizedBox(height: 5)]),
                      _buildPdfRevenueRow('Total Revenue', revenue['total'] as double? ?? 0.0, currencyFormat, ttf, isTotal: true),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 15),
            
            // Top Items Section
            // if (topItems.isNotEmpty) pw.Container(
            //   padding: const pw.EdgeInsets.all(10),
            //   decoration: pw.BoxDecoration(
            //     border: pw.Border.all(color: PdfColors.grey300),
            //     borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            //   ),
            //   child: pw.Column(
            //     crossAxisAlignment: pw.CrossAxisAlignment.start,
            //     children: [
            //       pw.Text(
            //         'Top Selling Items',
            //         style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
            //       ),
            //       pw.SizedBox(height: 10),
            //       pw.Table(
            //         border: pw.TableBorder.all(color: PdfColors.grey300),
            //         children: [
            //           // Header row
            //           pw.TableRow(
            //             decoration: const pw.BoxDecoration(color: PdfColors.blue100),
            //             children: [
            //               pw.Padding(
            //                 padding: const pw.EdgeInsets.all(5),
            //                 child: pw.Text(
            //                   'Rank',
            //                   style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
            //                   textAlign: pw.TextAlign.center,
            //                 ),
            //               ),
            //               pw.Padding(
            //                 padding: const pw.EdgeInsets.all(5),
            //                 child: pw.Text(
            //                   'Item',
            //                   style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
            //                 ),
            //               ),
            //               pw.Padding(
            //                 padding: const pw.EdgeInsets.all(5),
            //                 child: pw.Text(
            //                   'Price',
            //                   style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
            //                   textAlign: pw.TextAlign.right,
            //                 ),
            //               ),
            //               pw.Padding(
            //                 padding: const pw.EdgeInsets.all(5),
            //                 child: pw.Text(
            //                   'Qty',
            //                   style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
            //                   textAlign: pw.TextAlign.center,
            //                 ),
            //               ),
            //               pw.Padding(
            //                 padding: const pw.EdgeInsets.all(5),
            //                 child: pw.Text(
            //                   'Revenue',
            //                   style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
            //                   textAlign: pw.TextAlign.right,
            //                 ),
            //               ),
            //             ],
            //           ),
            //           // Top items rows - limit to top 10
            //           ...topItems.take(10).toList().asMap().entries.map(
            //             (entry) => _buildPdfTopItemRow(entry.key + 1, entry.value, currencyFormat, ttf)
            //           ).toList(),
            //         ],
            //       ),
            //     ],
            //   ),
            // ),
          ];
        },
      ),
    );
    
    return pdf;
  }
  
  // // Helper method to build a summary item for PDF
  // pw.Widget _buildPdfSummaryItem(String title, String value, pw.Font? font) {
  //   return pw.Container(
  //     padding: const pw.EdgeInsets.all(10),
  //     decoration: pw.BoxDecoration(
  //       border: pw.Border.all(color: PdfColors.grey300),
  //       borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
  //     ),
  //     width: 120,
  //     child: pw.Column(
  //       children: [
  //         pw.Text(
  //           title,
  //           style: pw.TextStyle(font: font, fontSize: 10),
  //           textAlign: pw.TextAlign.center,
  //         ),
  //         pw.SizedBox(height: 5),
  //         pw.Text(
  //           value,
  //           style: pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold),
  //           textAlign: pw.TextAlign.center,
  //         ),
  //       ],
  //     ),
  //   );
  // }
  
  // Helper method to build payment row for PDF
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
  
  // Helper method to build service type row for PDF
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
  
  // Helper method to build revenue row for PDF
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
  
  // Helper method to build top item row for PDF
  // pw.TableRow _buildPdfTopItemRow(int rank, Map<String, dynamic> item, NumberFormat formatter, pw.Font? font) {
  //   final name = item['name']?.toString() ?? '';
  //   final quantity = item['quantity'] as int? ?? 0;
  //   final price = item['price'] as double? ?? 0.0;
  //   final totalRevenue = item['total_revenue'] as double? ?? 0.0;
    
  //   return pw.TableRow(
  //     children: [
  //       pw.Padding(
  //         padding: const pw.EdgeInsets.all(5),
  //         child: pw.Text(
  //           '$rank',
  //           style: pw.TextStyle(font: font),
  //           textAlign: pw.TextAlign.center,
  //         ),
  //       ),
  //       pw.Padding(
  //         padding: const pw.EdgeInsets.all(5),
  //         child: pw.Text(
  //           name,
  //           style: pw.TextStyle(font: font),
  //         ),
  //       ),
  //       pw.Padding(
  //         padding: const pw.EdgeInsets.all(5),
  //         child: pw.Text(
  //           formatter.format(price),
  //           style: pw.TextStyle(font: font),
  //           textAlign: pw.TextAlign.right,
  //         ),
  //       ),
  //       pw.Padding(
  //         padding: const pw.EdgeInsets.all(5),
  //         child: pw.Text(
  //           '$quantity',
  //           style: pw.TextStyle(font: font),
  //           textAlign: pw.TextAlign.center,
  //         ),
  //       ),
  //       pw.Padding(
  //         padding: const pw.EdgeInsets.all(5),
  //         child: pw.Text(
  //           formatter.format(totalRevenue),
  //           style: pw.TextStyle(font: font),
  //           textAlign: pw.TextAlign.right,
  //         ),
  //       ),
  //     ],
  //   );
  // }
  
  // Helper to get the number of days in a month
  int _getDaysInMonth(int year, int month) {
    // Use the trick that the day 0 of the next month is the last day of the current month
    return DateTime(year, month + 1, 0).day;
  }
    
  // Generate a cache key based on report parameters
  String _getCacheKey(String reportType, DateTime date, {DateTime? endDate}) {
    if (reportType == 'daily') {
      return 'daily_${DateFormat('yyyy-MM-dd').format(date)}';
    } else if (reportType == 'monthly') {
      return 'monthly_${DateFormat('yyyy-MM').format(date)}';
    } else {
      // Custom date range
      return 'custom_${DateFormat('yyyy-MM-dd').format(date)}_${DateFormat('yyyy-MM-dd').format(endDate ?? date)}';
    }
  }
  
  // Load report data from local database
  Future<void> _loadReport() async {
    if (_isLoading) return; // Prevent multiple simultaneous loads
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Determine date range based on report type
      DateTime startDate, endDate;
      
      if (_selectedReportType == 'daily') {
        // Daily report - use selected date
        startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      } else if (_selectedReportType == 'monthly') {
        // Monthly report - use full month
        startDate = DateTime(_startDate.year, _startDate.month, 1);
        // Last day of month
        if (_startDate.month < 12) {
          endDate = DateTime(_startDate.year, _startDate.month + 1, 0, 23, 59, 59);
        } else {
          endDate = DateTime(_startDate.year + 1, 1, 0, 23, 59, 59);
        }
      } else {
        // Custom date range - use start and end dates
        startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
        endDate = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      }
      
      final String cacheKey = _getCacheKey(
        _selectedReportType, 
        startDate,
        endDate: endDate
      );
      
      // Debug logging for date range
      debugPrint('Loading report for date range: ${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}');
      
      // Check if we have cached data
      if (_reportCache.containsKey(cacheKey)) {
        setState(() {
          _reportData = _reportCache[cacheKey];
          _isLoading = false;
        });
        return;
      }

      // Load report data from local repositories
      final reportData = await _generateLocalReport(startDate, endDate);
      
      // Store results in cache
      _reportCache[cacheKey] = reportData;
      
      // Update state with the report data
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

  // Generate report data from local database with explicit date range
  Future<Map<String, dynamic>> _generateLocalReport(DateTime startDate, DateTime endDate) async {
    // Get all orders from local database
    final List<Order> allOrders = await _orderRepo.getAllOrders();
    
    // Get all expenses from local database
    final List<Map<String, dynamic>> allExpenses = await _expenseRepo.getAllExpenses();
    
    // Filter orders based on date range
    List<Order> filteredOrders = _filterOrdersByDateRange(allOrders, startDate, endDate);
    
    // Filter expenses based on date range
    List<Map<String, dynamic>> filteredExpenses = _filterExpensesByDateRange(allExpenses, startDate, endDate);
    
    // Generate report data
    final reportData = _createReportFromData(filteredOrders, filteredExpenses);
    
    return reportData;
  }
  // Filter orders by explicit date range
  List<Order> _filterOrdersByDateRange(List<Order> orders, DateTime startDate, DateTime endDate) {
    return orders.where((order) {
      if (order.createdAt == null) return false;
      
      // Parse the date from the order
      DateTime orderDate;
      try {
        if (order.createdAt!.contains('local_')) {
          // Handle local timestamp format
          final parts = order.createdAt!.split('_');
          if (parts.length > 1) {
            final timestamp = int.parse(parts.last);
            orderDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else {
            orderDate = DateTime.now();
            return false;
          }
        } else {
          // Standard ISO date format
          orderDate = DateTime.parse(order.createdAt!);
        }
        
        // Now check if order date is within range
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

  // Filter expenses by explicit date range
  List<Map<String, dynamic>> _filterExpensesByDateRange(
    List<Map<String, dynamic>> expenses, 
    DateTime startDate, 
    DateTime endDate
  ) {
    return expenses.where((expense) {
      final dateStr = expense['date'] as String;
      
      // Parse the date string (expected format: "dd-MM-yyyy")
      DateTime expenseDate;
      try {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          expenseDate = DateTime(year, month, day);
          
          // Check if expense date is within range
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
  
  // Helper to safely get payment values
  double _getPaymentValue(Map<String, dynamic> paymentTotals, String method, String type) {
    try {
      return (paymentTotals[method] as Map<String, dynamic>?)?[type] as double? ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }
  
  // Modified _createReportFromData method to group all "Dining" orders together
  Map<String, dynamic> _createReportFromData(List<Order> orders, List<Map<String, dynamic>> expenses) {
    // Debug logging
    debugPrint('Creating report from ${orders.length} orders and ${expenses.length} expenses');
    
    // 1. Calculate summary statistics
    final totalOrders = orders.length;
    final totalRevenue = orders.fold(0.0, (sum, order) => sum + order.total);
    final totalItemsSold = orders.fold(0, (sum, order) => sum + order.items.length);
    
    // 2. Group orders by service type
    final Map<String, List<Order>> ordersByServiceType = {};
    for (final order in orders) {
      // Normalize the service type - if it contains "Dining", use just "Dining"
      String serviceType = order.serviceType;
      if (serviceType.contains('Dining')) {
        serviceType = 'Dining';
      }
      
      ordersByServiceType.putIfAbsent(serviceType, () => []).add(order);
    }
    
    // 3. Calculate revenue breakdown
    final subtotal = orders.fold(0.0, (sum, order) => sum + order.subtotal);
    final tax = orders.fold(0.0, (sum, order) => sum + order.tax);
    final discount = orders.fold(0.0, (sum, order) => sum + order.discount);
    
    // 4. Calculate payment method totals
    final Map<String, Map<String, double>> paymentTotals = {
      'cash': {'sales': 0.0, 'expenses': 0.0, 'net': 0.0},
      'bank': {'sales': 0.0, 'expenses': 0.0, 'net': 0.0},
      'other': {'sales': 0.0, 'expenses': 0.0, 'net': 0.0},
      'total': {'sales': 0.0, 'expenses': 0.0, 'net': 0.0},
    };
    
    // Sum sales by payment method
    for (final order in orders) {
      final paymentMethod = (order.paymentMethod ?? 'cash').toLowerCase();
      if (paymentMethod == 'cash') {
        paymentTotals['cash']!['sales'] = (paymentTotals['cash']!['sales'] ?? 0.0) + order.total;
      } else if (paymentMethod == 'bank') {
        paymentTotals['bank']!['sales'] = (paymentTotals['bank']!['sales'] ?? 0.0) + order.total;
      } else {
        paymentTotals['other']!['sales'] = (paymentTotals['other']!['sales'] ?? 0.0) + order.total;
      }
      // Update total sales
      paymentTotals['total']!['sales'] = (paymentTotals['total']!['sales'] ?? 0.0) + order.total;
    }
    
    // Sum expenses by account type
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
      // Update total expenses
      paymentTotals['total']!['expenses'] = (paymentTotals['total']!['expenses'] ?? 0.0) + total;
    }
    
    // Calculate net for each payment method
    for (final key in paymentTotals.keys) {
      paymentTotals[key]!['net'] = (paymentTotals[key]!['sales'] ?? 0.0) - (paymentTotals[key]!['expenses'] ?? 0.0);
    }
    
    // 5. Calculate top-selling items
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
    
    // Convert to list and sort by revenue
    final topItems = itemSales.values.toList()
      ..sort((a, b) => (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));
    
    // 6. Prepare service type sales data
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
    
    // 7. Assemble the full report data
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
        _selectedReportType = 'custom'; // Set report type to custom when date range is selected
      });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Text('Reports'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Add PDF save button to app bar
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
          // Report Type Selection
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
                
                // Date/Period Selection
                if (_selectedReportType == 'daily')
                  _buildDateSelector()
                else if (_selectedReportType == 'monthly')
                  _buildMonthSelector()
                else
                  _buildDateRangeSelector(),
              ],
            ),
          ),
          
          // Report Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reportData == null
                    ?  Center(child: Text('No data available'.tr()))
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
            // Initialize date range based on selected report type
            if (type == 'daily') {
              _isCustomDateRange = false;
            } else if (type == 'monthly') {
              _isCustomDateRange = false;
              // Set to first day of current month
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
                  'Selected Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}'.tr(),
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
                  'Month: ${DateFormat('MMMM yyyy').format(_startDate)}'.tr(),
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
        // Set to first day of selected month
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
                          'From: ${DateFormat('dd MMM yyyy').format(_startDate)}'.tr(),
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
                          'To: ${DateFormat('dd MMM yyyy').format(_endDate)}'.tr(),
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
          // Summary Cards
          _buildSummarySection(),
          const SizedBox(height: 24),
          
          // Payment Totals section
          _buildPaymentTotalsSection(),
          const SizedBox(height: 24),
          
          // Service Type Sales Section
          _buildServiceTypeSalesSection(),
          const SizedBox(height: 24),
          
          // Revenue Breakdown
          _buildRevenueSection(),
          const SizedBox(height: 24),
          
          // Top Items
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              ?  Padding(
                  padding: EdgeInsets.all(32),
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
                          // Service type icon and name
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
                                        serviceTypeName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        '$totalOrders orders'.tr(),
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
                          
                          // Revenue
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: topItems.isEmpty
              ?  Padding(
                  padding: EdgeInsets.all(32),
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
                      subtitle: Text('Price: ${price.toStringAsFixed(3)}'.tr()),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$quantity sold'.tr(),
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
    
    // Get payment totals from the report data
    final paymentTotals = _reportData!['paymentTotals'] as Map<String, dynamic>?;
    
    if (paymentTotals == null) {
      return  Center(child: Text('Payment data not available'.tr()));
    }
    
    // Format currency
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(
          'Cash and Bank Sales'.tr(),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        // Cash and Bank Summary Table
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Table header
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
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Revenue'.tr(),
                        style: TextStyle(
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
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Cash row
              _buildPaymentRow(
                'Total Cash Sales'.tr(), 
                _getPaymentValue(paymentTotals, 'cash', 'sales'),
                _getPaymentValue(paymentTotals, 'cash', 'expenses'),
                currencyFormat,
                Colors.grey.shade100,
              ),
              
              // Bank row
              _buildPaymentRow(
                'Total Bank Sales'.tr(), 
                _getPaymentValue(paymentTotals, 'bank', 'sales'),
                _getPaymentValue(paymentTotals, 'bank', 'expenses'),
                currencyFormat,
                Colors.white,
              ),
              
              // Divider
              Divider(height: 1, color: Colors.grey.shade300),
              
              // Total row
              _buildPaymentRow(
                'Total Sales'.tr(), 
                _getPaymentValue(paymentTotals, 'total', 'sales'),
                _getPaymentValue(paymentTotals, 'total', 'expenses'),
                currencyFormat,
                Colors.blue.shade50,
                isTotal: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper to build a single row in the payment table
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

  // Helper method to get service type icon
  IconData _getServiceTypeIcon(String serviceType) {
    if (serviceType.contains('Dining')) {
      return Icons.restaurant;
    } else if (serviceType.contains('Delivery')) {
      return Icons.delivery_dining;
    } else if (serviceType.contains('Takeout')) {
      return Icons.takeout_dining;
    } else if (serviceType.contains('Drive')) {
      return Icons.drive_eta;
    } else if (serviceType.contains('Catering')) {
      return Icons.cake;
    } else {
      return Icons.receipt;
    }
  }

  // Helper method to get service type color
  Color _getServiceTypeColor(String serviceType) {
    if (serviceType.contains('Dining')) {
      return Colors.blue;
    } else if (serviceType.contains('Delivery')) {
      return Colors.orange;
    } else if (serviceType.contains('Takeout')) {
      return Colors.green;
    } else if (serviceType.contains('Catering')) {
      return Colors.purple;
    } else if (serviceType.contains('Drive' )) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }
}

  