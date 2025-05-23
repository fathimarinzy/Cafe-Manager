import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../providers/settings_provider.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  Map<String, dynamic>? _reportData;
  String _selectedReportType = 'daily';
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _paymentTotals;
  bool _isLoadingPaymentTotals = false;
  
  // Date range for custom period reports
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30)); // Default to last 30 days
  DateTime _endDate = DateTime.now();
  bool _isCustomDateRange = false;
  
  // Helper method to safely convert to double
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Helper method to safely convert to int
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  @override
  void initState() {
    super.initState();
    _loadReport();
  }
// Add this method to load payment totals
Future<void> _loadPaymentTotals() async {
  setState(() {
    _isLoadingPaymentTotals = true;
  });

  try {
    if (_selectedReportType == 'daily') {
      _paymentTotals = await _apiService.getPaymentTotals(_selectedDate);
    } else if (_isCustomDateRange) {
      _paymentTotals = await _apiService.getPaymentTotals(_startDate, endDate: _endDate);
    } else {
      _paymentTotals = await _apiService.getPaymentTotals(_startDate, isMonthly: true);
    }
    
    setState(() {
      _isLoadingPaymentTotals = false;
    });
  } catch (e) {
    setState(() {
      _isLoadingPaymentTotals = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading payment totals: $e')),
      );
    }
  }
}
  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      //  _errorMessage = '';
    _paymentTotals = null; 
    });

    try {
      Map<String, dynamic> data;
      if (_selectedReportType == 'daily') {
        data = await _apiService.getDailyReport(_selectedDate);
      } else if (_isCustomDateRange) {
        // Load custom date range report
        data = await _apiService.getCustomRangeReport(_startDate, _endDate);
      } else {
        // Regular monthly report
        data = await _apiService.getMonthlyReport(_startDate);
      }
      
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report: $e')),
        );
      }
    }
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
      });
      _loadReport();
    }
  }
  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                // const Text(
                //   'Report Type',
                //   style: TextStyle(
                //     fontSize: 16,
                //     fontWeight: FontWeight.bold,
                //   ),
                // ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildReportTypeCard(
                        'daily',
                        'Daily Report',
                        Icons.today,
                        _selectedReportType == 'daily',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildReportTypeCard(
                        'monthly',
                        'Monthly Report',
                        Icons.date_range,
                        _selectedReportType == 'monthly',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Date/Period Selection
                if (_selectedReportType == 'daily')
                  _buildDateSelector()
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
                    ? const Center(child: Text('No data available'))
                    : _buildReportContent(),
          ),
        ],
      ),
    );
  }
