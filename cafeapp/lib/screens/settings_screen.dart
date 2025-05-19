import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import '../providers/auth_provider.dart';
import '../providers/table_provider.dart';
import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'login_screen.dart';
// import '../services/settings_password_service.dart';
import 'modifier_screen.dart'; // Import the ModifierScreen
import 'table_management_screen.dart'; // Import the TableManagementScreen
import 'printer_settings_screen.dart'; // Import the PrinterSettingsScreen
import '../utils/app_localization.dart';

class SettingsScreen extends StatefulWidget {
  final String userType;
  const SettingsScreen({super.key,this.userType = 'staff'});
   
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
  final _taxRateController = TextEditingController(text: '5.0');
  
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
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
  
  Future<void> _backupData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Save current settings first to ensure they're included in the backup
      await _saveSettings();
      
      // Create the backup
      final backupPath = await BackupService.backupData();
      
      // Check if widget is still mounted before updating UI
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      if (backupPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Backup created successfully'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () {
                BackupService.shareBackup(backupPath);
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create backup')),
        );
      }
    } catch (e) {
      debugPrint('Error creating backup: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating backup: $e')),
        );
      }
    }
  }
  
  Future<void> _restoreData() async {
    try {
      // Get list of available backups
      final backups = await BackupService.getAvailableBackups();
      
      // Check if widget is still mounted before continuing
      if (!mounted) return;
      
      if (backups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No backups found')),
        );
        return;
      }
      
      // Show dialog to select backup
      final selectedBackup = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select Backup to Restore'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final backup = backups[index];
                final DateTime timestamp = DateTime.parse(backup['timestamp']);
                final String date = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
                final String time = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
                
                return ListTile(
                  title: Text('Backup from $date'),
                  subtitle: Text('Created at $time'),
                  onTap: () => Navigator.of(ctx).pop(backup),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      
      // Check if widget is still mounted before continuing
      if (!mounted) return;
      
      if (selectedBackup == null) return;
      
      // For the second dialog, also check if mounted
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Restore'),
          content: const Text(
            'Restoring from backup will overwrite all current settings. '
            'This action cannot be undone. Are you sure you want to continue?'
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            TextButton(
              child: const Text('Restore', style: TextStyle(color: Colors.blue)),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ) ?? false;
      
      // Check if widget is still mounted before continuing
      if (!mounted) return;
      
      if (!confirmed) return;
      
      // Restore the backup
      setState(() {
        _isLoading = true;
      });
      
      final success = await BackupService.restoreData(selectedBackup['path']);
      
      // Final mounted check before updating UI
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      if (success) {
        // Reload settings - breaking this up into separate operations with mounted checks
        await _loadSettings();
        
        // Check mounted state again before showing message
        if (!mounted) return;
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully')),
        );
        
        // Refresh table provider - check mounted again
        if (!mounted) return;
        final tableProvider = Provider.of<TableProvider>(context, listen: false);
        tableProvider.refreshTables();
      } else {
        // Only access context if still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to restore backup')),
        );
      }
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring backup: $e')),
        );
      }
    }
  }

  void _showPrinterSelectionDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Select Default Printer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('Default Printer'),
                  onTap: () {
                    setState(() {
                      _selectedPrinter = 'Default Printer';
                    });
                    Navigator.pop(dialogContext);
                  },
                ),
                ListTile(
                  title: const Text('Kitchen Printer'),
                  onTap: () {
                    setState(() {
                      _selectedPrinter = 'Kitchen Printer';
                    });
                    Navigator.pop(dialogContext);
                  },
                ),
                ListTile(
                  title: const Text('Office Printer'),
                  onTap: () {
                    setState(() {
                      _selectedPrinter = 'Office Printer';
                    });
                    Navigator.pop(dialogContext);
                  },
                ),
                const Divider(),
                TextButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Search for Printers'),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Searching for printers...')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        );
      },
    );
  }
  
  // void _showClearDataDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext dialogContext) {
  //       return AlertDialog(
  //         title: const Text('Clear All Data'),
  //         content: const Text(
  //           'This will delete all app data including orders, settings, and login information.\n\n'
  //           'This action cannot be undone. Are you sure you want to continue?'
  //         ),
  //         actions: [
  //           TextButton(
  //             child: const Text('Cancel'),
  //             onPressed: () => Navigator.pop(dialogContext),
  //           ),
  //           TextButton(
  //             child: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
  //             onPressed: () {
  //               Navigator.pop(dialogContext);
  //               _clearAllData();
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
  
  // Future<void> _clearAllData() async {
  //   try {
  //     setState(() {
  //       _isLoading = true;
  //     });
      
  //     // Reset settings provider
  //     final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
  //     await settingsProvider.resetSettings();
      
  //     // Clear secure storage
  //     const storage = FlutterSecureStorage();
  //     await storage.deleteAll();
      
  //     // Check if widget is still mounted before accessing context
  //     if (!mounted) return;
      
  //     // Log out the user
  //     Provider.of<AuthProvider>(context, listen: false).logout();
      
  //     // Navigate to login screen
  //     Navigator.of(context).pushAndRemoveUntil(
  //       MaterialPageRoute(builder: (context) => const LoginScreen()),
  //       (route) => false,
  //     );
  //   } catch (e) {
  //     debugPrint('Error clearing data: $e');
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Error clearing data: $e')),
  //       );
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
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
                
                // TAX SETTINGS - Important for sales
                _buildSectionHeader('Tax Settings'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Tax Rate: ${_taxRateController.text}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // const Text(
                        //   'This tax rate will be applied to all orders throughout the app',
                        //   style: TextStyle(fontSize: 12, color: Colors.grey),
                        // ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _taxRateController,
                          decoration: const InputDecoration(
                            labelText: 'Sales Tax Rate (%)',
                            border: OutlineInputBorder(),
                            suffixText: '%',
                            hintText: 'Enter your tax rate (e.g., 5.0)',
                            // helperText: 'Sets the tax rate for all calculations in the app',
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
                  const Divider(),
                
                // RECEIPT SETTINGS
                // _buildSectionHeader('Receipt Settings'),
                // Padding(
                //   padding: const EdgeInsets.only(bottom: 16),
                //   child: TextFormField(
                //     controller: _receiptFooterController,
                //     decoration: const InputDecoration(
                //       labelText: 'Receipt Footer Message',
                //       border: OutlineInputBorder(),
                //       hintText: 'Thank you message for receipt',
                //     ),
                //     maxLines: 2,
                //   ),
                // ),
                
                // PRINTER SETTINGS SECTION
                _buildSectionHeader('Printer Settings'),
                _buildPrinterSettingsSection(),
                const Divider(),
                
                // PRINTER SETTINGS SUBSECTION
                _buildSubsectionHeader('Printer Options'),
                SwitchListTile(
                  title: const Text('Auto-print receipts'),
                  subtitle: const Text('Automatically print receipts when orders are completed'),
                  value: _autoPrintReceipts,
                  onChanged: (value) {
                    setState(() {
                      _autoPrintReceipts = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Auto-print kitchen orders'),
                  subtitle: const Text('Automatically send orders to kitchen printer'),
                  value: _autoPrintKitchenOrders,
                  onChanged: (value) {
                    setState(() {
                      _autoPrintKitchenOrders = value;
                    });
                  },
                ),
                Card(
                  child: ListTile(
                    title: const Text('Default Printer'),
                    subtitle: Text(_selectedPrinter),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showPrinterSelectionDialog();
                    },
                  ),
                ),
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
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.backup, color: Colors.blue[700]),
                        title: const Text('Backup App Data'),
                        subtitle: const Text('Save all settings and configuration'),
                        onTap: _backupData,
                      ),
                      const Divider(height: 1, indent: 70),
                      ListTile(
                        leading: Icon(Icons.restore, color: Colors.green[700]),
                        title: const Text('Restore From Backup'),
                        subtitle: const Text('Load settings from a previous backup'),
                        onTap: _restoreData,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // APP APPEARANCE
                _buildSectionHeader('Appearance'),
                Card(
                  child: Column(
                    children: [
                      // ListTile(
                      //   title: const Text('Theme'),
                      //   subtitle: Text(_selectedTheme),
                      //   trailing: DropdownButton<String>(
                      //     value: _selectedTheme,
                      //     onChanged: (String? newValue) {
                      //       if (newValue != null) {
                      //         setState(() {
                      //           _selectedTheme = newValue;
                      //         });
                      //       }
                      //     },
                      //     items: <String>['Light', 'Dark', 'System Default']
                      //         .map<DropdownMenuItem<String>>((String value) {
                      //       return DropdownMenuItem<String>(
                      //         value: value,
                      //         child: Text(value),
                      //       );
                      //     }).toList(),
                      //     underline: Container(),
                      //   ),
                      // ),
                      const Divider(height: 1, indent: 16),
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
                // const Divider(),
                
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
                        // Icon(
                        //   _showAdvancedSettings 
                        //       ? Icons.keyboard_arrow_up 
                        //       : Icons.keyboard_arrow_down,
                        //   color: Colors.grey[600],
                        // ),
                        // const SizedBox(width: 8),
                        // Text(
                        //   _showAdvancedSettings
                        //       ? 'Hide Advanced Settings'
                        //       : 'Show Advanced Settings',
                        //   style: TextStyle(
                        //     color: Colors.grey[700],
                        //     fontWeight: FontWeight.w500,
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ),
                
              //   // ADVANCED SETTINGS (hidden by default)
              //   if (_showAdvancedSettings) ...[
              //     const Divider(),
              //     _buildSectionHeader('Advanced Settings'),
              //     Padding(
              //       padding: const EdgeInsets.only(bottom: 16),
              //       child: TextFormField(
              //         controller: _serverUrlController,
              //         decoration: const InputDecoration(
              //           labelText: 'Server URL',
              //           border: OutlineInputBorder(),
              //           hintText: 'https://example.com/api',
              //         ),
              //         validator: (value) {
              //           if (value == null || value.isEmpty) {
              //             return 'Please enter server URL';
              //           }
              //           return null;
              //         },
              //       ),
              //     ),
                  
              //     ListTile(
              //       leading: const Icon(Icons.delete_forever, color: Colors.red),
              //       title: const Text('Clear All App Data'),
              //       subtitle: const Text('Delete all saved data (Caution: Cannot be undone)'),
              //       onTap: _showClearDataDialog,
              //     ),
              //     // PASSWORD MANAGEMENT SECTION - only for owner
              //       const Divider(),
              //       _buildSectionHeader('Password Management'),
              //       _buildPasswordManagementSection(),
                
              // ],

                
                // ABOUT
                const Divider(),
                ListTile(
                  title: const Text('SIMS RESTO CAFE'),
                  subtitle: const Text('Version 1.0.0'),
                  leading: const Icon(Icons.info_outline),
                ),
                const SizedBox(height: 40),
              ],
            ),
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
  // Add this new method to build the password management section
  // Widget _buildPasswordManagementSection() {
  //   return Card(
  //     child: Padding(
  //       padding: const EdgeInsets.all(16),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           const Text(
  //             'Change Settings Passwords',
  //             style: TextStyle(
  //               fontSize: 16,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //           const SizedBox(height: 16),
            
  //           // Staff password field
  //           TextFormField(
  //             decoration: const InputDecoration(
  //               labelText: 'Staff Password',
  //               border: OutlineInputBorder(),
  //               helperText: 'Change password for staff members',
  //             ),
  //             obscureText: true,
  //             onChanged: (value) {
  //               // Store password temporarily
  //               _tempStaffPassword = value;
  //             },
  //           ),
  //           const SizedBox(height: 16),
            
  //           // Owner password field
  //           TextFormField(
  //             decoration: const InputDecoration(
  //               labelText: 'Owner Password',
  //               border: OutlineInputBorder(),
  //               helperText: 'Change password for owners',
  //             ),
  //             obscureText: true,
  //             onChanged: (value) {
  //               // Store password temporarily
  //               _tempOwnerPassword = value;
  //             },
  //           ),
  //           const SizedBox(height: 16),
            
  //           // Save passwords button
  //           ElevatedButton(
  //             onPressed: _savePasswords,
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Colors.blue.shade700,
  //               foregroundColor: Colors.white,
  //             ),
  //             child: const Text('Update Passwords'),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  // Store temporary passwords
  // String _tempStaffPassword = '';
  // String _tempOwnerPassword = '';
  
  // Method to save updated passwords
//   Future<void> _savePasswords() async {
//     final passwordService = SettingsPasswordService();
//     bool staffUpdated = false;
//     bool ownerUpdated = false;
    
//     if (_tempStaffPassword.isNotEmpty) {
//       staffUpdated = await passwordService.updatePassword(1, _tempStaffPassword);
//     }
    
//     if (_tempOwnerPassword.isNotEmpty) {
//       ownerUpdated = await passwordService.updatePassword(2, _tempOwnerPassword);
//     }
    
//     if (staffUpdated || ownerUpdated) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Passwords updated successfully')),
//         );
//       }
//     } else if (_tempStaffPassword.isNotEmpty || _tempOwnerPassword.isNotEmpty) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('No passwords were updated')),
//         );
//       }
//     }
//   }
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
  
  Widget _buildSubsectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
}