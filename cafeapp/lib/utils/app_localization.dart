// lib/utils/app_localization.dart

// import 'package:flutter/material.dart';

// import 'package:cafeapp/main.dart';

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
       // Dashboard
      'appTitle': 'مقهى سيمز ريستو',
      'dashboard': 'لوحة التحكم',
      'dining': 'تناول الطعام',
      'takeout': 'طلب خارجي',
      'delivery': 'توصيل',
      'driveThrough': 'السيارة',
      'catering': 'تموين',
      'orderList': 'قائمة الطلبات',
        
      // Login screen
      'Login': 'تسجيل الدخول',
      'Username': 'اسم المستخدم',
      'Password': 'كلمة المرور',
      'Please enter your username': 'الرجاء إدخال اسم المستخدم الخاص بك',
      'Please enter your password': 'الرجاء إدخال كلمة المرور',
      'Login Failed. Please check your credentials.': 'فشل تسجيل الدخول. يرجى التحقق من بيانات الاعتماد الخاصة بك.',
       
       // Menu screen
      'Failed to load menu. Please try again.':'فشل تحميل القائمة. يُرجى المحاولة مرة أخرى.',
      'Please select an item first':'الرجاء تحديد العنصر أولاً',
      'Kitchen note added':'تمت إضافة ملاحظة المطبخ',
      'Order List':'قائمة الطلبات',
      'Discount':'تخفيض',
      'Kitchen note':'ملاحظة المطبخ',
      'Clear':'واضح',
      'Remove':'يزيل',
      'Clear Order':'أمر واضح',
      'Are you sure you want to clear all items from this order?':'هل أنت متأكد أنك تريد مسح كافة العناصر من هذا الطلب؟',
      'Cancel': 'إلغاء',
      'Order cleared successfully':'تم تنفيذ الطلب بنجاح',
      'Tables': 'الطاولات',
      'Order is already empty':'الطلب فارغ بالفعل',
      'Please select a menu item first':'الرجاء تحديد عنصر القائمة أولاً',
      'Search Menu...':'قائمة البحث...',
      'No items found in this category':'لم يتم العثور على أي عناصر في هذه الفئة',
      'is out of stock but has been added to your order':'غير متوفر في المخزون ولكن تمت إضافته إلى طلبك',
      'Out of stock': 'غير متوفر',
      'Available': 'متاح',
      'Order Items':'عناصر الطلب',
      'Sub total': 'المجموع الفرعي',
      'Tax amount': 'ضريبة',
      'Grand total': 'المجموع',
      'Surcharge':'تكلفة إضافية',
      'Delivery charge':'رسوم التوصيل',
      'Item discount':'خصم السلعة',
      'Bill discount':'خصم الفاتورة',
      'Date visited':'تاريخ الزيارة',
      'Count visited':'عدد الزيارات',
      'Point':'نقطة',
      'Cash':'نقدي',
      'Credit':'ائتمان',
      'Order':'طلب',
      'Tender':'ليّن',
      'Your cart is empty': 'عربة التسوق فارغة',
      'Please add items to your order':'يرجى إضافة العناصر إلى طلبك',












      'menu': 'القائمة',
      'search': 'بحث',
      'categories': 'الفئات',
      'addToCart': 'أضف إلى السلة',
      'itemAdded': 'تمت إضافة العنصر إلى السلة',
      
      
      'cart': 'عربة التسوق',
      'clearCart': 'إفراغ السلة',
      'placeOrder': 'تقديم الطلب',
      'orderTotal': 'إجمالي الطلب',
      
    
      'emptyCart': 'عربة التسوق فارغة',





      'settings': 'الإعدادات',
      'appearance': 'المظهر',
      'theme': 'السمة',
      'language': 'اللغة',
      'businessInformation': 'معلومات العمل',
      'printerSettings': 'إعدادات الطابعة',
      'taxSettings': 'إعدادات الضريبة',
      'products': 'المنتجات',
      'dataAndBackup': 'البيانات والنسخ الاحتياطي',
      'advancedSettings': 'إعدادات متقدمة',

      // Common actions
      'save': 'حفظ',
      'add': 'إضافة',
      'edit': 'تعديل',
      'delete': 'حذف',
    
      'print': 'طباعة',
      'back': 'رجوع',
      'Logout': 'تسجيل الخروج',
      'languageChanged': 'تم تغيير اللغة بنجاح',
     // Add more translations as needed
      'Are you sure you want to logout?':'هل أنت متأكد أنك تريد تسجيل الخروج؟',
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