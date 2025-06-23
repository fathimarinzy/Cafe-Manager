import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/local_expense_repository.dart';
import '../screens/expense_history_screen.dart';

class ExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? expenseToEdit;
  const ExpenseScreen({this.expenseToEdit,super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  // Add a controller with a default value for cashier type
  final _cashierController = TextEditingController(text: '1');
  // Add a variable to store the selected cashier type
  String _selectedCashierType = 'Cashier'; // Default value
  // List of available cashier types
  final List<String> _cashierTypes = ['Cashier', 'Salesman'];
  
  bool _isLoading = false;
  List<ExpenseItem> _expenseItems = [];
  
  // Date related variables
  DateTime _selectedDate = DateTime.now();
  String _currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
  
  double _grandTotal = 0.0;
  
  // Keep the existing account type selection
  String _selectedAccountType = 'Cash Account';
  final List<String> _accountTypes = ['Cash Account', 'Bank Account'];

  // Initialize local repository
  final LocalExpenseRepository _expenseRepository = LocalExpenseRepository();
  
  final List<String> _expenseCategories = [
    'Shop Expense',
    'Office Expense',
    'Food Expense',
    'Transport',
    'Utilities',
    'Rent',
    'Salaries',
    'Kitchen Expense',
    'Raw Materials',
    'Maintenance',
    'Equipment',
    'Cleaning Supplies',
    'Other'
  ];

  // Track if the search filter is active for each row
  List<bool> _searchActiveStates = [];
  // Search text controllers for each expense item
  final List<TextEditingController> _searchControllers = [];
  // Filtered account options for each expense item
  final List<List<String>> _filteredOptions = [];

  @override
  void initState() {
    super.initState();
    // If we're editing an existing expense, load its data
  if (widget.expenseToEdit != null) {
    _loadExpenseData();
  } else {
    // If it's a new expense, just add an empty row
    _addNewExpenseRow();
  }

  }
  
  @override
  void dispose() {
    _cashierController.dispose();
    
    // Dispose all controllers
    for (var controller in _searchControllers) {
      controller.dispose();
    }
    for (var item in _expenseItems) {
      item.narrationController.dispose();
      item.amountController.dispose();
      item.remarksController.dispose();
    }
    
    super.dispose();
  }
  void _loadExpenseData() {
  final expense = widget.expenseToEdit!;
  
  // Set date
  try {
    final dateStr = expense['date'] as String;
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? 2000;
      _selectedDate = DateTime(year, month, day);
      _currentDate = DateFormat('dd-MM-yyyy').format(_selectedDate);
    }
  } catch (e) {
    debugPrint('Error parsing date: $e');
  }
  
  // Set account type
  final accountType = expense['accountType'] as String;
  if (_accountTypes.contains(accountType)) {
    _selectedAccountType = accountType;
  }
  
  // Set cashier
  final cashierStr = expense['cashier'] as String;
  final cashierParts = cashierStr.split('-');
  if (cashierParts.length == 2) {
    _selectedCashierType = cashierParts[0];
    _cashierController.text = cashierParts[1];
  }
  
  // Load expense items
  final items = expense['items'] as List<dynamic>;
  for (var item in items) {
    final accountController = TextEditingController(text: item['account']);
    final narrationController = TextEditingController(text: item['narration']);
    final amountController = TextEditingController(text: item['amount'].toString());
    final remarksController = TextEditingController(text: item['remarks'] ?? '');
    
    _searchControllers.add(accountController);
    _filteredOptions.add([..._expenseCategories]);
    _searchActiveStates.add(false);
    
    _expenseItems.add(
      ExpenseItem(
        slNo: item['slNo'],
        account: item['account'],
        narration: item['narration'],
        amount: item['amount'],
        remarks: item['remarks'] ?? '',
        narrationController: narrationController,
        amountController: amountController,
        remarksController: remarksController
      )
    );
  }
  
  // Update grand total
  _updateGrandTotal();
}

  // Method to show date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020), // Allow dates from 2020
      lastDate: DateTime.now().add(const Duration(days: 365)), // Allow future dates up to 1 year
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
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _currentDate = DateFormat('dd-MM-yyyy').format(_selectedDate);
      });
    }
  }
  
  void _updateGrandTotal() {
    double total = 0.0;
    for (var item in _expenseItems) {
      total += item.amount;
    }
    setState(() {
      _grandTotal = total;
    });
  }
  
  void _addNewExpenseRow() {
    final accountController = TextEditingController();
    final narrationController = TextEditingController();
    final amountController = TextEditingController();
    final remarksController = TextEditingController();
    
    _searchControllers.add(accountController);
    _filteredOptions.add([..._expenseCategories]);
    _searchActiveStates.add(false);
    
    setState(() {
      _expenseItems.add(
        ExpenseItem(
          slNo: _expenseItems.length + 1,
          account: '',
          narration: '',
          amount: 0.0,
          remarks: '',
          narrationController: narrationController,
          amountController: amountController,
          remarksController: remarksController
        )
      );
    });
  }
  
  void _updateExpenseItem(int index, {
    String? account,
    String? narration,
    double? amount,
    String? remarks,
  }) {
    if (index >= 0 && index < _expenseItems.length) {
      setState(() {
        if (account != null) _expenseItems[index].account = account;
        if (narration != null) _expenseItems[index].narration = narration;
        if (amount != null) _expenseItems[index].amount = amount;
        if (remarks != null) _expenseItems[index].remarks = remarks;
        _updateGrandTotal();
      });
    }
  }
  
  void _removeExpenseItem(int index) {
    if (index >= 0 && index < _expenseItems.length) {
      // Dispose the controllers for this item
      _searchControllers[index].dispose();
      _searchControllers.removeAt(index);
      _filteredOptions.removeAt(index);
      _searchActiveStates.removeAt(index);
      
      _expenseItems[index].narrationController.dispose();
      _expenseItems[index].amountController.dispose();
      _expenseItems[index].remarksController.dispose();
      
      setState(() {
        _expenseItems.removeAt(index);
        // Renumber items
        for (int i = 0; i < _expenseItems.length; i++) {
          _expenseItems[i].slNo = i + 1;
        }
        _updateGrandTotal();
      });
    }
  }
  
  // Filter account options for a specific row
  void _filterOptions(int index, String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredOptions[index] = [..._expenseCategories];
      } else {
        _filteredOptions[index] = _expenseCategories
            .where((account) => account.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }
  
  void _toggleDropdown(int index) {
    setState(() {
      _searchActiveStates[index] = !_searchActiveStates[index];
    });
  }
  
  Future<void> _saveExpense() async {
    // Validate form
    bool hasEmptyFields = false;
    bool hasValidAmount = false;
    
    for (var item in _expenseItems) {
      if (item.account.isEmpty || item.narration.isEmpty) {
        hasEmptyFields = true;
      }
      if (item.amount > 0) {
        hasValidAmount = true;
      }
    }
    
    if (hasEmptyFields) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    
    if (!hasValidAmount || _grandTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one expense with a valid amount')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Create expense data including the selected account type and cashier type
      final expenseData = {
        'date': _currentDate, // Use the selected date
        'cashier': '${_selectedCashierType}-${_cashierController.text}', // Include cashier type
        'accountType': _selectedAccountType, // Include selected account type
        'items': _expenseItems.map((item) => {
          'slNo': item.slNo,
          'account': item.account,
          'narration': item.narration,
          'amount': item.amount,
          'remarks': item.remarks,
        }).toList(),
        'grandTotal': _grandTotal,
      };
      
      bool result;
    if (widget.expenseToEdit != null) {
      // We're updating an existing expense
      expenseData['id'] = widget.expenseToEdit!['id'];
      result = await _expenseRepository.updateExpense(expenseData);
    } else {
      // We're creating a new expense
      result = await _expenseRepository.saveExpense(expenseData);
    }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (result) {
          // Show success message with a more visible dialog instead of just a SnackBar
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Success'),
              content: Text(widget.expenseToEdit != null 
              ? 'Expense updated successfully!' 
              : 'Expense records stored successfully!'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();

                    if (widget.expenseToEdit != null) {
                      // If we're updating, navigate back to the previous screen
                      Navigator.of(context).pop();
                    } else {
                      // If we're adding a new record, reset the form for a new entry
                      _resetForm();
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save expense. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _resetForm() {
    // Dispose all current controllers
    for (var controller in _searchControllers) {
      controller.dispose();
    }
    
    for (var item in _expenseItems) {
      item.narrationController.dispose();
      item.amountController.dispose();
      item.remarksController.dispose();
    }
    
    _searchControllers.clear();
    _filteredOptions.clear();
    _searchActiveStates.clear();
    
    setState(() {
      _expenseItems.clear();
      // Reset to current date
      _selectedDate = DateTime.now();
      _currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
      _grandTotal = 0.0;
      // Reset selected account type to default
      _selectedAccountType = 'Cash Account';
      // Reset cashier type to default
      _selectedCashierType = 'Cashier';
      // Reset cashier input field but keep existing structure
      _cashierController.text = '1';
    });
    
    _addNewExpenseRow();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Payment'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Row(
                                  children: [
                                    const Icon(Icons.payment, color: Colors.green),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Cash Payment',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // First Row - Cash Account and Date
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cash Account Section
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Cash Account:'),
                                    const SizedBox(height: 4),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value: _selectedAccountType,
                                          items: _accountTypes.map((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            if (newValue != null) {
                                              setState(() {
                                                _selectedAccountType = newValue;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(width: 16),
                              
                              // Date Section
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Date:'),
                                    const SizedBox(height: 4),
                                    InkWell(
                                      onTap: () => _selectDate(context),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today,
                                              size: 20,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _currentDate,
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Second Row - Cashier/Salesman Section
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Role dropdown
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Cashier:'),
                                    const SizedBox(height: 4),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value: _selectedCashierType,
                                          items: _cashierTypes.map((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            if (newValue != null) {
                                              setState(() {
                                                _selectedCashierType = newValue;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(width: 16),
                              
                              // ID text field - commented out but kept for reference
                              // Expanded(
                              //   flex: 1,
                              //   child: Column(
                              //     crossAxisAlignment: CrossAxisAlignment.start,
                              //     children: [
                              //       Text('${_selectedCashierType} ID:'),
                              //       const SizedBox(height: 4),
                              //       TextField(
                              //         controller: _cashierController,
                              //         decoration: const InputDecoration(
                              //           isDense: true,
                              //           contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              //           border: OutlineInputBorder(),
                              //         ),
                              //       ),
                              //     ],
                              //   ),
                              // ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Expense Items Table
                  Card(
                    elevation: 2,
                    child: Column(
                      children: [
                        // Table header
                        Container(
                          color: Colors.blue.shade800,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                _buildHeaderCell('Sl.No', 1),
                                _buildHeaderCell('Account', 3),
                                _buildHeaderCell('Narration', 3),
                                _buildHeaderCell('Remarks', 2),
                                // _buildHeaderCell('OldBalance', 2),
                                _buildHeaderCell('Amount', 2),
                                _buildHeaderCell('NetAmount', 2),
                                _buildHeaderCell('', 1), // Delete button column
                              ],
                            ),
                          ),
                        ),
                        
                        // Table rows
                        for (int i = 0; i < _expenseItems.length; i++)
                          _buildExpenseRow(i),
                        
                        // Add button
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ElevatedButton.icon(
                            onPressed: _addNewExpenseRow,
                            icon: const Icon(Icons.add),
                            label: const Text(''),
                            style: ElevatedButton.styleFrom(
                              // backgroundColor: Colors.blue,
                              // foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        
                        // Totals
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text('Gross:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 100,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    alignment: Alignment.centerRight,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                    ),
                                    child: const Text('0.000'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text('Total Tax:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 100,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    alignment: Alignment.centerRight,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                    ),
                                    child: const Text('0.000'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text('Grand Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 100,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    alignment: Alignment.centerRight,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                    ),
                                    child: Text(
                                      _grandTotal.toStringAsFixed(3),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saveExpense,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () { 
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ExpenseHistoryScreen()),
                          );
                          },
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Expenses'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // ElevatedButton.icon(
                      //   onPressed: () {},
                      //   icon: const Icon(Icons.share),
                      //   label: const Text('Share'),
                      //   style: ElevatedButton.styleFrom(
                      //     backgroundColor: Colors.blue.shade400,
                      //     foregroundColor: Colors.white,
                      //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      //   ),
                      // ),
                      const SizedBox(width: 16),
                      // ElevatedButton.icon(
                      //   onPressed: () {},
                      //   icon: const Icon(Icons.search),
                      //   label: const Text('Search'),
                      //   style: ElevatedButton.styleFrom(
                      //     backgroundColor: Colors.blue.shade400,
                      //     foregroundColor: Colors.white,
                      //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      //   ),
                      // ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }
  
  Widget _buildHeaderCell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  Widget _buildExpenseRow(int index) {
    final item = _expenseItems[index];
    
    return Container(
      color: index % 2 == 0 ? Colors.white : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            // Sl.No
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('${item.slNo}'),
              ),
            ),
            
            // Account with search dropdown
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    // Search field and dropdown toggle
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (mounted && hasFocus) {
                          setState(() {
                            _searchActiveStates[index] = true;
                          });
                        }
                      },
                      child: TextField(
                        controller: _searchControllers[index],
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: const OutlineInputBorder(),
                          // hintText: 'Select Account',
                          suffixIcon: IconButton(
                            icon: Icon(_searchActiveStates[index] 
                              ? Icons.keyboard_arrow_up 
                              : Icons.keyboard_arrow_down),
                            onPressed: () => _toggleDropdown(index),
                          ),
                        ),
                        onChanged: (value) {
                          _filterOptions(index, value);
                          _updateExpenseItem(index, account: value);
                        },
                      ),
                    ),
                    
                    // Dropdown menu
                    if (_searchActiveStates[index])
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredOptions[index].length,
                          itemBuilder: (context, optionIndex) {
                            final option = _filteredOptions[index][optionIndex];
                            return ListTile(
                              dense: true,
                              title: Text(option),
                              onTap: () {
                                _searchControllers[index].text = option;
                                _updateExpenseItem(index, account: option);
                                setState(() {
                                  _searchActiveStates[index] = false;
                                });
                              },
                              tileColor: option == item.account 
                                ? Colors.blue.shade100 
                                : null,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Narration
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: item.narrationController,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                    // hintText: 'Enter Narration',
                  ),
                  onChanged: (value) {
                    _updateExpenseItem(index, narration: value);
                  },
                ),
              ),
            ),
            
            // Remarks
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: item.remarksController,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                    // hintText: 'Remarks',
                  ),
                  onChanged: (value) {
                    _updateExpenseItem(index, remarks: value);
                  },
                ),
              ),
            ),
            
            // OldBalance
            // Expanded(
            //   flex: 2,
            //   child: Padding(
            //     padding: const EdgeInsets.symmetric(horizontal: 8.0),
            //     child: TextField(
            //       readOnly: true,
            //       controller: TextEditingController(text: '0.000'),
            //       decoration: const InputDecoration(
            //         isDense: true,
            //         contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            //         border: OutlineInputBorder(),
            //       ),
            //     ),
            //   ),
            // ),
            
            // Amount - Using dedicated controller
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: item.amountController,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                    // hintText: 'Amount',
                    
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    double? amount = double.tryParse(value);
                    _updateExpenseItem(
                      index,
                      amount: amount ?? 0.0,
                    );
                  },
                ),
              ),
              
            ),
            
            // NetAmount
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Container(
                  color: Colors.blue.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  alignment: Alignment.centerRight,
                  child: Text(
                    item.amount.toStringAsFixed(3),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            
            // Delete button column
            Expanded(
              flex: 1,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeExpenseItem(index),
                tooltip: 'Delete row',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpenseItem {
  int slNo;
  String account;
  String narration;
  double amount;
  String remarks;
  TextEditingController narrationController; 
  TextEditingController amountController;
  TextEditingController remarksController;
  
  ExpenseItem({
    required this.slNo,
    required this.account,
    required this.narration,
    required this.amount,
    required this.remarks,
    required this.narrationController,
    required this.amountController,
    required this.remarksController,
  });
}