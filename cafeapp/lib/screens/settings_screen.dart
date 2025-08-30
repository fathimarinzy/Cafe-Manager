import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/table_provider.dart';
import '../providers/settings_provider.dart';
import '../services/demo_service.dart'; // Add this import
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
import '../services/license_service.dart';
import 'renewal_screen.dart';


class SettingsScreen extends StatefulWidget {
  final String userType;
  const SettingsScreen({super.key, this.userType = 'staff'});
   
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final _showAdvancedSettings = false;
  bool get _isOwner => widget.userType == 'owner';
  bool _isDemoMode = false;
  bool _isDemoExpired = false;
  int _remainingDemoDays = 0;

   // Add these license-related variables
  bool _isLicenseExpired = false;
  int _remainingLicenseDays = 0;
  bool _isRegularUser = false;
  
  // Business Information
  final _businessNameController = TextEditingController();
  final _secondBusinessNameController = TextEditingController();
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
    _checkDemoStatus();
    _checkLicenseStatus(); 
  }
    
  // Add this method
Future<void> _checkLicenseStatus() async {
  final licenseStatus = await LicenseService.getLicenseStatus();
  
  setState(() {
    _isRegularUser = licenseStatus['isRegistered'] && !_isDemoMode;
    _isLicenseExpired = licenseStatus['isExpired'];
    _remainingLicenseDays = licenseStatus['remainingDays'];
  });

}
  
  Future<void> _checkDemoStatus() async {
    final isDemoMode = await DemoService.isDemoMode();
    final isDemoExpired = await DemoService.isDemoExpired();
    final remainingDays = await DemoService.getRemainingDemoDays();
    
    setState(() {
      _isDemoMode = isDemoMode;
      _isDemoExpired = isDemoExpired;
      _remainingDemoDays = remainingDays;
    });
  }
  
  @override
  void dispose() {
    _businessNameController.dispose();
    _secondBusinessNameController.dispose();
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
      _secondBusinessNameController.text = settingsProvider.secondBusinessName;
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
    // Check if demo is expired and prevent saving
    if (_isDemoExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demo expired. Settings cannot be modified.'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
          secondBusinessName: _secondBusinessNameController.text,
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
      
      final prefs = await SharedPreferences.getInstance();
      final deviceRegistered = prefs.getBool('device_registered') ?? false;
      final deviceId = prefs.getString('device_id');
      final companyName = prefs.getString('company_name');
      final deviceName = prefs.getString('device_name');
      final registrationDate = prefs.getString('registration_date');
      
      final dbResetService = DatabaseResetService();
      await dbResetService.forceResetAllDatabases();
      
      if (!mounted) return;
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.resetSettings();
      
      if (deviceRegistered) {
        await prefs.setBool('device_registered', true);
        if (deviceId != null) await prefs.setString('device_id', deviceId);
        if (companyName != null) await prefs.setString('company_name', companyName);
        if (deviceName != null) await prefs.setString('device_name', deviceName);
        if (registrationDate != null) await prefs.setString('registration_date', registrationDate);
        
        debugPrint('✅ Device registration preserved after reset');
      }
      
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
                  if (!deviceRegistered) {
                    SystemNavigator.pop();
                  } 
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
            leading: Icon(Icons.table_bar, color: _isDemoExpired ? Colors.grey : Colors.blue[700]),
            title: Text('Table Management'.tr()),
            subtitle: Text('Configure dining tables and layout'.tr()),
            trailing: _isDemoExpired ? null : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _isDemoExpired ? null : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TableManagementScreen(),
                ),
              );
            },
            enabled: !_isDemoExpired,
          ),
          const Divider(height: 1, indent: 70),
          ListTile(
            leading: Icon(Icons.grid_view, color: _isDemoExpired ? Colors.grey : Colors.blue[700]),
            title: Text('Dining Table Layout'.tr()),
            subtitle: Text('Configure table rows and columns'.tr()),
            trailing: _isDemoExpired ? null : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _isDemoExpired ? null : _showLayoutDialog,
            enabled: !_isDemoExpired,
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
        // Only show save button if not expired (for demo or regular users)
        if (!_isDemoExpired && !(_isRegularUser && _isLicenseExpired))
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
                // Only show business information if not expired or is active demo
                if (!_isDemoExpired || _isDemoMode && !(_isRegularUser && _isLicenseExpired)) ...[
                  _buildSectionHeader('Business Information'.tr()),
                  _buildBusinessInfoSection(),
                  const Divider(),
                ],

                // Only show other sections if demo is not expired
                if (!_isDemoExpired && !(_isRegularUser && _isLicenseExpired)) ...[
                  _buildSectionHeader('Expense'.tr()),
                  _expenseSection(),
                  const Divider(),
                ],
                
                // Always show Reports section (even if demo expired)
                _buildSectionHeader('Reports'.tr()),
                _buildReportsSection(),
                const Divider(),
                
                // Only show other sections if demo is not expired
                if (!_isDemoExpired && !(_isRegularUser && _isLicenseExpired)) ...[
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
                ],
                
                _buildSectionHeader('Logout'.tr()),
                _logoutsection(),

                // About section
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
                      
                      // Show license info for regular users, demo info for demo users, or contact for others
                      if (_isRegularUser) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isLicenseExpired ? Colors.red[50] : 
                                  _remainingLicenseDays <= 30 ? Colors.blue[50] : Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isLicenseExpired ? Colors.red[300]! : 
                                    _remainingLicenseDays <= 30 ? Colors.blue[300]! : Colors.blue[300]!,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(13),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _isLicenseExpired ? Icons.access_time : Icons.verified,
                                    color: _isLicenseExpired ? Colors.red[700] :
                                          _remainingLicenseDays <= 30 ? Colors.blue[900] : Colors.blue[900], 
                                    size: 20
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isLicenseExpired ? 'License Expired'.tr() : 'License Active'.tr(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _isLicenseExpired ? Colors.red[700] : 
                                            _remainingLicenseDays <= 30 ? Colors.blue[900] : Colors.blue[900],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (!_isLicenseExpired)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _remainingLicenseDays <= 30 ? Colors.red[100] : Colors.green[100],
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _remainingLicenseDays <= 30 ? Colors.red[300]! : Colors.green[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        '$_remainingLicenseDays ${'days left'.tr()}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _remainingLicenseDays <= 30 ? Colors.red[700] : Colors.green[700],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 25),
                              
                              // Main content row with support info on left and button on right
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Support information column (left side)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isLicenseExpired ? 
                                          'Contact support for license renewal:' :
                                          _remainingLicenseDays <= 30 ?
                                          'License expiring soon. Contact support for renewal:' :
                                          'Contact support for assistance:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
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
                                  ),
                                  
                                  // Spacer between support info and button
                                  const SizedBox(width: 16),
                                  
                                  // Renew button (right side)
                                  if (_isLicenseExpired || _remainingLicenseDays <= 30)
                                    Container(
                                      alignment: Alignment.topCenter,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => const RenewalScreen(renewalType: RenewalType.license),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _isLicenseExpired ? Colors.red[600] : Colors.blue[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          elevation: 2,
                                          shadowColor: Colors.black.withAlpha(51),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // const Icon(Icons.autorenew, size: 20),
                                            // const SizedBox(height: 4),
                                            Text(
                                              'Renew License'.tr(),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else if (_isDemoMode && !_isDemoExpired) ...[
                        // Existing demo mode display code
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.schedule, color: Colors.blue[900], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Demo Mode Active'.tr(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _remainingDemoDays <= 5 ? Colors.red[100] : Colors.green[100],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _remainingDemoDays <= 5 ? Colors.red[300]! : Colors.green[300]!,
                                      ),
                                    ),
                                    child: Text(
                                      '$_remainingDemoDays ${'days left'.tr()}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _remainingDemoDays <= 5 ? Colors.red[700] : Colors.green[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                               Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _remainingDemoDays <= 5 ? 
                                      'Demo expiring soon. Renew demo or contact support:' :
                                      'Contact support for full registration:',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  // Add renewal button for demo
                                  if (_remainingDemoDays <= 7) // Show renewal option in last week
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => const RenewalScreen(renewalType: RenewalType.demo),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[700],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        'Renew'.tr(),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                 ],
                               ),
                              Text(
                                'Contact support for full registration:',
                                style: TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
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
                        ),
                      ] else if (_isDemoExpired) ...[
                        // Existing demo expired display code
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.access_time, color: Colors.red[700], size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Demo Expired'.tr(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red[700],
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => const RenewalScreen(renewalType: RenewalType.demo),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[700],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        'Renew'.tr(),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 8),
                              Text(
                                'Contact support for full registration:',
                                style: TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                            ],
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
                      ] else ...[
                        // Default contact numbers for other cases
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

  String _getOwnerText() {
    return 'Owner'.tr();
  }

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
            leading: Icon(Icons.backup, color: _isDemoExpired ? Colors.grey : Colors.blue[700]),
            title: Text('Backup & Restore'.tr()),
            subtitle: Text('Create, restore, and manage backups'.tr()),
            trailing: _isDemoExpired ? null : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _isDemoExpired ? null : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BackupManagerWidget(),
                ),
              );
            },
            enabled: !_isDemoExpired,
          ),
          const Divider(height: 1, indent: 70),
          ListTile(
            leading: Icon(Icons.delete_forever, color: _isDemoExpired ? Colors.grey : Colors.red[700]),
            title: Text('Reset Data'.tr()),
            subtitle: Text('Clear all app data'.tr()),
            onTap: _isDemoExpired ? null : _showResetConfirmationDialog,
            enabled: !_isDemoExpired,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTaxSettingsSection() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.attach_money, color: _isDemoExpired ? Colors.grey : Colors.blue[700]),
        title: Text('Tax Settings'.tr()),
        subtitle: Text('${'Current Tax Rate'.tr()}: ${_taxRateController.text}%'),
        trailing: _isDemoExpired ? null : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _isDemoExpired ? null : _showTaxSettingsDialog,
        enabled: !_isDemoExpired,
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
        leading: Icon(Icons.analytics, color: Colors.blue[700]), // Always enabled
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
        leading: Icon(Icons.business, color: (_isOwner && !_isDemoExpired) ? Colors.blue[700] : Colors.grey),
        title: Text('Business Information'.tr()),
        subtitle: Text((_isOwner && !_isDemoExpired)
            ? (_businessNameController.text.isNotEmpty 
                ? _businessNameController.text 
                : 'Configure restaurant details'.tr())
            : 'Configure restaurant details'.tr()),
        trailing: (_isOwner && !_isDemoExpired) ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
        onTap: (_isOwner && !_isDemoExpired) ? _showBusinessInfoDialog : null,
        enabled: (_isOwner && !_isDemoExpired),
        tileColor: (_isOwner && !_isDemoExpired) ? null : Colors.grey.shade100,
      ),
    );
  }
  
  Widget _expenseSection() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.money_off, color: _isDemoExpired ? Colors.grey : Colors.blue[700]),
        title: Text('Expense Management'.tr()),
        subtitle: Text('Track and manage your expenses'.tr()),
        trailing: _isDemoExpired ? null : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _isDemoExpired ? null : () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ExpenseScreen(),
            ),
          );
        },
        enabled: !_isDemoExpired,
      ),
    );
  }
  
  void _showBusinessInfoDialog() {
    final businessNameController = TextEditingController(text: _businessNameController.text);
    final secondBusinessNameController = TextEditingController(text: _secondBusinessNameController.text);
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
                  _secondBusinessNameController.text = secondBusinessNameController.text;
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
        leading: Icon(Icons.inventory, color: _isDemoExpired ? Colors.grey : Colors.blue[700]),
        title: Text('Product Management'.tr()),
        subtitle: Text('Add, edit, or remove menu items'.tr()),
        trailing: _isDemoExpired ? null : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _isDemoExpired ? null : () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ModifierScreen(),
            ),
          );
        },
        enabled: !_isDemoExpired,
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
        leading: Icon(Icons.print, color: _isDemoExpired ? Colors.grey : Colors.blue[700]),
        title: Text('Printer Configuration'.tr()),
        subtitle: Text('Configure thermal printer settings'.tr()),
        trailing: _isDemoExpired ? null : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _isDemoExpired ? null : () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PrinterSettingsScreen(),
            ),
          );
        },
        enabled: !_isDemoExpired,
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