//   Widget _buildDateRangePicker() {
//   return Theme(
//     data: ThemeData.light().copyWith(
//       colorScheme: ColorScheme.light(
//         primary: Colors.blue.shade700,
//         onPrimary: Colors.white,
//         surface: Colors.blue.shade50,
//         onSurface: Colors.black87,
//       ),
//       dialogBackgroundColor: Colors.white,
//     ),
//     child: DateRangePickerDialog(
//       initialDateRange: DateTimeRange(
//         start: _startDate,
//         end: _endDate,
//       ),
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now(),
//       saveText: 'APPLY',
//       confirmText: 'APPLY',
//       cancelText: 'CANCEL',
//       fieldStartLabelText: 'START DATE',
//       fieldEndLabelText: 'END DATE',
//     ),
//   );
// }

  Widget _buildReportTypeCard(String type, String title, IconData icon, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedReportType = type;
          // Reset custom date range flag when switching report types
          if (type == 'daily') {
            _isCustomDateRange = false;
          }
        });
        _loadReport();
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
                  'Selected Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}',
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
          Row(
            children: [
              // Icon(
              //   Icons.date_range,
              //   color: _isCustomDateRange ? Colors.blue.shade700 : Colors.grey.shade600,
              // ),
              const SizedBox(width: 8),
              // Text(
              //   'Custom Date Range',
              //   style: TextStyle(
              //     fontSize: 16,
              //     fontWeight: _isCustomDateRange ? FontWeight.bold : FontWeight.normal,
              //     color: _isCustomDateRange ? Colors.blue.shade700 : Colors.black87,
              //   ),
              // ),
            ],
          ),
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
                        'From: ${DateFormat('dd MMM yyyy').format(_startDate)}',
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
                        'To: ${DateFormat('dd MMM yyyy').format(_endDate)}',
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
// Add this method to include a period label in the report header
// Widget _buildReportPeriodHeader() {
//   // For daily report
//   if (_selectedReportType == 'daily') {
//     return Text(
//       'Report for ${DateFormat('dd MMMM yyyy').format(_selectedDate)}',
//       style: TextStyle(
//         fontSize: 14,
//         color: Colors.grey.shade700,
//         fontStyle: FontStyle.italic,
//       ),
//     );
//   } 
//   // For custom date range report
//   else if (_isCustomDateRange) {
//     return Text(
//       'Report from ${DateFormat('dd MMM yyyy').format(_startDate)} to ${DateFormat('dd MMM yyyy').format(_endDate)}',
//       style: TextStyle(
//         fontSize: 14,
//         color: Colors.grey.shade700,
//         fontStyle: FontStyle.italic,
//       ),
//     );
//   }
//   // For regular monthly report
//   else {
//     return Text(
//       'Report for ${DateFormat('MMMM yyyy').format(_startDate)}',
//       style: TextStyle(
//         fontSize: 14,
//         color: Colors.grey.shade700,
//         fontStyle: FontStyle.italic,
//       ),
//     );
//   }
// }
  Widget _buildReportContent() {
    if (_reportData == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Report period header
        // _buildReportPeriodHeader(),
        // const SizedBox(height: 16),
        
          // Summary Cards
          _buildSummarySection(),
          const SizedBox(height: 24),
           // Add the payment totals section
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

  // UPDATED: Build summary section with safe type conversion
  Widget _buildSummarySection() {
    final summary = _reportData!['summary'] ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Summary',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Orders',
                '${_toInt(summary['totalOrders'])}',
                Icons.receipt_long,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                'Total Revenue',
                '${_toDouble(summary['totalRevenue']).toStringAsFixed(3)}',
                Icons.attach_money,
                Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                'Items Sold',
                '${_toInt(summary['totalItemsSold'])}',
                Icons.inventory,
                Colors.purple,
              ),
            ),
          ],
        ),
        // const SizedBox(height: 12),
        Row(
          children: [
            // Expanded(
            //   child: _buildSummaryCard(
            //     'Average Order',
            //     '${_toDouble(summary['averageOrderValue']).toStringAsFixed(3)}',
            //     Icons.trending_up,
            //     Colors.orange,
            //   ),
            // ),
            
          ],
        ),
        
        // Add growth metrics for period reports
        // if (_selectedReportType == 'monthly' && summary['revenueGrowth'] != null) ...[
        //   const SizedBox(height: 12),
        //   Row(
        //     children: [
        //       Expanded(
        //         child: _buildSummaryCard(
        //           'Revenue Growth',
        //           '${_toDouble(summary['revenueGrowth']).toStringAsFixed(1)}%',
        //           Icons.trending_up,
        //           _toDouble(summary['revenueGrowth']) >= 0 ? Colors.green : Colors.red,
        //         ),
        //       ),
        //       const SizedBox(width: 12),
        //       Expanded(
        //         child: _buildSummaryCard(
        //           'Order Growth',
        //           '${_toDouble(summary['ordersGrowth']).toStringAsFixed(1)}%',
        //           Icons.show_chart,
        //           _toDouble(summary['ordersGrowth']) >= 0 ? Colors.green : Colors.red,
        //         ),
        //       ),
        //     ],
        //   ),
        // ],
      ],
    );
  }


  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
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
                    color: color.withOpacity(0.8),
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
            const Text(
              'Sales by Service Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            // Text(
            //   '${serviceTypeSales.length} service types',
            //   style: TextStyle(color: Colors.grey.shade600),
            // ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: serviceTypeSales.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No sales data found')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: serviceTypeSales.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final serviceType = serviceTypeSales[index] as Map<String, dynamic>;
                    final serviceTypeName = serviceType['serviceType']?.toString() ?? '';
                    final totalOrders = _toInt(serviceType['totalOrders']);
                    final totalRevenue = _toDouble(serviceType['totalRevenue']);
                    // final averageOrderValue = _toDouble(serviceType['averageOrderValue']);
                    // final percentage = _toDouble(serviceType['percentage']);
                    
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
                                  backgroundColor: _getServiceTypeColor(serviceTypeName).withOpacity(0.2),
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
                                        '$totalOrders orders',
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
                          
                          // Revenue and percentage
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
                                // Text(
                                //   '${percentage.toStringAsFixed(1)}% of total',
                                //   style: TextStyle(
                                //     color: Colors.grey.shade600,
                                //     fontSize: 12,
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                          
                          // Average order value
                          // Expanded(
                          //   flex: 2,
                          //   child: Column(
                          //     crossAxisAlignment: CrossAxisAlignment.end,
                          //     children: [
                          //       Text(
                          //         'Avg: ${averageOrderValue.toStringAsFixed(3)}',
                          //         style: TextStyle(
                          //           color: Colors.grey.shade700,
                          //           fontSize: 14,
                          //           fontWeight: FontWeight.w500,
                          //         ),
                          //       ),
                          //       // Progress bar for percentage
                          //       const SizedBox(height: 4),
                          //       Container(
                          //         width: 80,
                          //         height: 4,
                          //         decoration: BoxDecoration(
                          //           color: Colors.grey.shade200,
                          //           borderRadius: BorderRadius.circular(2),
                          //         ),
                          //         child: FractionallySizedBox(
                          //           alignment: Alignment.centerLeft,
                          //           widthFactor: percentage / 100,
                          //           child: Container(
                          //             decoration: BoxDecoration(
                          //               color: _getServiceTypeColor(serviceTypeName),
                          //               borderRadius: BorderRadius.circular(2),
                          //             ),
                          //           ),
                          //         ),
                          //       ),
                          //     ],
                          //   ),
                          // ),
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
        const Text(
          'Revenue Breakdown',
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
              _buildRevenueRow('Subtotal', _toDouble(revenue['subtotal'])),
              const SizedBox(height: 8),
              _buildRevenueRow('Tax', _toDouble(revenue['tax'])),
              const SizedBox(height: 8),
              _buildRevenueRow('Discounts', _toDouble(revenue['discounts'])),
              const Divider(),
              _buildRevenueRow('Total Revenue', _toDouble(revenue['total']), isTotal: true),
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
        const Text(
          'Top Selling Items',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: topItems.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No items data available')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topItems.length > 5 ? 5 : topItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = topItems[index] as Map<String, dynamic>;
                    final name = item['name']?.toString() ?? '';
                    final quantity = _toInt(item['quantity']);
                    final price = _toDouble(item['price']);
                    final totalRevenue = _toDouble(item['total_revenue']);
                    
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
                      subtitle: Text('Price: ${price.toStringAsFixed(3)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$quantity sold',
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
  
  // Get payment totals from API if not already loaded
  if (_paymentTotals == null) {
    _loadPaymentTotals();
    return const Center(child: CircularProgressIndicator());
  }
  
  // Format currency
  final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Cash and Bank Summary',
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
                      'Payment Method',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Sales',
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
                      'Expenses',
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
                      'Net',
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
              'Cash', 
              _paymentTotals!['cash']['sales'],
              _paymentTotals!['cash']['expenses'],
              _paymentTotals!['cash']['net'],
              currencyFormat,
              Colors.grey.shade100,
            ),
            
            // Bank row
            _buildPaymentRow(
              'Bank', 
              _paymentTotals!['bank']['sales'],
              _paymentTotals!['bank']['expenses'],
              _paymentTotals!['bank']['net'],
              currencyFormat,
              Colors.white,
            ),
            
            // Other row
            _buildPaymentRow(
              'Other', 
              _paymentTotals!['other']['sales'],
              _paymentTotals!['other']['expenses'],
              _paymentTotals!['other']['net'],
              currencyFormat,
              Colors.grey.shade100,
            ),
            
            // Divider
            Divider(height: 1, color: Colors.grey.shade300),
            
            // Total row
            _buildPaymentRow(
              'Total', 
              _paymentTotals!['total']['sales'],
              _paymentTotals!['total']['expenses'],
              _paymentTotals!['total']['net'],
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
  double net,
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
        Expanded(
          flex: 2,
          child: Text(
            formatter.format(net),
            style: TextStyle(
              color: net >= 0 ? Colors.blue.shade700 : Colors.red.shade700,
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
    switch (serviceType.toLowerCase()) {
      case 'dining':
        return Icons.restaurant;
      case 'delivery':
        return Icons.delivery_dining;
      case 'takeout':
        return Icons.takeout_dining;
      case 'catering':
        return Icons.cake;
      case 'drive through':
        return Icons.drive_eta;
      default:
        return Icons.receipt;
    }
  }

  // Helper method to get service type color
  Color _getServiceTypeColor(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'dining':
        return Colors.blue;
      case 'delivery':
        return Colors.orange;
      case 'takeout':
        return Colors.green;
      case 'catering':
        return Colors.purple;
      case 'drive through':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}