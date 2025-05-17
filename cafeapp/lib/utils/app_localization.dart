// lib/utils/app_localization.dart

// import 'package:flutter/material.dart';

class AppLocalization {
  static final AppLocalization _instance = AppLocalization._internal();
  factory AppLocalization() => _instance;
  AppLocalization._internal();

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'SIMS RESTO CAFE',
      'dashboard': 'Dashboard',
      'dining': 'Dining',
      'takeout': 'Takeout',
      'delivery': 'Delivery',
      'driveThrough': 'Drive Through',
      'catering': 'Catering',
      'orderList': 'Order List',
      'settings': 'Settings',
      'appearance': 'Appearance',
      'theme': 'Theme',
      'language': 'Language',
      'businessInformation': 'Business Information',
      'printerSettings': 'Printer Settings',
      'taxSettings': 'Tax Settings',
      'tables': 'Tables',
      'products': 'Products',
      'dataAndBackup': 'Data & Backup',
      'advancedSettings': 'Advanced Settings',
      // Common actions
      'save': 'Save',
      'cancel': 'Cancel',
      'add': 'Add',
      'edit': 'Edit',
      'delete': 'Delete',
      'search': 'Search',
      'print': 'Print',
      'back': 'Back',
      'logout': 'Logout',
      'languageChanged': 'Language changed successfully',
      // Add more translations as needed
    },
    'ar': {
      'appTitle': 'مقهى سيمز ريستو',
      'dashboard': 'لوحة التحكم',
      'dining': 'تناول الطعام',
      'takeout': 'طلب خارجي',
      'delivery': 'توصيل',
      'driveThrough': 'السيارة',
      'catering': 'تموين',
      'orderList': 'قائمة الطلبات',
      'settings': 'الإعدادات',
      'appearance': 'المظهر',
      'theme': 'السمة',
      'language': 'اللغة',
      'businessInformation': 'معلومات العمل',
      'printerSettings': 'إعدادات الطابعة',
      'taxSettings': 'إعدادات الضريبة',
      'tables': 'الطاولات',
      'products': 'المنتجات',
      'dataAndBackup': 'البيانات والنسخ الاحتياطي',
      'advancedSettings': 'إعدادات متقدمة',
      // Common actions
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'add': 'إضافة',
      'edit': 'تعديل',
      'delete': 'حذف',
      'search': 'بحث',
      'print': 'طباعة',
      'back': 'رجوع',
      'logout': 'تسجيل الخروج',
      'languageChanged': 'تم تغيير اللغة بنجاح',
     // Add more translations as needed
      'are you sure you want to logout?':'هل أنت متأكد أنك تريد تسجيل الخروج؟',
    },
  };

  String _currentLanguage = 'en';

  void setLanguage(String languageCode) {
    if (_localizedValues.containsKey(languageCode)) {
      _currentLanguage = languageCode;
    }
  }

  String get currentLanguage => _currentLanguage;

  String translate(String key) {
    return _localizedValues[_currentLanguage]?[key] ?? 
           _localizedValues['en']?[key] ?? 
           key;
  }
}

// Extension method for easy translation
extension TranslateString on String {
  String tr() {
    return AppLocalization().translate(this);
  }
}