import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/table_provider.dart';
import '../providers/settings_provider.dart';
// import '../services/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'modifier_screen.dart'; 
import 'table_management_screen.dart'; 
import 'printer_settings_screen.dart'; 
import '../utils/app_localization.dart';
import '../screens/expense_screen.dart';
import '../screens/report_screen.dart';
// import '../repositories/local_menu_repository.dart';
// import '../repositories/local_order_repository.dart';
// import '../repositories/local_person_repository.dart';
// import '../repositories/local_expense_repository.dart';
import '../widgets/backup_manager_widget.dart';
import '../utils/database_reset_service.dart';

class SettingsScreen extends StatefulWidget {
  final String userType;
  const SettingsScreen({super.key, this.userType = 'staff'});
   
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showAdvancedSettings = false;
  bool get _isOwner => widget.userType == 'owner';
  
  // Business Information
  final _businessNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Printer Settings
  bool _autoPrintReceipts = true;
  bool _autoPrintKitchenOrders = true;
  String _selectedPrinter = 'Default Printer';
  
  // Tax Settings
  final _taxRateController = TextEditingController(text: '0.0');
  
  // Table Layout
  int _tableRows = 4;
  int _tableColumns = 4;
  
  // Receipt Footer
  final _receiptFooterController = TextEditingController();
  
  // App Appearance
  String _selectedTheme = 'Light';
  String _selectedLanguage = 'English';
  
