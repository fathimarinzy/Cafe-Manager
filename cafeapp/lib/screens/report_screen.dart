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
  
  // Cache to store previously loaded reports
  final Map<String, Map<String, dynamic>> _reportCache = {};
  final Map<String, Map<String, dynamic>> _paymentTotalsCache = {};
  
  // Date range for custom period reports
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
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

  // Load report and payment totals in a single operation
  Future<void> _loadReport() async {
    if (_isLoading) return; // Prevent multiple simultaneous loads
    
    setState(() {
      _isLoading = true;
    });

    try {
      final String cacheKey = _getCacheKey(
        _selectedReportType, 
        _selectedReportType == 'daily' ? _selectedDate : _startDate,
        endDate: _isCustomDateRange ? _endDate : null
      );
      
      // Check if we have cached data
      if (_reportCache.containsKey(cacheKey) && _paymentTotalsCache.containsKey(cacheKey)) {
        setState(() {
          _reportData = _reportCache[cacheKey];
          _isLoading = false;
        });
        return;
      }

      // Load both report data and payment totals concurrently
      final reportFuture = _loadReportData();
      final paymentTotalsFuture = _loadPaymentTotalsData();
      
      // Wait for both futures to complete
      final results = await Future.wait([reportFuture, paymentTotalsFuture]);
      
      // Store results in cache
      _reportCache[cacheKey] = results[0] as Map<String, dynamic>;
      _paymentTotalsCache[cacheKey] = results[1] as Map<String, dynamic>;
      
      // Only update state once with both results
      if (mounted) {
        setState(() {
          _reportData = _reportCache[cacheKey];
          _reportData!['paymentTotals'] = _paymentTotalsCache[cacheKey];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report: $e')),
        );
      }
    }
  }

  // Load just the report data (without updating state)
  Future<Map<String, dynamic>> _loadReportData() async {
    if (_selectedReportType == 'daily') {
      return await _apiService.getDailyReport(_selectedDate);
    } else if (_isCustomDateRange) {
      return await _apiService.getCustomRangeReport(_startDate, _endDate);
    } else {
      return await _apiService.getMonthlyReport(_startDate);
    }
  }

  // Load just the payment totals data (without updating state)
  Future<Map<String, dynamic>> _loadPaymentTotalsData() async {
    try {
      if (_selectedReportType == 'daily') {
        return await _apiService.getPaymentTotals(_selectedDate);
      } else if (_isCustomDateRange) {
        return await _apiService.getPaymentTotals(_startDate, endDate: _endDate);
      } else {
        return await _apiService.getPaymentTotals(_selectedDate, isMonthly: true);
      }
    } catch (e) {
      debugPrint('Error loading payment totals: $e');
      // Return empty data structure on error
      return {
        'cash': {'sales': 0.0, 'expenses': 0.0, 'net': 0.0},
        'bank': {'sales': 0.0, 'expenses': 0.0, 'net': 0.0},
        'other': {'sales': 0.0, 'expenses': 0.0, 'net': 0.0},
        'total': {'sales': 0.0, 'expenses': 0.0, 'net': 0.0},
      };
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

  Widget _buildReportTypeCard(String type, String title, IconData icon, bool isSelected) {
    return InkWell(
      onTap: () {
        if (_selectedReportType != type) {
          setState(() {
            _selectedReportType = type;
            // Reset custom date range flag when switching report types
            if (type == 'daily') {
              _isCustomDateRange = false;
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
          
          // Payment Totals section - now using cached data
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
        // const Text(
        //   'Summary',
        //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        // ),
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
              'Total Sales ',
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
    
    // Get payment totals from the unified report data structure
    final paymentTotals = _reportData!['paymentTotals'] as Map<String, dynamic>?;
    
    if (paymentTotals == null) {
      return const Center(child: Text('Payment data not available'));
    }
    
    // Format currency
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cash and Bank Sales',
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
                        'Revenue',
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
                  ],
                ),
              ),
              
              // Cash row
              _buildPaymentRow(
                ' Total Cash Sales', 
                _toDouble(paymentTotals['cash']['sales']),
                _toDouble(paymentTotals['cash']['expenses']),
                currencyFormat,
                Colors.grey.shade100,
              ),
              
              // Bank row
              _buildPaymentRow(
                'Total Bank Sales', 
                _toDouble(paymentTotals['bank']['sales']),
                _toDouble(paymentTotals['bank']['expenses']),
                currencyFormat,
                Colors.white,
              ),
              
              // Divider
              Divider(height: 1, color: Colors.grey.shade300),
              
              // Total row
              _buildPaymentRow(
                'Total Sales', 
                _toDouble(paymentTotals['total']['sales']),
                _toDouble(paymentTotals['total']['expenses']),
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