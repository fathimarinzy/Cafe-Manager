import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localization.dart';
import '../services/online_sync_service.dart';

class SettingsProvider with ChangeNotifier {
  // Server settings
  String _serverUrl = 'https://ftrinzy.pythonanywhere.com/api';
  
  // Printer settings
  bool _autoPrintReceipts = true;
  bool _autoPrintKitchenOrders = true;
  String _selectedPrinter = 'Default Printer';

  // Device Sync
  bool _deviceSyncEnabled = false;

  // Input settings
  bool _doubleTapToOpenKeyboard = false;

  
  // App appearance
  String _appTheme = 'Light';
  String _appLanguage = 'English';
  
  // Tax settings
  double _taxRate = 0.0;
  bool _isVatInclusive = false; // NEW: Add this field

  // Table layout
  int _tableRows = 4;
  int _tableColumns = 4;
  
  // Business information
  String _businessName = 'SIMS CAFE';
  String _secondBusinessName = ''; // Add second business name field
  String _businessAddress = '';
  String _businessPhone = '';
  String _businessEmail = '';

  
  // Receipt settings
  String _receiptFooter = 'Thank you for your visit! Please come again.';
  
  // Loading state
  bool _isLoading = false;
  bool _isInitialized = false;
  
  // Theme mode
  ThemeMode _themeMode = ThemeMode.light;

  // Get the language code from language name
  String get languageCode {
    switch (_appLanguage.toLowerCase()) {
      case 'arabic':
        return 'ar';
      case 'english':
      default:
        return 'en';
    }
  }

  // Getters
  String get serverUrl => _serverUrl;
  bool get autoPrintReceipts => _autoPrintReceipts;
  bool get autoPrintKitchenOrders => _autoPrintKitchenOrders;
  String get selectedPrinter => _selectedPrinter;
  bool get deviceSyncEnabled => _deviceSyncEnabled;
  bool get doubleTapToOpenKeyboard => _doubleTapToOpenKeyboard;

  String get appTheme => _appTheme;
  String get appLanguage => _appLanguage;
  double get taxRate => _taxRate;
  int get tableRows => _tableRows;
  int get tableColumns => _tableColumns;
  String get businessName => _businessName;
  String get secondBusinessName => _secondBusinessName; // Add getter for second business name
  String get businessAddress => _businessAddress;
  String get businessPhone => _businessPhone;
  String get businessEmail => _businessEmail;

  String get receiptFooter => _receiptFooter;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  ThemeMode get themeMode => _themeMode;
  bool get isVatInclusive => _isVatInclusive;

  SettingsProvider() {
      _loadSettings().then((_) {
    // Initialize the language after settings are loaded
    initializeLanguage();
  });
  }
  
