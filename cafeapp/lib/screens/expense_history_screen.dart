import 'package:cafeapp/utils/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/local_expense_repository.dart';
import '../screens/expense_screen.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  final LocalExpenseRepository _repository = LocalExpenseRepository();
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'Today'; // Keep internal filter in English
  final List<String> _filterOptions = ['Today', 'This Week', 'This Month', 'All Expenses']; // Keep internal values in English
  final ScrollController _scrollController = ScrollController();
  
  // For date formatting
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '',
    decimalDigits: 3,
  );

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Loading expenses...');
      final expenses = await _repository.getAllExpenses();
      debugPrint('Successfully loaded ${expenses.length} expenses');
      
      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading expenses: $e');
      debugPrint('Stack trace: $stackTrace');
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading expenses'.tr()),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _deleteExpense(int id) async {
    try {
      final success = await _repository.deleteExpense(id);
      if (success) {
        setState(() {
          _expenses.removeWhere((expense) => expense['id'] == id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 16),
                  Text('Expense deleted successfully'.tr()),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 16),
                  Text('Failed to delete expense'.tr()),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(child: Text('Error deleting expense'.tr())),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _editExpense(Map<String, dynamic> expense) {
    // Navigate to ExpenseScreen with expense data for editing
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpenseScreen(expenseToEdit: expense),
      ),
    ).then((_) => _loadExpenses()); // Refresh list after returning
  }

  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete, color: Colors.red),
            const SizedBox(width: 8),
            Text('Delete Expense'.tr()),
          ],
        ),
        content: Text('Are you sure you want to delete this expense record? This action cannot be undone.'.tr()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteExpense(id);
            },
            child: Text('Delete'.tr()),
          ),
        ],
      ),
    );
  }

  // Helper method to get translated account type for display
  String _getTranslatedAccountType(String accountType) {
    switch (accountType) {
      case 'Cash Account':
        return 'Cash Account'.tr();
      case 'Bank Account':
        return 'Bank Account'.tr();
      default:
        return accountType;
    }
  }

  // Helper method to get translated cashier type for display
  String _getTranslatedCashierType(String cashierType) {
    switch (cashierType) {
      case 'Cashier':
        return 'Cashier'.tr();
      case 'Salesman':
        return 'Salesman'.tr();
      default:
        return cashierType;
    }
  }

  // Helper method to get translated category name for display
  String _getTranslatedCategory(String category) {
    switch (category) {
      case 'Shop Expenses':
        return 'Shop Expenses'.tr();
      case 'Office Expenses':
        return 'Office Expenses'.tr();
      case 'Food Expenses':
        return 'Food Expenses'.tr();
      case 'Transport':
        return 'Transport'.tr();
      case 'Utilities':
        return 'Utilities'.tr();
      case 'Rent':
        return 'Rent'.tr();
      case 'Salaries':
        return 'Salaries'.tr();
      case 'Kitchen Expenses':
        return 'Kitchen Expenses'.tr();
      case 'Raw Materials':
        return 'Raw Materials'.tr();
      case 'Maintenance':
        return 'Maintenance'.tr();
      case 'Equipments':
        return 'Equipments'.tr();
      case 'Cleaning Supplies':
        return 'Cleaning Supplies'.tr();
      case 'Others':
        return 'Others'.tr();
      default:
        return category;
    }
  }

  // Helper method to get translated filter name for display
  String _getTranslatedFilterName(String filter) {
    switch (filter) {
      case 'Today':
        return 'Today'.tr();
      case 'This Week':
        return 'This Week'.tr();
      case 'This Month':
        return 'This Month'.tr();
      case 'All Expenses':
        return 'All Expenses'.tr();
      default:
        return filter;
    }
  }

  void _viewExpenseDetails(Map<String, dynamic> expense) {
    final date = expense['date'] as String;
    final cashier = expense['cashier'] as String;
    final accountType = expense['accountType'] as String;
    final total = expense['grandTotal'] as double;
    final items = expense['items'] as List<dynamic>;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long, size: 24, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Expense Details'.tr(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              'Date'.tr(),
                              date,
                              Icons.calendar_today,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              'Account'.tr(),
                              _getTranslatedAccountType(accountType),
                              Icons.account_balance,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              'Cashier'.tr(),
                              _getTranslatedCashierType(cashier),
                              Icons.person,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              'Total'.tr(),
                              _currencyFormat.format(total),
                              Icons.attach_money,
                              isHighlighted: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Items List
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Expenses'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...items.map((item) => _buildItemCard(item)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildInfoCard(String label, String value, IconData icon, {bool isHighlighted = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.blue.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: isHighlighted ? Colors.blue.shade800 : Colors.grey.shade700),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isHighlighted ? Colors.blue.shade800 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? Colors.blue.shade800 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final slNo = item['slNo'] as int;
    final account = item['account'] as String;
    final narration = item['narration'] as String;
    final remarks = item['remarks'] as String?;
    final amount = item['amount'] as num;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    slNo.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTranslatedCategory(account),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        narration,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (remarks != null && remarks.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  remarks,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _currencyFormat.format(amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredExpenses() {
    List<Map<String, dynamic>> filtered = List.from(_expenses);
    
    // Apply date filter
    if (_selectedFilter != 'All Expenses') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      filtered = filtered.where((expense) {
        final dateStr = expense['date'] as String;
        DateTime? date;
        try {
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]) ?? 1;
            final month = int.tryParse(parts[1]) ?? 1;
            final year = int.tryParse(parts[2]) ?? 2000;
            date = DateTime(year, month, day);
          }
        } catch (e) {
          debugPrint('Error parsing date $dateStr: $e');
          try {
            date = DateTime.parse(dateStr);
          } catch (e) {
            debugPrint('Failed to parse date in any format: $dateStr');
            return false;
          }
        }
        
        if (date == null) return false;
        
        switch (_selectedFilter) {
          case 'Today':
            return date.year == today.year && 
                   date.month == today.month && 
                   date.day == today.day;
          case 'This Week':
            final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
            return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) && 
                   date.isBefore(startOfWeek.add(const Duration(days: 7)));
          case 'This Month':
            return date.year == today.year && date.month == today.month;
          default:
            return true;
        }
      }).toList();
    }
    
    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((expense) {
        if (expense['date'].toString().toLowerCase().contains(query) ||
            expense['cashier'].toString().toLowerCase().contains(query) ||
            expense['accountType'].toString().toLowerCase().contains(query)) {
          return true;
        }
        
        final items = expense['items'] as List<dynamic>;
        for (var item in items) {
          if (item['account'].toString().toLowerCase().contains(query) ||
              item['narration'].toString().toLowerCase().contains(query)) {
            return true;
          }
        }
        
        return false;
      }).toList();
    }
    
    return filtered;
  }

  // Helper method for items count text
  String getItemsCountText(int count) {
    if (count == 1) {
      return '1 ${'item'.tr()}';
    } else {
      return '$count ${'items'.tr()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredExpenses = _getFilteredExpenses();
    
    final int totalItemsCount = filteredExpenses.fold<int>(
      0,
      (sum, expense) {
        final items = expense['items'] as List<dynamic>;
        return sum + items.length;
      },
    );

    final double totalAmount = filteredExpenses.fold<double>(
      0,
      (sum, expense) => sum + (expense['grandTotal'] as double),
    );
    
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          'Expenses'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Summary Card - Now showing filtered results
          if (!_isLoading && _expenses.isNotEmpty)
          Container(
              margin: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 55),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Expenses'.tr(),
                            totalItemsCount.toString(),
                            Icons.receipt_long,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Amount'.tr(),
                            _currencyFormat.format(totalAmount),
                            Icons.attach_money,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
        
          // Search and Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search expenses...'.tr(),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                
                // Filter chips
                const SizedBox(height: 12),
                Container(
                  alignment: Alignment.center,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: _filterOptions.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return ChoiceChip(
                        label: Text(_getTranslatedFilterName(filter)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedFilter = filter;
                            });
                          }
                        },
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: Colors.blue.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.blue.shade800 : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Expense list
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading expenses...'.tr(),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : filteredExpenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No expenses found'.tr(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty || _selectedFilter != 'All Expenses'
                                  ? ''
                                  : 'Tap the + button to add a new expense'.tr(),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: filteredExpenses.length,
                        itemBuilder: (context, index) {
                          final expense = filteredExpenses[index];
                          final expenseId = expense['id'] as int;
                          final date = expense['date'] as String;
                          final accountType = expense['accountType'] as String;
                          final items = expense['items'] as List<dynamic>;
                          
                          // Format date better if needed
                          String formattedDate = date;
                          try {
                            final parts = date.split('-');
                            if (parts.length == 3) {
                              final day = int.tryParse(parts[0]);
                              final month = int.tryParse(parts[1]);
                              final year = int.tryParse(parts[2]);
                              
                              if (day != null && month != null && year != null) {
                                final dateObj = DateTime(year, month, day);
                                formattedDate = _dateFormat.format(dateObj);
                              }
                            } else {
                              final dateObj = DateTime.parse(date);
                              formattedDate = _dateFormat.format(dateObj);
                            }
                          } catch (e) {
                            debugPrint('Error formatting date: $e');
                          }
                          
                          return Dismissible(
                            key: Key('expense-$expenseId'),
                            background: Container(
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.delete, color: Colors.white),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Delete'.tr(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (direction) async {
                              _showDeleteConfirmation(expenseId);
                              return false; // Don't dismiss automatically
                            },
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              margin: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                onTap: () => _viewExpenseDetails(expense),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Left Column - Date and Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.calendar_today,
                                                      size: 16,
                                                      color: Colors.blue.shade700,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      formattedDate,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.account_balance,
                                                      size: 16,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      _getTranslatedAccountType(accountType),
                                                      style: TextStyle(
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.receipt,
                                                      size: 16,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      getItemsCountText(items.length),
                                                      style: TextStyle(
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Right Column - Action Buttons
                                          Column(
                                            children: [
                                              // Edit Button
                                              ElevatedButton.icon(
                                                onPressed: () => _editExpense(expense),
                                                icon: const Icon(Icons.edit, size: 16),
                                                label: Text('Edit'.tr()),
                                                style: ElevatedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              // Delete Button
                                              ElevatedButton.icon(
                                                onPressed: () => _showDeleteConfirmation(expenseId),
                                                icon: const Icon(Icons.delete, size: 16),
                                                label: Text('Delete'.tr()),
                                                style: ElevatedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed('/expense').then((_) => _loadExpenses());
        },
        icon: const Icon(Icons.add),
        label: Text('Add Expense'.tr()),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
 
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          border: Border.all(color: color.withAlpha(77)),
          borderRadius: BorderRadius.circular(18),
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
      ),
    );
  }
}