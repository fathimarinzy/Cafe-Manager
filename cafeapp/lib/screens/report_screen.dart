import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/local_order_repository.dart';
import '../repositories/local_expense_repository.dart';
import '../models/order.dart';

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
    
  // Helper method to get the number of days in a month
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
          SnackBar(content: Text('Error loading report: $e')),
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
                        'Monthly Report',
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
                  'Month: ${DateFormat('MMMM yyyy').format(_startDate)}',
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
                'Total Orders',
                '${summary['totalOrders'] ?? 0}',
                Icons.receipt_long,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                'Total Revenue',
                '${(summary['totalRevenue'] as double? ?? 0.0).toStringAsFixed(3)}',
                Icons.attach_money,
                Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                'Items Sold',
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
              _buildRevenueRow('Subtotal', revenue['subtotal'] as double? ?? 0.0),
              const SizedBox(height: 8),
              _buildRevenueRow('Tax', revenue['tax'] as double? ?? 0.0),
              const SizedBox(height: 8),
              _buildRevenueRow('Discounts', revenue['discounts'] as double? ?? 0.0),
              const Divider(),
              _buildRevenueRow('Total Revenue', revenue['total'] as double? ?? 0.0, isTotal: true),
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
    
    // Get payment totals from the report data
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
                _getPaymentValue(paymentTotals, 'cash', 'sales'),
                _getPaymentValue(paymentTotals, 'cash', 'expenses'),
                currencyFormat,
                Colors.grey.shade100,
              ),
              
              // Bank row
              _buildPaymentRow(
                'Total Bank Sales', 
                _getPaymentValue(paymentTotals, 'bank', 'sales'),
                _getPaymentValue(paymentTotals, 'bank', 'expenses'),
                currencyFormat,
                Colors.white,
              ),
              
              // Divider
              Divider(height: 1, color: Colors.grey.shade300),
              
              // Total row
              _buildPaymentRow(
                'Total Sales', 
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

  // Helper to safely get payment values
  double _getPaymentValue(Map<String, dynamic> paymentTotals, String method, String type) {
    try {
      return (paymentTotals[method] as Map<String, dynamic>?)?[type] as double? ?? 0.0;
    } catch (e) {
      return 0.0;
    }
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
    } else if (serviceType.contains('Drive')) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }
}

  