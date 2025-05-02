import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/table_provider.dart';
import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
   
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showAdvancedSettings = false;
  
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
      
      // Save all settings at once
      await settingsProvider.saveAllSettings(
        // Business info
        businessName: _businessNameController.text,
        businessAddress: _addressController.text,
        businessPhone: _phoneController.text,
        
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
  
  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Clear All Data'),
          content: const Text(
            'This will delete all app data including orders, settings, and login information.\n\n'
            'This action cannot be undone. Are you sure you want to continue?'
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.pop(dialogContext);
                _clearAllData();
              },
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _clearAllData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Reset settings provider
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.resetSettings();
      
      // Clear secure storage
      const storage = FlutterSecureStorage();
      await storage.deleteAll();
      
      // Check if widget is still mounted before accessing context
      if (!mounted) return;
      
      // Log out the user
      Provider.of<AuthProvider>(context, listen: false).logout();
      
      // Navigate to login screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Error clearing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing data: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _businessNameController,
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
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                      hintText: 'Enter your restaurant address',
                    ),
                    maxLines: 2,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                      hintText: 'Enter your restaurant phone number',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const Divider(),
                
                // TAX SETTINGS - Important for sales
                _buildSectionHeader('Tax Settings'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _taxRateController,
                    decoration: const InputDecoration(
                      labelText: 'Sales Tax Rate (%)',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                      hintText: 'Enter your tax rate (e.g., 5.0)',
                    ),
                    keyboardType: TextInputType.number,
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
                ),
                const Divider(),
                
                // RECEIPT SETTINGS
                _buildSectionHeader('Receipt Settings'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _receiptFooterController,
                    decoration: const InputDecoration(
                      labelText: 'Receipt Footer Message',
                      border: OutlineInputBorder(),
                      hintText: 'Thank you message for receipt',
                    ),
                    maxLines: 2,
                  ),
                ),
                
                // PRINTER SETTINGS
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
                
                // TABLE LAYOUT
                _buildSectionHeader('Dining Tables Layout'),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Number of Rows'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: _tableRows,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              onChanged: (int? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _tableRows = newValue;
                                  });
                                }
                              },
                              items: List.generate(8, (index) => index + 1)
                                  .map<DropdownMenuItem<int>>((int value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text(value.toString()),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Number of Columns'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: _tableColumns,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              onChanged: (int? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _tableColumns = newValue;
                                  });
                                }
                              },
                              items: List.generate(8, (index) => index + 1)
                                  .map<DropdownMenuItem<int>>((int value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text(value.toString()),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                      ListTile(
                        title: const Text('Theme'),
                        subtitle: Text(_selectedTheme),
                        trailing: DropdownButton<String>(
                          value: _selectedTheme,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedTheme = newValue;
                              });
                            }
                          },
                          items: <String>['Light', 'Dark', 'System Default']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          underline: Container(),
                        ),
                      ),
                      const Divider(height: 1, indent: 16),
                      ListTile(
                        title: const Text('Language'),
                        subtitle: Text(_selectedLanguage),
                        trailing: DropdownButton<String>(
                          value: _selectedLanguage,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedLanguage = newValue;
                              });
                            }
                          },
                          items: <String>['English', 'Spanish', 'French', 'Arabic']
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
                        Icon(
                          _showAdvancedSettings 
                              ? Icons.keyboard_arrow_up 
                              : Icons.keyboard_arrow_down,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _showAdvancedSettings
                              ? 'Hide Advanced Settings'
                              : 'Show Advanced Settings',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // ADVANCED SETTINGS (hidden by default)
                if (_showAdvancedSettings) ...[
                  const Divider(),
                  _buildSectionHeader('Advanced Settings'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        border: OutlineInputBorder(),
                        hintText: 'https://example.com/api',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter server URL';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text('Clear All App Data'),
                    subtitle: const Text('Delete all saved data (Caution: Cannot be undone)'),
                    onTap: _showClearDataDialog,
                  ),
                ],
                
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
}