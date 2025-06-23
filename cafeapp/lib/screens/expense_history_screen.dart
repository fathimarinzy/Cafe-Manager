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
  String _selectedFilter = 'Today';
  final List<String> _filterOptions = ['Today', 'This Week', 'This Month', 'All Expenses'];
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
            content: Text('Error loading expenses: ${e.toString()}'),
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
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 16),
                  Text('Expense deleted successfully'),
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
              content: const Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 16),
                  Text('Failed to delete expense'),
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
                Expanded(child: Text('Error deleting expense: $e')),
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
        title: const Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Expense'),
          ],
        ),
        content: const Text('Are you sure you want to delete this expense record? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
                          const Text(
                            'Expense Details',
                            style: TextStyle(
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
                              'Date',
                              date,
                              Icons.calendar_today,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              'Account',
                              accountType,
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
                              'Cashier',
                              cashier,
                              Icons.person,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              'Total',
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
                      const Text(
                        'Expenses',
                        style: TextStyle(
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
            color: Colors.black.withOpacity(0.05),
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
                        account,
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
        // Parsing the date from "dd-MM-yyyy" format (based on your ExpenseScreen)
        DateTime? date;
        try {
          // First try with dd-MM-yyyy format (your app's format)
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]) ?? 1;
            final month = int.tryParse(parts[1]) ?? 1;
            final year = int.tryParse(parts[2]) ?? 2000;
            date = DateTime(year, month, day);
          }
        } catch (e) {
          debugPrint('Error parsing date $dateStr: $e');
          // Fallback - try standard parsing
          try {
            date = DateTime.parse(dateStr);
          } catch (e) {
            debugPrint('Failed to parse date in any format: $dateStr');
            return false; // Exclude this expense from results if date can't be parsed
          }
        }
        
        // If we couldn't parse the date, exclude this expense
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
        // Search in date, cashier, account type
        if (expense['date'].toString().toLowerCase().contains(query) ||
            expense['cashier'].toString().toLowerCase().contains(query) ||
            expense['accountType'].toString().toLowerCase().contains(query)) {
          return true;
        }
        
        // Search in items
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

  @override
  Widget build(BuildContext context) {
    final filteredExpenses = _getFilteredExpenses();
    
    // Calculate totals for the summary card based on filtered expenses
    final int totalExpenseCount = filteredExpenses.length;
    final double totalAmount = filteredExpenses.fold<double>(
      0,
      (sum, expense) => sum + (expense['grandTotal'] as double),
    );
    
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Expenses',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        // centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.refresh),
          //   onPressed: _loadExpenses,
          //   tooltip: 'Refresh',
          // ),
        ],
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
                  // Filter indicator
                  // Container(
                  //   margin: const EdgeInsets.only(bottom: 10),
                  //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  //   decoration: BoxDecoration(
                  //     color: Colors.blue.shade50,
                  //     borderRadius: BorderRadius.circular(20),
                  //     border: Border.all(color: Colors.blue.shade200),
                  //   ),
                  //   child: Row(
                  //     mainAxisSize: MainAxisSize.min,
                  //     children: [
                  //       Icon(
                  //         _getFilterIcon(_selectedFilter),
                  //         size: 16,
                  //         color: Colors.blue.shade700,
                  //       ),
                  //       const SizedBox(width: 6),
                  //       Text(
                  //         _selectedFilter,
                  //         style: TextStyle(
                  //           color: Colors.blue.shade700,
                  //           fontSize: 13,
                  //           fontWeight: FontWeight.bold,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  
                  // Summary cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 55), // Left/Right spacing
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Expenses',
                            totalExpenseCount.toString(),
                            Icons.receipt_long,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Amount',
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
                    hintText: 'Search expenses...',
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
                        label: Text(filter),
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
                          'Loading expenses...',
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
                              'No expenses found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty || _selectedFilter != 'All Expenses'
                                  ? 'Try changing your search or filter'
                                  : 'Tap the + button to add a new expense',
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
                          // final total = expense['grandTotal'] as double;
                          final items = expense['items'] as List<dynamic>;
                          
                          // Format date better if needed
                          String formattedDate = date;
                          try {
                            // First try with dd-MM-yyyy format (your app's format)
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
                              // Fallback - try standard parsing
                              final dateObj = DateTime.parse(date);
                              formattedDate = _dateFormat.format(dateObj);
                            }
                          } catch (e) {
                            // Keep original format if parsing fails
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
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete, color: Colors.white),
                                  SizedBox(height: 4),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                                                      accountType,
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
                                                      '${items.length} item${items.length != 1 ? 's' : ''}',
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
                                            label: const Text('Edit'),
                                            style: ElevatedButton.styleFrom(
                                              // backgroundColor: Colors.blue,
                                              // foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          // Delete Button
                                          ElevatedButton.icon(
                                            onPressed: () => _showDeleteConfirmation(expenseId),
                                            icon: const Icon(Icons.delete, size: 16),
                                            label: const Text('Delete'),
                                            style: ElevatedButton.styleFrom(
                                              // backgroundColor: Colors.red,
                                              // foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ),
                                          
                                         
                                        ],
                                      ),
                                      
                                      // Item preview if space allows
                                      // if (items.isNotEmpty) ...[
                                      //   const Divider(height: 24),
                                      //   Row(
                                      //     children: [
                                      //       const Icon(
                                      //         Icons.format_list_bulleted,
                                      //         size: 16,
                                      //         color: Colors.grey,
                                      //       ),
                                      //       const SizedBox(width: 8),
                                      //       const Text(
                                      //         'Recent Items:',
                                      //         style: TextStyle(
                                      //           color: Colors.grey,
                                      //           fontSize: 12,
                                      //         ),
                                      //       ),
                                      //       const Spacer(),
                                      //       TextButton(
                                      //         onPressed: () => _viewExpenseDetails(expense),
                                      //         style: TextButton.styleFrom(
                                      //           visualDensity: VisualDensity.compact,
                                      //           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      //         ),
                                      //         child: const Row(
                                      //           mainAxisSize: MainAxisSize.min,
                                      //           children: [
                                      //             Text(
                                      //               'View All',
                                      //               style: TextStyle(fontSize: 12),
                                      //             ),
                                      //             Icon(Icons.arrow_forward, size: 14),
                                      //           ],
                                      //         ),
                                      //       ),
                                      //     ],
                                      //   ),
                                      //   const SizedBox(height: 8),
                                      //   _buildItemPreview(items),
                                      // ],
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
        label: const Text('Add Expense'),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
    // Helper method to get icon for filter
  // IconData _getFilterIcon(String filter) {
  //   switch (filter) {
  //     case 'Today':
  //       return Icons.today;
  //     case 'This Week':
  //       return Icons.date_range;
  //     case 'This Month':
  //       return Icons.calendar_month;
  //     case 'All Expenses':
  //       return Icons.all_inclusive;
  //     default:
  //       return Icons.filter_list;
  //   }
  // }
  
 
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
  return ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 180), // Adjust as needed
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