  // Convert string theme to ThemeMode
  ThemeMode _getThemeModeFromString(String theme) {
    switch (theme.toLowerCase()) {
      case 'dark':
        return ThemeMode.dark;
      case 'system default':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }
  
  // Convert ThemeMode to string
  String _getStringFromThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light';
    }
  }
  // Update the setLanguage method
  Future<void> setLanguage(String language) async {
    if (_appLanguage != language) {
      await setSetting('app_language', language);
      _appLanguage = language;
      
      // Update the AppLocalization instance with the new language code
      AppLocalization().setLanguage(languageCode);
      
      notifyListeners();
    }
  }

  // Initialize language on app start
  void initializeLanguage() {
    AppLocalization().setLanguage(languageCode);
  }
 
  // Method specifically for updating tax rate
  Future<void> updateTaxRate(double newRate) async {
    if (newRate < 0 || newRate > 100) {
      throw Exception('Tax rate must be between 0 and 100');
    }
    
    await setSetting('tax_rate', newRate);
    _taxRate = newRate;
    
    // Make sure to notify listeners so all dependent widgets update
    notifyListeners();
    
    // Log for debugging
    debugPrint('Tax rate updated to $_taxRate%');
  }
    
  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load server settings
      _serverUrl = prefs.getString('server_url') ?? _serverUrl;
      
      // Load printer settings
      _autoPrintReceipts = prefs.getBool('auto_print_receipts') ?? _autoPrintReceipts;
      _autoPrintKitchenOrders = prefs.getBool('auto_print_kitchen') ?? _autoPrintKitchenOrders;
      _selectedPrinter = prefs.getString('selected_printer') ?? _selectedPrinter;
      
      // Load Device Sync
      _deviceSyncEnabled = prefs.getBool('device_sync_enabled') ?? false; // Default to false if not set

      // Load Input settings
      _doubleTapToOpenKeyboard = prefs.getBool('double_tap_keyboard') ?? false;

      
      // Load appearance settings
      _appTheme = prefs.getString('app_theme') ?? _appTheme;
      _appLanguage = prefs.getString('app_language') ?? _appLanguage;
      
      // Set the theme mode based on theme string
      _themeMode = _getThemeModeFromString(_appTheme);
      
      // Load tax settings
      _taxRate = prefs.getDouble('tax_rate') ?? _taxRate;
      _isVatInclusive = prefs.getBool('is_vat_inclusive') ?? _isVatInclusive;

      // Load table layout
      _tableRows = prefs.getInt('table_rows') ?? _tableRows;
      _tableColumns = prefs.getInt('table_columns') ?? _tableColumns;
      
      // Load business info
      _businessName = prefs.getString('business_name') ?? _businessName;
      _secondBusinessName = prefs.getString('second_business_name') ?? _secondBusinessName; // Load second business name
      _businessAddress = prefs.getString('business_address') ?? _businessAddress;
      _businessPhone = prefs.getString('business_phone') ?? _businessPhone;
      _businessEmail = prefs.getString('business_email') ?? _businessEmail;

      // Load receipt settings
      _receiptFooter = prefs.getString('receipt_footer') ?? _receiptFooter;
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Helper to sync business info
  Future<void> _triggerBusinessInfoSync() async {
    try {
      await OnlineSyncService.syncBusinessInfo(
        businessName: _businessName,
        secondBusinessName: _secondBusinessName,
        businessAddress: _businessAddress,
        businessPhone: _businessPhone,
        businessEmail: _businessEmail,
      );
    } catch (e) {
      debugPrint('Error triggering business info sync: $e');
    }
  }

  // Save a single setting
  Future<void> setSetting(String key, dynamic value) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isBusinessInfoUpdated = false;
      
      // Update the appropriate field based on key
      switch (key) {
        case 'server_url':
          if (value is String) {
            _serverUrl = value;
            await prefs.setString(key, value);
          }
          break;
        case 'auto_print_receipts':
          if (value is bool) {
            _autoPrintReceipts = value;
            await prefs.setBool(key, value);
          }
          break;
        case 'auto_print_kitchen':
          if (value is bool) {
            _autoPrintKitchenOrders = value;
            await prefs.setBool(key, value);
          }
          break;
        case 'selected_printer':
          if (value is String) {
            _selectedPrinter = value;
            await prefs.setString(key, value);
          }
          break;
        case 'device_sync_enabled':
          if (value is bool) {
            _deviceSyncEnabled = value;
            await prefs.setBool(key, value);
          }
          break;
        case 'double_tap_keyboard':
          if (value is bool) {
            _doubleTapToOpenKeyboard = value;
            await prefs.setBool(key, value);
          }
          break;

        case 'app_theme':
          if (value is String) {
            _appTheme = value;
            await prefs.setString(key, value);
            // Also update the theme mode
            _themeMode = _getThemeModeFromString(value);
          }
          break;
        case 'app_language':
          if (value is String) {
            _appLanguage = value;
            await prefs.setString(key, value);
          }
          break;
        case 'tax_rate':
          if (value is double) {
            _taxRate = value;
            await prefs.setDouble(key, value);
          }
          break;
        case 'is_vat_inclusive':
          if (value is bool) {
            _isVatInclusive = value;
            await prefs.setBool(key, value);
          }
          break;
        case 'table_rows':
          if (value is int) {
            _tableRows = value;
            await prefs.setInt(key, value);
          }
          break;
        case 'table_columns':
          if (value is int) {
            _tableColumns = value;
            await prefs.setInt(key, value);
          }
          break;
        case 'business_name':
          if (value is String) {
            _businessName = value;
            await prefs.setString(key, value);
            isBusinessInfoUpdated = true;
          }
          break;
        case 'second_business_name': // Add case for second business name
          if (value is String) {
            _secondBusinessName = value;
            await prefs.setString(key, value);
             isBusinessInfoUpdated = true;
          }
          break;
        case 'business_address':
          if (value is String) {
            _businessAddress = value;
            await prefs.setString(key, value);
             isBusinessInfoUpdated = true;
          }
          break;
        case 'business_phone':
          if (value is String) {
            _businessPhone = value;
            await prefs.setString(key, value);
             isBusinessInfoUpdated = true;
          }
          break;
        case 'business_email':
          if (value is String) {
            _businessEmail = value;
            await prefs.setString(key, value);
             isBusinessInfoUpdated = true;
          }
          break;
        case 'receipt_footer':
          if (value is String) {
            _receiptFooter = value;
            await prefs.setString(key, value);
          }
          break;
        case 'theme_mode':
          if (value is ThemeMode) {
            _themeMode = value;
            _appTheme = _getStringFromThemeMode(value);
            await prefs.setString('app_theme', _appTheme);
          }
          break;
      }
      
      // Trigger sync if needed
      if (isBusinessInfoUpdated) {
        _triggerBusinessInfoSync();
      }
      
    } catch (e) {
      debugPrint('Error saving setting $key: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Update theme mode directly
  Future<void> setThemeMode(ThemeMode mode) async {
    await setSetting('theme_mode', mode);
    // This will update _themeMode and _appTheme in the setSetting method
  }
  
  // Save all settings at once
  Future<void> saveAllSettings({
    String? serverUrl,
    bool? autoPrintReceipts,
    bool? autoPrintKitchenOrders,
    String? selectedPrinter,
    String? appTheme,
    String? appLanguage,
    double? taxRate,
    int? tableRows,
    int? tableColumns,
    String? businessName,
    String? secondBusinessName, 
    String? businessAddress,
    String? businessPhone,
    String? businessEmail, 
    String? receiptFooter,
    ThemeMode? themeMode,
    bool? isVatInclusive,

    bool? deviceSyncEnabled,
    bool? doubleTapToOpenKeyboard,

  }) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isBusinessInfoUpdated = false;
      
      // Update server settings
      if (serverUrl != null) {
        _serverUrl = serverUrl;
        await prefs.setString('server_url', serverUrl);
      }
      
      // Update printer settings
      if (autoPrintReceipts != null) {
        _autoPrintReceipts = autoPrintReceipts;
        await prefs.setBool('auto_print_receipts', autoPrintReceipts);
      }
      
      if (autoPrintKitchenOrders != null) {
        _autoPrintKitchenOrders = autoPrintKitchenOrders;
        await prefs.setBool('auto_print_kitchen', autoPrintKitchenOrders);
      }
      
      if (selectedPrinter != null) {
        _selectedPrinter = selectedPrinter;
        await prefs.setString('selected_printer', selectedPrinter);
      }
      
      // Update appearance settings
      if (appTheme != null) {
        _appTheme = appTheme;
        await prefs.setString('app_theme', appTheme);
        // Also update the theme mode
        _themeMode = _getThemeModeFromString(appTheme);
      }
      
      // If themeMode is provided directly, use it and update appTheme
      if (themeMode != null) {
        _themeMode = themeMode;
        _appTheme = _getStringFromThemeMode(themeMode);
        await prefs.setString('app_theme', _appTheme);
      }
      
      if (appLanguage != null) {
        _appLanguage = appLanguage;
        await prefs.setString('app_language', appLanguage);
      }
      
      // Update tax settings
      if (taxRate != null) {
        _taxRate = taxRate;
        await prefs.setDouble('tax_rate', taxRate);
      }
      if (isVatInclusive != null) {
        _isVatInclusive = isVatInclusive;
        await prefs.setBool('is_vat_inclusive', isVatInclusive);
      }
      // Update table layout
      if (tableRows != null) {
        _tableRows = tableRows;
        await prefs.setInt('table_rows', tableRows);
      }
      
      if (tableColumns != null) {
        _tableColumns = tableColumns;
        await prefs.setInt('table_columns', tableColumns);
      }
      
      // Update business info
      if (businessName != null) {
        _businessName = businessName;
        await prefs.setString('business_name', businessName);
        isBusinessInfoUpdated = true;
      }
      if (secondBusinessName != null) { // Add second business name saving
        _secondBusinessName = secondBusinessName;
        await prefs.setString('second_business_name', secondBusinessName);
         isBusinessInfoUpdated = true;
      }
      
      if (businessAddress != null) {
        _businessAddress = businessAddress;
        await prefs.setString('business_address', businessAddress);
         isBusinessInfoUpdated = true;
      }
      
      if (businessPhone != null) {
        _businessPhone = businessPhone;
        await prefs.setString('business_phone', businessPhone);
         isBusinessInfoUpdated = true;
      }

      if (businessEmail != null) {
        _businessEmail = businessEmail;
        await prefs.setString('business_email', businessEmail);
         isBusinessInfoUpdated = true;
      }
      
      // Update receipt settings
      if (receiptFooter != null) {
        _receiptFooter = receiptFooter;
        await prefs.setString('receipt_footer', receiptFooter);
      }
      
      if (deviceSyncEnabled != null) {
        _deviceSyncEnabled = deviceSyncEnabled;
        await prefs.setBool('device_sync_enabled', deviceSyncEnabled);
      }

      if (doubleTapToOpenKeyboard != null) {
        _doubleTapToOpenKeyboard = doubleTapToOpenKeyboard;
        await prefs.setBool('double_tap_keyboard', doubleTapToOpenKeyboard);
      }

      
      // Trigger sync if needed
      if (isBusinessInfoUpdated) {
        _triggerBusinessInfoSync();
      }
      
    } catch (e) {
      debugPrint('Error saving settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Reset all settings to default
  Future<void> resetSettings() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Reset server settings
      _serverUrl = 'https://ftrinzy.pythonanywhere.com/api';
      
      // Reset printer settings
      _autoPrintReceipts = true;
      _autoPrintKitchenOrders = true;
      _selectedPrinter = 'Default Printer';
      
      // Reset appearance settings
      _appTheme = 'Light';
      _appLanguage = 'English';
      _themeMode = ThemeMode.light;
      
      // Reset tax settings
      _taxRate = 0.0;
      _isVatInclusive = false;
      
      // Input settings
      _doubleTapToOpenKeyboard = false;

      
      // Reset table layout
      _tableRows = 4;
      _tableColumns = 4;
      
      // Reset business info
      _businessName = 'SIMS CAFE';
      _secondBusinessName = ''; 
      _businessAddress = '';
      _businessPhone = '';
      _businessEmail = '';
      
      // Reset receipt settings
      _receiptFooter = 'Thank you for your visit! Please come again.';
      
      // Clear all preferences
      await prefs.clear();
      
      // Save the defaults
      await saveAllSettings(
        serverUrl: _serverUrl,
        autoPrintReceipts: _autoPrintReceipts,
        autoPrintKitchenOrders: _autoPrintKitchenOrders,
        selectedPrinter: _selectedPrinter,
        appTheme: _appTheme,
        appLanguage: _appLanguage,
        taxRate: _taxRate,
        tableRows: _tableRows,
        tableColumns: _tableColumns,
        businessName: _businessName,
        secondBusinessName: _secondBusinessName, // Include second business name in rese
        businessAddress: _businessAddress,
        businessPhone: _businessPhone,
        businessEmail: _businessEmail, // Include business email in reset
        receiptFooter: _receiptFooter,
        themeMode: _themeMode,
        isVatInclusive: _isVatInclusive,
        doubleTapToOpenKeyboard: _doubleTapToOpenKeyboard,

      );
    } catch (e) {
      debugPrint('Error resetting settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}