  // Advanced Settings
  final _serverUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  @override
  void dispose() {
    _businessNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _taxRateController.dispose();
    _receiptFooterController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // Wait for settings to load if they haven't been initialized
      if (!settingsProvider.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Check if widget is still mounted before updating state
      if (!mounted) return;
      
      // Load business info (now at the top)
      _businessNameController.text = settingsProvider.businessName;
      _addressController.text = settingsProvider.businessAddress;
      _phoneController.text = settingsProvider.businessPhone;
      
      // Load printer settings
      _autoPrintReceipts = settingsProvider.autoPrintReceipts;
      _autoPrintKitchenOrders = settingsProvider.autoPrintKitchenOrders;
      _selectedPrinter = settingsProvider.selectedPrinter;
      
      // Load tax settings
      _taxRateController.text = settingsProvider.taxRate.toString();
      
      // Load table layout
      _tableRows = settingsProvider.tableRows;
      _tableColumns = settingsProvider.tableColumns;
      
      // Load receipt footer
      _receiptFooterController.text = settingsProvider.receiptFooter;
      
      // Load appearance settings
      _selectedTheme = settingsProvider.appTheme;
      _selectedLanguage = settingsProvider.appLanguage;
      
      // Load advanced settings (server URL)
      _serverUrlController.text = settingsProvider.serverUrl;
    } catch (e) {
      debugPrint('Error loading settings: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (!_formKey.currentState!.validate()) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // Parse tax rate
      double taxRate = 5.0;
      try {
        taxRate = double.parse(_taxRateController.text);
      } catch (e) {
        debugPrint('Error parsing tax rate: $e');
      }
        // Business info settings - only owner can change
      if (_isOwner) {
        await settingsProvider.saveAllSettings(
          // Business info
          businessName: _businessNameController.text,
          businessAddress: _addressController.text,
          businessPhone: _phoneController.text,
          
          // Tax settings
          taxRate: taxRate,
          
          // Table layout
          tableRows: _tableRows,
          tableColumns: _tableColumns,
          
          // Server URL
          serverUrl: _showAdvancedSettings ? _serverUrlController.text : null,
        );
      }
      
      // Save all settings at once
      await settingsProvider.saveAllSettings(
     
        // Printer settings
        autoPrintReceipts: _autoPrintReceipts,
        autoPrintKitchenOrders: _autoPrintKitchenOrders,
        selectedPrinter: _selectedPrinter,
        
        // Tax settings
        taxRate: taxRate,
        
        // Table layout
        tableRows: _tableRows,
        tableColumns: _tableColumns,
        
        // Receipt footer
        receiptFooter: _receiptFooterController.text,
        
        // Appearance
        appTheme: _selectedTheme,
        appLanguage: _selectedLanguage,
        
        // Advanced (Server URL)
        serverUrl: _serverUrlController.text,
      );
      
      // Check if widget is still mounted before updating UI
      if (!mounted) return;
      
      // Update table provider with new layout
      final tableProvider = Provider.of<TableProvider>(context, listen: false);
      await tableProvider.refreshTables();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Future<void> _backupData() async {
  //   try {
  //     setState(() {
  //       _isLoading = true;
  //     });
      
  //     // Save current settings first to ensure they're included in the backup
  //     await _saveSettings();
      
  //     // Create the backup
  //     final backupPath = await BackupService.backupData();
      
  //     // Check if widget is still mounted before updating UI
  //     if (!mounted) return;
      
  //     setState(() {
  //       _isLoading = false;
  //     });
      
  //     if (backupPath != null) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: const Text('Backup created successfully'),
  //           action: SnackBarAction(
  //             label: 'Share',
  //             onPressed: () {
  //               BackupService.shareBackup(backupPath);
  //             },
  //           ),
  //         ),
  //       );
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Failed to create backup')),
  //       );
  //     }
  //   } catch (e) {
  //     debugPrint('Error creating backup: $e');
      
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //       });
        
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Error creating backup: $e')),
  //       );
  //     }
  //   }
  // }
  
  // Future<void> _restoreData() async {
  //   try {
  //     // Get list of available backups
  //     final backups = await BackupService.getAvailableBackups();
      
  //     // Check if widget is still mounted before continuing
  //     if (!mounted) return;
      
  //     if (backups.isEmpty) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('No backups found')),
  //       );
  //       return;
  //     }
      
  //     // Show dialog to select backup
  //     final selectedBackup = await showDialog<Map<String, dynamic>>(
  //       context: context,
  //       builder: (ctx) => AlertDialog(
  //         title: const Text('Select Backup to Restore'),
  //         content: SizedBox(
  //           width: double.maxFinite,
  //           height: 300,
  //           child: ListView.builder(
  //             itemCount: backups.length,
  //             itemBuilder: (context, index) {
  //               final backup = backups[index];
  //               final DateTime timestamp = DateTime.parse(backup['timestamp']);
  //               final String date = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
  //               final String time = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
                
  //               return ListTile(
  //                 title: Text('Backup from $date'),
  //                 subtitle: Text('Created at $time'),
  //                 onTap: () => Navigator.of(ctx).pop(backup),
  //               );
  //             },
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.of(ctx).pop(),
  //             child: const Text('Cancel'),
  //           ),
  //         ],
  //       ),
  //     );
      
  //     // Check if widget is still mounted before continuing
  //     if (!mounted) return;
      
  //     if (selectedBackup == null) return;
      
  //     // For the second dialog, also check if mounted
  //     final confirmed = await showDialog<bool>(
  //       context: context,
  //       builder: (ctx) => AlertDialog(
  //         title: const Text('Confirm Restore'),
  //         content: const Text(
  //           'Restoring from backup will overwrite all current settings.\n'
  //           'This action cannot be undone. Are you sure you want to continue?'
  //         ),
  //         actions: [
  //           TextButton(
  //             child: const Text('Cancel'),
  //             onPressed: () => Navigator.of(ctx).pop(false),
  //           ),
  //           TextButton(
  //             child: const Text('Restore', style: TextStyle(color: Colors.blue)),
  //             onPressed: () => Navigator.of(ctx).pop(true),
  //           ),
  //         ],
  //       ),
  //     ) ?? false;
      
  //     // Check if widget is still mounted before continuing
  //     if (!mounted) return;
      
  //     if (!confirmed) return;
      
  //     // Restore the backup
  //     setState(() {
  //       _isLoading = true;
  //     });
      
  //     final success = await BackupService.restoreData(selectedBackup['path']);
      
  //     // Final mounted check before updating UI
  //     if (!mounted) return;
      
  //     setState(() {
  //       _isLoading = false;
  //     });
      
  //     if (success) {
  //       // Reload settings - breaking this up into separate operations with mounted checks
  //       await _loadSettings();
        
  //       // Check mounted state again before showing message
  //       if (!mounted) return;
        
  //       // Show success message
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Backup restored successfully')),
  //       );
        
  //       // Refresh table provider - check mounted again
  //       if (!mounted) return;
  //       final tableProvider = Provider.of<TableProvider>(context, listen: false);
  //       tableProvider.refreshTables();
  //     } else {
  //       // Only access context if still mounted
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Failed to restore backup')),
  //       );
  //     }
  //   } catch (e) {
  //     debugPrint('Error restoring backup: $e');
      
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //       });
        
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Error restoring backup: $e')),
  //       );
  //     }
  //   }
  // }

  // Show reset confirmation dialog
  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text(
          'This will delete all app data.\n'
          'This action cannot be undone. Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showPasswordDialog();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  // Show password verification dialog
  void _showPasswordDialog() {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isPasswordIncorrect = false;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Password : '),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the password';
              }
              if (isPasswordIncorrect) {
                  return 'Incorrect password';
              }
              return null;
            },
             onChanged: (value) {
                // Reset the incorrect flag when user types
                if (isPasswordIncorrect) {
                  setState(() {
                    isPasswordIncorrect = false;
                  });
                  // This will rebuild the form without the error
                  formKey.currentState?.validate();
                }
              },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
                // Verify password - you should replace with your own password verification
                // For this example, I'm using a hard-coded password 'staff123'
                if (passwordController.text == '1234') {
                  Navigator.of(ctx).pop();
                  _resetAllData();
                } else {
                  // Set the flag and trigger validation to show error
                  setState(() {
                    isPasswordIncorrect = true;
                  });
                  formKey.currentState?.validate();
                }
              },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  // Reset all data
  Future<void> _resetAllData() async {
  if (!mounted) return;
  
  setState(() {
    _isLoading = true;
  });

  try {
    // Show a progress dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WillPopScope(
          // Prevent dialog from being dismissed with back button
          onWillPop: () async => false,
          child: const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Resetting data... Please wait.'),
                SizedBox(height: 8),
                Text(
                  'This may take a moment. Do not close the app.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Get instance of our new database reset service
    final dbResetService = DatabaseResetService();
    
    // Use the force reset method that handles readonly database issues
    await dbResetService.forceResetAllDatabases();
    
    // Reset settings to defaults
    if (!mounted) return;
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    await settingsProvider.resetSettings();
    
    // Reset table layouts
    if (!mounted) return;
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    await tableProvider.refreshTables();
    
    // Pop the progress dialog
    if (mounted) Navigator.of(context).pop();
    
    // Show success message with restart instruction
    if (mounted) {
      // Show a dialog instructing the user to restart the app
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Reset Complete'),
          content: const Text(
            'All data has been reset successfully.\n'
            'You must restart the app for changes to take effect completely.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Reload settings
                _loadSettings();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    // Pop the progress dialog in case of error
    if (mounted) Navigator.of(context).pop();
    
    debugPrint('Error resetting data: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resetting data: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

//   // Methods to clear each database
// Future<void> _clearMenuDatabase() async {
//   try {
//     // Use repository pattern to get a fresh database connection
//     final menuRepo = LocalMenuRepository();
//     final db = await menuRepo.database;
    
//     // Delete all records
//     await db.delete('menu_items');
    
//     // Try to reset the sequence counter
//     try {
//       await db.execute('DELETE FROM SQLITE_SEQUENCE WHERE name = "menu_items"');
//     } catch (e) {
//       // Ignore if not supported
//       debugPrint('Could not reset sequence for menu_items: $e');
//     }
    
//     debugPrint('Menu database cleared successfully');
//   } catch (e) {
//     debugPrint('Error clearing menu database: $e');
//     // Don't rethrow - continue with other operations
//   }
// }

// Future<void> _clearOrderDatabase() async {
//   try {
//     // Use repository pattern to get a fresh database connection
//     final orderRepo = LocalOrderRepository();
//     final db = await orderRepo.database;
    
//     // Delete in the correct order to maintain foreign key integrity
//     await db.delete('order_items');
//     await db.delete('orders');
    
//     // Try to reset the sequence counters
//     try {
//       await db.execute('DELETE FROM SQLITE_SEQUENCE WHERE name = "orders"');
//       await db.execute('DELETE FROM SQLITE_SEQUENCE WHERE name = "order_items"');
//     } catch (e) {
//       debugPrint('Could not reset sequences for orders: $e');
//     }
    
//     debugPrint('Order database cleared successfully');
//   } catch (e) {
//     debugPrint('Error clearing order database: $e');
//   }
// }

// Future<void> _clearPersonDatabase() async {
//   try {
//     // Use repository pattern to get a fresh database connection
//     final personRepo = LocalPersonRepository();
//     final db = await personRepo.database;
    
//     // Delete all records
//     await db.delete('persons');
    
//     // Try to reset the sequence counter
//     try {
//       await db.execute('DELETE FROM SQLITE_SEQUENCE WHERE name = "persons"');
//     } catch (e) {
//       debugPrint('Could not reset sequence for persons: $e');
//     }
    
//     debugPrint('Person database cleared successfully');
//   } catch (e) {
//     debugPrint('Error clearing person database: $e');
//   }
// }

// Future<void> _clearExpenseDatabase() async {
//   try {
//     // Use repository pattern to get a fresh database connection
//     final expenseRepo = LocalExpenseRepository();
//     final db = await expenseRepo.database;
    
//     // Delete in the correct order to maintain foreign key integrity
//     await db.delete('expense_items');
//     await db.delete('expenses');
    
//     // Try to reset the sequence counters
//     try {
//       await db.execute('DELETE FROM SQLITE_SEQUENCE WHERE name = "expenses"');
//       await db.execute('DELETE FROM SQLITE_SEQUENCE WHERE name = "expense_items"');
//     } catch (e) {
//       debugPrint('Could not reset sequences for expenses: $e');
//     }
    
//     debugPrint('Expense database cleared successfully');
//   } catch (e) {
//     debugPrint('Error clearing expense database: $e');
//   }
// }

  // Add the Tables section widget with dining table layout option
  Widget _buildTablesSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.table_bar, color: Colors.blue[700]),
            title: const Text('Table Management'),
            subtitle: const Text('Configure dining tables and layout'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TableManagementScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 70),
          ListTile(
            leading: Icon(Icons.grid_view, color: Colors.blue[700]),
            title: const Text('Dining Table Layout'),
            subtitle: const Text('Configure table rows and columns'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showLayoutDialog,
          ),
        ],
      ),
    );
  }
  
  // Show layout selection dialog (copied from DiningTableScreen)
  void _showLayoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Get screen width to calculate dialog width
        final screenWidth = MediaQuery.of(context).size.width;
        
        return AlertDialog(
          title: const Text(
            'Select Table Layout',
            style: TextStyle(
              fontSize: 18, // Smaller title font
              fontWeight: FontWeight.bold,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          // Make dialog narrower - only 65% of screen width
          content: SizedBox(
            width: screenWidth * 0.65,
            child: ListView(
              shrinkWrap: true,
              children: _layoutOptions.map((option) {
                return ListTile(
                  dense: true, // Makes the list tile more compact
                  title: Text(
                    option['label'],
                    style: const TextStyle(
                      fontSize: 14, // Smaller font for options
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _tableRows = option['rows'];
                      _tableColumns = option['columns'];
                    });
                    // Save the selected layout to persist it
                    _saveLayout(option['rows'], option['columns']);
                    Navigator.pop(context);
                  },
                  trailing: (_tableRows == option['rows'] && _tableColumns == option['columns']) 
                    ? const Icon(Icons.check, color: Colors.green, size: 18) // Smaller checkmark
                    : null,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 14), // Smaller font for button
              ),
            ),
          ],
        );
      },
    );
  }
  
  // Save layout configuration to SharedPreferences
  Future<void> _saveLayout(int rows, int columns) async {
    try {
      // First update the SettingsProvider
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.saveAllSettings(
        tableRows: rows,
        tableColumns: columns,
      );
      
      // Also directly update the shared preferences with the exact same keys used in DiningTableScreen
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dining_table_rows', rows);
      await prefs.setInt('dining_table_columns', columns);
      
      // Show a confirmation message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Table layout saved')),
        );
      }
    } catch (e) {
      debugPrint('Error saving layout settings: $e');
    }
  }
  
  // Predefined layout options (same as DiningTableScreen)
  final List<Map<String, dynamic>> _layoutOptions = [
    {'label': '3x4 Layout', 'rows': 3, 'columns': 4},
    {'label': '4x4 Layout', 'rows': 4, 'columns': 4},
    {'label': '4x5 Layout', 'rows': 4, 'columns': 5},
    {'label': '4x6 Layout', 'rows': 4, 'columns': 6},
    {'label': '4x8 Layout', 'rows': 4, 'columns': 8},
    {'label': '5x6 Layout', 'rows': 5, 'columns': 6},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings ${_isOwner ? "(Owner)" : ""}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            onPressed: _saveSettings,
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue[700],
            ),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // BUSINESS INFORMATION - Most important, at the top
                _buildSectionHeader('Business Information'),
                _buildBusinessInfoSection(),

                const Divider(),
                _buildSectionHeader('Expense'),
                _expenseSection(),
                const Divider(),
                _buildSectionHeader('Reports'),
                _buildReportsSection(),
                const Divider(),
                // TAX SETTINGS - Important for sales
                _buildSectionHeader('Tax Settings'),
                _buildTaxSettingsSection(),
                 
                const Divider(),
                
                // PRINTER SETTINGS SECTION
                _buildSectionHeader('Printer Settings'),
                _buildPrinterSettingsSection(),
                const Divider(),
              
                // PRODUCT MANAGEMENT - Add the new section
                _buildSectionHeader('Products'),
                _buildProductSection(),
                const Divider(),
                
                // TABLE MANAGEMENT - Add the new section
                _buildSectionHeader('Tables'),
                _buildTablesSection(),
                const Divider(),
                
                // DATA MANAGEMENT
                _buildSectionHeader('Data & Backup'),
                _buildDataBackupSection(),
                const SizedBox(height: 16),
                const Divider(),
                // APP APPEARANCE
                _buildSectionHeader('Appearance'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text('language'.tr()),
                        subtitle: Text(_selectedLanguage),
                        trailing: DropdownButton<String>(
                          value: _selectedLanguage,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedLanguage = newValue;
                              });
                              
                              // Apply the language change
                              final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                              settingsProvider.setLanguage(newValue);
                                
                              // Show a confirmation message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('languageChanged'.tr()),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          items: <String>['English', 'Arabic']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          underline: Container(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                
                // ADVANCED SETTINGS TOGGLE
                InkWell(
                  onTap: () {
                    setState(() {
                      _showAdvancedSettings = !_showAdvancedSettings;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Show/hide advanced settings controls if needed
                      ],
                    ),
                  ),
                ),
                
                // logout section
                _buildSectionHeader('Logout'),
                _logoutsection(),
             
                // ABOUT
                const Divider(),
                ListTile(
                    title: Text(_businessNameController.text.isNotEmpty ? _businessNameController.text : 'SIMS RESTO CAFE'),
                  subtitle: const Text('Version 1.0.1'),
                  leading: const Icon(Icons.info_outline),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  // Build the Data & Backup section with the new Reset option
  Widget _buildDataBackupSection() {
    return Card(
      child: Column(
        children: [
          // ListTile(
          //   leading: Icon(Icons.backup, color: Colors.blue[700]),
          //   title: const Text('Backup App Data'),
          //   subtitle: const Text('Save all settings and configuration'),
          //   onTap: _backupData,
          // ),
          ListTile(
            leading: Icon(Icons.backup, color: Colors.blue[700]),
            title: const Text('Backup & Restore'),
            subtitle: const Text('Create, restore, and manage backups'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BackupManagerWidget(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 70),
          // ListTile(
          //   leading: Icon(Icons.restore, color: Colors.green[700]),
          //   title: const Text('Restore From Backup'),
          //   subtitle: const Text('Load settings from a previous backup'),
          //   onTap: _restoreData,
          // ),
          const Divider(height: 1, indent: 70),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red[700]),
            title: const Text('Reset Data'),
            subtitle: const Text('Clear all app data '),
            onTap: _showResetConfirmationDialog,
          ),
        ],
      ),
    );
  }
  
  // Add this method to build the Tax Settings section as a ListTile
  Widget _buildTaxSettingsSection() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.attach_money, color: Colors.blue[700]),
        title: const Text('Tax Settings'),
        subtitle: Text('Current Tax Rate: ${_taxRateController.text}%'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _showTaxSettingsDialog,
      ),
    );
  }

