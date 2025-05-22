// lib/screens/report_screen.dart
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
  DateTime _selectedMonth = DateTime.now();
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

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> data;
      if (_selectedReportType == 'daily') {
        data = await _apiService.getDailyReport(_selectedDate);
      } else {
        data = await _apiService.getMonthlyReport(_selectedMonth);
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

  Future<void> _selectMonth() async {
  await showDialog<DateTime>(
    context: context,
    builder: (BuildContext context) {
      return _MonthYearPickerDialog(
        initialDate: _selectedMonth,
        onDateSelected: (DateTime selectedDate) {
          setState(() {
            _selectedMonth = selectedDate;
          });
          _loadReport();
        },
      );
    },
  );
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
                const Text(
                  'Report Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                        Icons.calendar_month,
                        _selectedReportType == 'monthly',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Date/Month Selection
                if (_selectedReportType == 'daily')
                  _buildDateSelector()
                else
                  _buildMonthSelector(),
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
        setState(() {
          _selectedReportType = type;
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
                'Selected Month: ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
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
          
          // Orders Section
          _buildOrdersSection(),
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
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Total Revenue',
              '${_toDouble(summary['totalRevenue']).toStringAsFixed(3)}',
              Icons.attach_money,
              Colors.green,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Average Order',
              '${_toDouble(summary['averageOrderValue']).toStringAsFixed(3)}',
              Icons.trending_up,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
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
      // Add growth metrics for monthly reports
      if (_selectedReportType == 'monthly' && summary['revenueGrowth'] != null) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Revenue Growth',
                '${_toDouble(summary['revenueGrowth']).toStringAsFixed(1)}%',
                Icons.trending_up,
                _toDouble(summary['revenueGrowth']) >= 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Order Growth',
                '${_toDouble(summary['ordersGrowth']).toStringAsFixed(1)}%',
                Icons.show_chart,
                _toDouble(summary['ordersGrowth']) >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ],
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
  // UPDATED: Build orders section with safe type conversion
Widget _buildOrdersSection() {
  final orders = _reportData!['orders'] as List? ?? [];
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Recent Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            '${orders.length} orders',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: orders.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No orders found')),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length > 10 ? 10 : orders.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final order = orders[index] as Map<String, dynamic>;
                  final orderId = _toInt(order['id']);
                  final serviceType = order['serviceType']?.toString() ?? '';
                  final total = _toDouble(order['total']);
                  final status = order['status']?.toString() ?? 'pending';
                  final createdAt = order['createdAt']?.toString() ?? DateTime.now().toIso8601String();
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(status).withOpacity(0.2),
                      child: Text(
                        '#${orderId.toString().padLeft(4, '0')}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ),
                    title: Text(serviceType),
                    subtitle: Text(
                      DateFormat('dd-MM-yyyy HH:mm').format(
                        DateTime.parse(createdAt),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          total.toStringAsFixed(3),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.bold,
                            ),
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

  
 // UPDATED: Build revenue section with safe type conversion
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

  // UPDATED: Build top items section with safe type conversion
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

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
// Add this custom Month/Year picker widget at the end of your report_screen.dart file
class _MonthYearPickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const _MonthYearPickerDialog({
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int selectedYear;
  late int selectedMonth;
  late PageController _pageController;

  final List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialDate.year;
    selectedMonth = widget.initialDate.month;
    _pageController = PageController(initialPage: selectedYear - 2020);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Month & Year',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Year selector
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        selectedYear--;
                      });
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                  Text(
                    selectedYear.toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: selectedYear < DateTime.now().year ? () {
                      setState(() {
                        selectedYear++;
                      });
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } : null,
                  ),
                ],
              ),
            ),
            
            const Divider(),
            
            // Month grid
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    selectedYear = 2020 + index;
                  });
                },
                itemCount: DateTime.now().year - 2020 + 1,
                itemBuilder: (context, yearIndex) {
                  final year = 2020 + yearIndex;
                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, monthIndex) {
                      final month = monthIndex + 1;
                      final isSelected = selectedMonth == month && selectedYear == year;
                      final now = DateTime.now();
                      final isDisabled = year > now.year || 
                          (year == now.year && month > now.month);
                      
                      return InkWell(
                        onTap: isDisabled ? null : () {
                          setState(() {
                            selectedMonth = month;
                            selectedYear = year;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.blue.shade700 
                                : isDisabled
                                    ? Colors.grey.shade200
                                    : Colors.blue.shade50,
                            border: Border.all(
                              color: isSelected 
                                  ? Colors.blue.shade700 
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              months[monthIndex],
                              style: TextStyle(
                                color: isSelected 
                                    ? Colors.white 
                                    : isDisabled
                                        ? Colors.grey.shade500
                                        : Colors.blue.shade700,
                                fontWeight: isSelected 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final selectedDate = DateTime(selectedYear, selectedMonth, 1);
                    widget.onDateSelected(selectedDate);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Select'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}