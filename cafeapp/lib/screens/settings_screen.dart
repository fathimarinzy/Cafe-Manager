import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/table_provider.dart';
import '../providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'modifier_screen.dart'; 
import 'table_management_screen.dart'; 
import 'printer_settings_screen.dart'; 
import '../utils/app_localization.dart';
import '../screens/expense_screen.dart';
import '../screens/report_screen.dart';
import '../widgets/backup_manager_widget.dart';
import '../utils/database_reset_service.dart';
import 'package:flutter/services.dart';


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
  final _secondBusinessNameController = TextEditingController(); // Add second business name controller
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
    _secondBusinessNameController.dispose(); // Dispose second business name controller
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
      
      if (!settingsProvider.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (!mounted) return;
      
      _businessNameController.text = settingsProvider.businessName;
      _secondBusinessNameController.text = settingsProvider.secondBusinessName; // Load second business name
      _addressController.text = settingsProvider.businessAddress;
      _phoneController.text = settingsProvider.businessPhone;
      
      _autoPrintReceipts = settingsProvider.autoPrintReceipts;
      _autoPrintKitchenOrders = settingsProvider.autoPrintKitchenOrders;
      _selectedPrinter = settingsProvider.selectedPrinter;
      
      _taxRateController.text = settingsProvider.taxRate.toString();
      
      _tableRows = settingsProvider.tableRows;
      _tableColumns = settingsProvider.tableColumns;
      
      _receiptFooterController.text = settingsProvider.receiptFooter;
      
      _selectedTheme = settingsProvider.appTheme;
      _selectedLanguage = settingsProvider.appLanguage;
      
      _serverUrlController.text = settingsProvider.serverUrl;
    } catch (e) {
      debugPrint('Error loading settings: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'Error loading settings'.tr()}: $e')),
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
      
      double taxRate = 5.0;
      try {
        taxRate = double.parse(_taxRateController.text);
      } catch (e) {
        debugPrint('Error parsing tax rate: $e');
      }
        
      if (_isOwner) {
        await settingsProvider.saveAllSettings(
          businessName: _businessNameController.text,
          secondBusinessName: _secondBusinessNameController.text, // Save second business name
          businessAddress: _addressController.text,
          businessPhone: _phoneController.text,
          taxRate: taxRate,
          tableRows: _tableRows,
          tableColumns: _tableColumns,
          serverUrl: _showAdvancedSettings ? _serverUrlController.text : null,
        );
      }
      
      await settingsProvider.saveAllSettings(
        autoPrintReceipts: _autoPrintReceipts,
        autoPrintKitchenOrders: _autoPrintKitchenOrders,
        selectedPrinter: _selectedPrinter,
        taxRate: taxRate,
        tableRows: _tableRows,
        tableColumns: _tableColumns,
        receiptFooter: _receiptFooterController.text,
        appTheme: _selectedTheme,
        appLanguage: _selectedLanguage,
        serverUrl: _serverUrlController.text,
      );
      
      if (!mounted) return;
      
      final tableProvider = Provider.of<TableProvider>(context, listen: false);
      await tableProvider.refreshTables();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settings saved successfully'.tr())),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'Error saving settings'.tr()}: $e')),
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

  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset All Data'.tr()),
        content: Text(
          'This will delete all app data. This action cannot be undone. Are you sure you want to continue?'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            child: Text('No'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showPasswordDialog();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Yes'.tr()),
          ),
        ],
      ),
    );
  }

  void _showPasswordDialog() {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isPasswordIncorrect = false;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter Password:'.tr()),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password'.tr(),
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the password'.tr();
              }
              if (isPasswordIncorrect) {
                return 'Incorrect password'.tr();
              }
              return null;
            },
            onChanged: (value) {
              if (isPasswordIncorrect) {
                setState(() {
                  isPasswordIncorrect = false;
                });
                formKey.currentState?.validate();
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              if (passwordController.text == '1234') {
                Navigator.of(ctx).pop();
                _resetAllData();
              } else {
                setState(() {
                  isPasswordIncorrect = true;
                });
                formKey.currentState?.validate();
              }
            },
            child: Text('Verify'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAllData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Resetting data... Please wait.'.tr()),
                  const SizedBox(height: 8),
                  Text(
                    'This may take a moment. Do not close the app.'.tr(),
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      
      final dbResetService = DatabaseResetService();
      await dbResetService.forceResetAllDatabases();
      
      if (!mounted) return;
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.resetSettings();
      
      if (!mounted) return;
      final tableProvider = Provider.of<TableProvider>(context, listen: false);
      await tableProvider.refreshTables();
      
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text('Reset Complete'.tr()),
            content: Text(
              'All data has been reset successfully. You must restart the app for changes to take effect completely.'.tr(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _loadSettings();
                  // Close the app completely
                  SystemNavigator.pop();
                },
                child: Text('OK'.tr()),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      
      debugPrint('Error resetting data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'Error resetting data'.tr()}: $e')),
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

  Widget _buildTablesSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.table_bar, color: Colors.blue[700]),
            title: Text('Table Management'.tr()),
            subtitle: Text('Configure dining tables and layout'.tr()),
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
            title: Text('Dining Table Layout'.tr()),
            subtitle: Text('Configure table rows and columns'.tr()),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showLayoutDialog,
          ),
        ],
      ),
    );
  }
  
  void _showLayoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        
        return AlertDialog(
          title: Text(
            'Select Table Layout'.tr(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          content: SizedBox(
            width: screenWidth * 0.65,
            child: ListView(
              shrinkWrap: true,
              children: _layoutOptions.map((option) {
                return ListTile(
                  dense: true,
                  title: Text(
                    option['label'],
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _tableRows = option['rows'];
                      _tableColumns = option['columns'];
                    });
                    _saveLayout(option['rows'], option['columns']);
                    Navigator.pop(context);
                  },
                  trailing: (_tableRows == option['rows'] && _tableColumns == option['columns']) 
                    ? const Icon(Icons.check, color: Colors.green, size: 18)
                    : null,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel'.tr(),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _saveLayout(int rows, int columns) async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.saveAllSettings(
        tableRows: rows,
        tableColumns: columns,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dining_table_rows', rows);
      await prefs.setInt('dining_table_columns', columns);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Table layout saved'.tr())),
        );
      }
    } catch (e) {
      debugPrint('Error saving layout settings: $e');
    }
  }
  
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
        title: Text('${'Settings'.tr()} ${_isOwner ? "(${_getOwnerText()})" : ""}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save),
            label: Text('Save'.tr()),
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
                _buildSectionHeader('Business Information'.tr()),
                _buildBusinessInfoSection(),

                const Divider(),
                _buildSectionHeader('Expense'.tr()),
                _expenseSection(),
                const Divider(),
                _buildSectionHeader('Reports'.tr()),
                _buildReportsSection(),
                const Divider(),
                _buildSectionHeader('Tax Settings'.tr()),
                _buildTaxSettingsSection(),
                 
                const Divider(),
                
                _buildSectionHeader('Printer Settings'.tr()),
                _buildPrinterSettingsSection(),
                const Divider(),
              
                _buildSectionHeader('Products'.tr()),
                _buildProductSection(),
                const Divider(),
                
                _buildSectionHeader('Tables'.tr()),
                _buildTablesSection(),
                const Divider(),
                
                _buildSectionHeader('Data & Backup'.tr()),
                _buildDataBackupSection(),
                const SizedBox(height: 16),
                const Divider(),
                _buildSectionHeader('Appearance'.tr()),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text('Language'.tr()),
                        subtitle: Text(_getLanguageDisplayName(_selectedLanguage)),
                        trailing: DropdownButton<String>(
                          value: _selectedLanguage,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedLanguage = newValue;
                              });
                              
                              final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                              settingsProvider.setLanguage(newValue);
                                
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Language changed successfully'.tr()),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          items: <String>['English', 'Arabic']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(_getLanguageDisplayName(value)),
                            );
                          }).toList(),
                          underline: Container(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                
                InkWell(
                  onTap: () {
                    setState(() {
                      _showAdvancedSettings = !_showAdvancedSettings;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [],
                    ),
                  ),
                ),
                
                _buildSectionHeader('Logout'.tr()),
                _logoutsection(),

                // const Divider(),
                // About section with contact numbers
                ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ''.tr(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '+968 7184 0022',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '+968 9906 2181',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '+968 7989 5704',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Version 1.0.1'.tr()),
                  ),
                  leading: const Icon(Icons.contact_support),
                ),
             
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  // Helper method to get owner text translation
  String _getOwnerText() {
    return 'Owner'.tr();
  }

  // Helper method to get language display name
  String _getLanguageDisplayName(String language) {
    switch (language) {
      case 'English':
        return 'English'.tr();
      case 'Arabic':
        return 'Arabic'.tr();
      default:
        return language;
    }
  }

  Widget _buildDataBackupSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.backup, color: Colors.blue[700]),
            title: Text('Backup & Restore'.tr()),
            subtitle: Text('Create, restore, and manage backups'.tr()),
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
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red[700]),
            title: Text('Reset Data'.tr()),
            subtitle: Text('Clear all app data'.tr()),
            onTap: _showResetConfirmationDialog,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTaxSettingsSection() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.attach_money, color: Colors.blue[700]),
        title: Text('Tax Settings'.tr()),
        subtitle: Text('${'Current Tax Rate'.tr()}: ${_taxRateController.text}%'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _showTaxSettingsDialog,
      ),
    );
  }

  void _showTaxSettingsDialog() {
    final taxRateController = TextEditingController(text: _taxRateController.text);
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Tax Settings'.tr()),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${'Current Tax Rate'.tr()}: ${_taxRateController.text}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                TextFormField(
                  controller: taxRateController,
                  decoration: InputDecoration(
                    labelText: 'Sales Tax Rate (%)'.tr(),
                    border: const OutlineInputBorder(),
                    suffixText: '%',
                    hintText: 'Enter your tax rate (e.g., 5.0)'.tr(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter tax rate'.tr();
                    }
                    try {
                      final rate = double.parse(value);
                      if (rate < 0 || rate > 100) {
                        return 'Tax rate must be between 0 and 100'.tr();
                      }
                    } catch (e) {
                      return 'Please enter a valid number'.tr();
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
              child: Text('Cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  setState(() {
                    _taxRateController.text = taxRateController.text;
                  });
                  
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tax rate updated (not saved yet)'.tr())),
                  );
                }
              },
              child: Text('Update'.tr()),
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
        title: Text('Reports'.tr()),
        subtitle: Text('View daily and monthly sales reports'.tr()),
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
  
  Widget _buildBusinessInfoSection() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.business, color: _isOwner ? Colors.blue[700] : Colors.grey),
        title: Text('Business Information'.tr()),
        subtitle: Text(_isOwner 
            ? (_businessNameController.text.isNotEmpty 
                ? _businessNameController.text 
                : 'Configure restaurant details'.tr())
            : 'Configure restaurant details'.tr()),
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
        title: Text('Expense Management'.tr()),
        subtitle: Text('Track and manage your expenses'.tr()),
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
  
  void _showBusinessInfoDialog() {
    final businessNameController = TextEditingController(text: _businessNameController.text);
    final secondBusinessNameController = TextEditingController(text: _secondBusinessNameController.text); // Add second business name controller
    final addressController = TextEditingController(text: _addressController.text);
    final phoneController = TextEditingController(text: _phoneController.text);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Business Information'.tr()),
          content: SingleChildScrollView(
            child: Form(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: businessNameController,
                    decoration: InputDecoration(
                      labelText: 'Restaurant Name'.tr(),
                      border: const OutlineInputBorder(),
                      hintText: 'Enter your restaurant name'.tr(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter restaurant name'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Add second restaurant name field
                  TextFormField(
                    controller: secondBusinessNameController,
                    decoration: InputDecoration(
                      labelText: 'Second Restaurant Name'.tr(),
                      border: const OutlineInputBorder(),
                      hintText: 'Enter second restaurant name (optional)'.tr(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Address'.tr(),
                      border: const OutlineInputBorder(),
                      hintText: 'Enter your restaurant address'.tr(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number'.tr(),
                      border: const OutlineInputBorder(),
                      hintText: 'Enter your restaurant phone number'.tr(),
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
              child: Text('Cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _businessNameController.text = businessNameController.text;
                  _secondBusinessNameController.text = secondBusinessNameController.text; // Update second business name
                  _addressController.text = addressController.text;
                  _phoneController.text = phoneController.text;
                });
                
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Business information updated (not saved yet)'.tr())),
                );
              },
              child: Text('Update'.tr()),
            ),
          ],
        );
      },
    );
  }
  
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.15,
          vertical: MediaQuery.of(context).size.height * 0.3
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Logout'.tr(), 
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                )
              ),
              const SizedBox(height: 20),
              Text(
                'Are you sure you want to logout?'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 120,
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                        textStyle: const TextStyle(fontSize: 16),
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
                    width: 120,
                    height: 48,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        authProvider.logout();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildProductSection() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.inventory, color: Colors.blue[700]),
        title: Text('Product Management'.tr()),
        subtitle: Text('Add, edit, or remove menu items'.tr()),
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
        leading: Icon(Icons.logout, color: Colors.blue[700]),
        title: Text('Logout'.tr()),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          _showLogoutDialog();
        },
      ),
    );
  }
  
  Widget _buildPrinterSettingsSection() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.print, color: Colors.blue[700]),
        title: Text('Printer Configuration'.tr()),
        subtitle: Text('Configure thermal printer settings'.tr()),
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