  // Add this method to show the tax settings dialog
  void _showTaxSettingsDialog() {
    // Create temporary controller with current value
    final taxRateController = TextEditingController(text: _taxRateController.text);
    
    // Form key for validation
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tax Settings'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Tax Rate: ${_taxRateController.text}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                TextFormField(
                  controller: taxRateController,
                  decoration: const InputDecoration(
                    labelText: 'Sales Tax Rate (%)',
                    border: OutlineInputBorder(),
                    suffixText: '%',
                    hintText: 'Enter your tax rate (e.g., 5.0)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter tax rate';
                    }
                    try {
                      final rate = double.parse(value);
                      if (rate < 0 || rate > 100) {
                        return 'Tax rate must be between 0 and 100';
                      }
                    } catch (e) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Validate the form
                if (formKey.currentState!.validate()) {
                  // Update the main controller with the dialog value
                  setState(() {
                    _taxRateController.text = taxRateController.text;
                  });
                  
                  // Close the dialog
                  Navigator.pop(context);
                  
                  // Show a snackbar to confirm changes
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tax rate updated (not saved yet)')),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildReportsSection() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.analytics, color: Colors.blue[700]),
        title: const Text('Reports'),
        subtitle: const Text('View daily and monthly sales reports'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ReportScreen(),
            ),
          );
        },
      ),
    );
  }
  
  // This will create the Business Information section as a ListTile
  Widget _buildBusinessInfoSection() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.business, color: _isOwner ? Colors.blue[700] : Colors.grey),
        title: const Text('Business Information'),
        subtitle: Text(_isOwner 
            ? (_businessNameController.text.isNotEmpty 
                ? _businessNameController.text 
                : 'Configure restaurant details')
            : 'Configure restaurant details'),
        trailing: _isOwner ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
        onTap: _isOwner ? _showBusinessInfoDialog : null,
        enabled: _isOwner,
        tileColor: _isOwner ? null : Colors.grey.shade100,
      ),
    );
  }
  
  Widget _expenseSection() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.money_off, color: Colors.blue[700]),
        title: const Text('Expense Management'),
        subtitle: const Text('Track and manage your expenses'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ExpenseScreen(),
            ),
          );
        },
      ),
    );
  }
  
  // Add this method to show the dialog with the text form fields
  void _showBusinessInfoDialog() {
    // Create temporary controllers with current values
    final businessNameController = TextEditingController(text: _businessNameController.text);
    final addressController = TextEditingController(text: _addressController.text);
    final phoneController = TextEditingController(text: _phoneController.text);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Business Information'),
          content: SingleChildScrollView(
            child: Form(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: businessNameController,
                    decoration: const InputDecoration(
                      labelText: 'Restaurant Name',
                      border: OutlineInputBorder(),
                      hintText: 'Enter your restaurant name',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter restaurant name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                      hintText: 'Enter your restaurant address',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                      hintText: 'Enter your restaurant phone number',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Update the main controllers with the dialog values
                setState(() {
                  _businessNameController.text = businessNameController.text;
                  _addressController.text = addressController.text;
                  _phoneController.text = phoneController.text;
                });
                
                // Close the dialog
                Navigator.pop(context);
                
                // Show a snackbar to confirm changes
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Business information updated (not saved yet)')),
                );
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }
  
  // Show logout confirmation dialog
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        // Add this to constrain and control the dialog size
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        // Control the dialog size with insets
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.15, // 70% width
          vertical: MediaQuery.of(context).size.height * 0.3   // 40% height
        ),
        child: Container(
          // Explicit dimensions for the dialog content
          width: 400,
          padding: const EdgeInsets.all(24), // Increased padding for more space
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Logout'.tr(), 
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontSize: 22, // Increased font size
                  fontWeight: FontWeight.bold,
                )
              ),
              const SizedBox(height: 20), // More space
              Text(
                'Are you sure you want to logout?'.tr(),
                style: const TextStyle(
                  fontSize: 16, // Increased font size
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32), // More space
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Space buttons evenly
                children: [
                  SizedBox(
                    width: 120, // Fixed width for buttons
                    height: 48, // Taller buttons
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                        textStyle: const TextStyle(fontSize: 16), // Larger text
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Text('Cancel'.tr()),
                    ),
                  ),
                  SizedBox(
                    width: 120, // Fixed width for buttons
                    height: 48, // Taller buttons
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        // Get the auth provider and log out
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        authProvider.logout();
                        // Navigate to login screen
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.shade50, // Background color
                        foregroundColor: Colors.red,
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Larger text
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                      ),
                      child: Text('Logout'.tr()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add the Product section widget
  Widget _buildProductSection() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.inventory, color: Colors.blue[700]),
        title: const Text('Product Management'),
        subtitle: const Text('Add, edit, or remove menu items'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ModifierScreen(),
            ),
          );
        },
      ),
    );
  }
  
  Widget _logoutsection() {  
    return Card(
      child: ListTile(
        leading: Icon(Icons.inventory, color: Colors.blue[700]),
        title: const Text('Logout'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          _showLogoutDialog();
        },
      ),
    );
  }
  
  // Add the Printer Settings section widget
  Widget _buildPrinterSettingsSection() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.print, color: Colors.blue[700]),
        title: const Text('Printer Configuration'),
        subtitle: const Text('Configure thermal printer settings'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PrinterSettingsScreen(),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue[900],
        ),
      ),
    );
  }
}