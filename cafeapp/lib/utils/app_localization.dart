
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
      'Invalid username or password':'اسم المستخدم أو كلمة المرور غير صالحة',

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


      //Dining Table Screen
      'Dining Tables':'طاولات طعام',
      'No tables available. Add tables from the Tables menu.':'لا توجد جداول متاحة. أضف الجداول من قائمة "الجداول".',
      'Table is currently occupied. You can start a new order or view current orders.':'الطاولة مشغولة حاليًا. يمكنك بدء طلب جديد أو عرض الطلبات الحالية.',
      'View Orders':'عرض الطلبات',
      'New Order':"النظام الجديد",
      'Occupied' :'مشغول',
      'Table':'طاولة',
      'Dining - Table':'تناول الطعام - الطاولة',

      //Expense History Screen
      'Error loading expenses':'خطأ في تحميل النفقات',
      'Expense deleted successfully':'تم حذف النفقات بنجاح',
      'Failed to delete expense':'فشل في حذف النفقات',
      'Error deleting expense':'خطأ في حذف النفقات',
      'Delete Expense':'حذف النفقات',
      'Are you sure you want to delete this expense record? This action cannot be undone.':'هل أنت متأكد أنك تريد حذف سجل النفقات هذا؟ لا يمكن التراجع عن هذا الإجراء.',
      'Delete':'يمسح',
      'Expense Details':'تفاصيل النفقات',
      'Date':'تاريخ',
      'Account':'حساب',
      'Cashier':'أمين الصندوق',
      'Total':'المجموع',
      'Expenses':'نفقات',
      'Total Expenses':"إجمالي النفقات",
      'Total Amount':'المبلغ الإجمالي',
      'Search expenses...':"نفقات البحث...",
      'Loading expenses...':'تحميل النفقات...',
      'No expenses found':"لم يتم العثور على أي نفقات",
      'All Expenses':"جميع النفقات",
      'Tap the + button to add a new expense':'اضغط على زر + لإضافة مصروف جديد',
      'Edit':'يحرر',
      'Add Expense':'إضافة نفقات',
      'item':'غرض',
      'Today':'اليوم',
      'This Month':"هذا الشهر",
      'This Week':'هذا الاسبوع',

      //Expense Screen
      'Salesman':'بائع',
      'Cash Account:':'حساب نقدي:',
      'Cash Account':'حساب نقدي',
      'Bank Account':'حساب مصرفي',
      'Shop Expenses':'نفقات التسوق',
      'Office Expenses':'مصاريف المكتب',
      'Food Expenses':"نفقات الطعام",
      'Transport':'ينقل',
      'Utilities':'المرافق العامة',
      'Rent':'إيجار',
      'Salaries':'الرواتب',
      'Kitchen Expenses':'مصاريف المطبخ',
      'Raw Materials':'مواد خام',
      'Maintenance':'صيانة',
      'Equipments':'المعدات',
      'Cleaning Supplies':'مواد التنظيف',
      'Others':'آحرون',
      'Please fill all required fields':'الرجاء ملء جميع الحقول المطلوبة',
      'Please add at least one expense with a valid amount':'الرجاء إضافة مصروف واحد على الأقل بمبلغ صالح',
      'Success':'نجاح',
      'Expense updated successfully!':'تم تحديث النفقات بنجاح!',
      'Expense records stored successfully!':'تم تخزين سجلات النفقات بنجاح!',
      'OK':'نعم',
      'Failed to save expense. Please try again.':'فشل في توفير النفقات. يُرجى المحاولة مرة أخرى.',
      'Error':'خطأ',
      'Cash Payment':'الدفع النقدي',
      'Date:':'تاريخ:',
      'Cashier:':'أمين الصندوق:',
      'Sl.No':'رقم التسلسل',
      'Narration':'السرد',
      'Remarks':'ملاحظات',
      'Amount':'كمية',
      'Net Amount':'المبلغ الصافي',
      'Gross:':'إجمالي:',
      'Total Tax:':'إجمالي الضريبة:',
      'Grand Total:':'المجموع الإجمالي:',
      'Save': 'حفظ',
      'Delete row':'حذف الصف',

      //Modifier Screen 
      'Could not access the selected image':"لم يتمكن من الوصول إلى الصورة المحددة",
      'Error selecting image':'خطأ في اختيار الصورة',
      'Could not access the captured photo':"لم أتمكن من الوصول إلى الصورة الملتقطة",
      'Error taking photo':'خطأ أثناء التقاط الصورة',
      'Delete Item':'حذف العنصر',
      'Are you sure you want to delete':'هل أنت متأكد أنك تريد الحذف',
      "Deleting item...":"حذف العنصر...",
      'Failed to delete item. Please try again.':'فشل حذف العنصر. يُرجى المحاولة مرة أخرى.',
      'This item cannot be deleted because it is used in existing orders.':'لا يمكن حذف هذا العنصر لأنه يُستخدم في الطلبات الموجودة.',
      'Item deleted successfully':'تم حذف العنصر بنجاح',
      'Dismiss':'رفض',
      'Please select a category':'الرجاء تحديد الفئة',
      "Saving item...":"حفظ العنصر...",
      "Failed to add category":"فشل في إضافة الفئة",
      'Failed to process image. Please try a different one.':'فشل معالجة الصورة. يُرجى تجربة صورة أخرى.',
      'Item added successfully':'تمت إضافة العنصر بنجاح',
      'Item updated successfully':'تم تحديث العنصر بنجاح',
      'Failed to save item. Please try again.':'فشل حفظ العنصر. يُرجى المحاولة مرة أخرى.',
      'Image file not found':'لم يتم العثور على ملف الصورة',
      'Error showing image':'خطأ في عرض الصورة',
      'Invalid file path':'مسار الملف غير صالح',
      'Failed to load image':'فشل تحميل الصورة',
      'No image selected':'لم يتم تحديد أي صورة',
      'Products':'منتجات',
      'Category':'فئة',
      'Select a category':'اختر الفئة',
      'No category selected':'لم يتم تحديد الفئة',
      'No items in this category':'لا يوجد عناصر في هذه الفئة',
      'Add New Item':'إضافة عنصر جديد',
      'Edit Item':'تحرير العنصر',
      'Name':'اسم',
      'Please enter a name':'الرجاء إدخال الاسم',
      'Price':'سعر',
      'Please enter a price':'الرجاء إدخال السعر',
      'Please enter a valid number':'الرجاء إدخال رقم صالح',
      'New Category':'فئة جديدة',
      'Please enter a category name':'الرجاء إدخال اسم الفئة',
      'Add new category':'إضافة فئة جديدة',
      'Item Image (Optional)':'صورة العنصر (اختياري)',
      'Remove Image':'إزالة الصورة',
      'Gallery':'معرض',
      'Camera':'آلة تصوير',
      '(Images are optional)':'(الصور اختيارية)',
      'Add Item':'إضافة عنصر',
      'Update Item':'تحديث العنصر',

      //Splash Screen
      'Please wait...':'انتظر من فضلك...',

      //Search Person Screen
      'People':'الناس',
      'Search by name':'البحث حسب الاسم',
      'No results found':'لم يتم العثور على نتائج',
      'No people added yet':'لم تتم إضافة أي أشخاص بعد',
      'Visited on':'تمت الزيارة في',

      // Order Confirmation Screen
      'Order Confirmation': 'تأكيد الطلب',
      'Order Summary': 'ملخص الطلب',
      'Date: %s at %s': 'التاريخ: %s في %s',
      'Service Type': 'نوع الخدمة',
      'at': 'في',
      'Customer': 'العميل',
      'Items': 'العناصر',
      'Item': 'الصنف',
      'Qty': 'الكمية',
      'Subtotal': 'المجموع الفرعي',
      'Tax': 'الضريبة',
      'TOTAL': 'المجموع الكلي',
      'Process Order': 'معالجة الطلب',
      'Processing...': 'جاري المعالجة...',
      'Cart is empty': 'سلة التسوق فارغة',
      'Error processing order': 'خطأ في معالجة الطلب',


      // Order Details Screen
      'Order Details': 'تفاصيل الطلب',
      'Order #': 'طلب #',
      'Bill Number': 'رقم الفاتورة',
      'Date & Time': 'التاريخ والوقت',
      'Items (Double-click to Edit)': 'العناصر (انقر مرتين للتعديل)',
      'Subtotal:': 'المجموع الفرعي:',
      'Tax:': 'الضريبة:',
      'Discount:': 'الخصم:',
      'TOTAL:': 'المجموع الكلي:',
      'Payment': 'الدفع',
      'Tender Payment': 'دفع الفاتورة',
      'Order not found': 'الطلب غير موجود',
      'Go Back': 'العودة',
      'Edit Order Items': 'تعديل عناصر الطلب',
      'Search Items': 'بحث العناصر',
      'Categories': 'الفئات',
      'Quantity:': 'الكمية:',
      'Order updated successfully': 'تم تحديث الطلب بنجاح',
      'Failed to load order details': 'فشل تحميل تفاصيل الطلب',
      'Error updating order': 'خطأ في تحديث الطلب',
      'Add Menu Item': 'إضافة عنصر من القائمة',
      'Try Again': 'حاول مرة أخرى',
      'Failed to print kitchen receipt': 'فشل طباعة إيصال المطبخ',
      'Error printing kitchen receipt': 'خطأ في طباعة إيصال المطبخ',
      'No matching items found':'لم يتم العثور على عناصر مطابقة',
      'Dining': 'تناول الطعام',
      'Takeout': 'طلب خارجي',
      'Delivery': 'توصيل',
      'Drive': 'السيارة',
      'Catering': 'تموين',

      // Order List Screen
     'All Orders': 'جميع الطلبات',
     'Orders': 'الطلبات',
     'Search order number...': 'ابحث برقم الطلب...',
     'This Year': 'هذه السنة',
     'All Time': 'كل الفترات',
     'Pending': 'قيد الانتظار',
     'Error:': 'خطأ:',
     'Retry': 'إعادة المحاولة',
     'No orders found with that number': 'لا توجد طلبات بهذا الرقم',
     'No pending orders found': 'لا توجد طلبات قيد الانتظار',
     'No orders found': 'لا توجد طلبات',
     'Orders will appear here once they are placed': 'ستظهر الطلبات هنا بمجرد تقديمها',
     'pending': 'قيد الانتظار',
     'completed': 'مكتمل',
     'cancelled': 'ملغى',
     'Time': 'الوقت',
 

      // Person Form Screen
     'Person Details': 'تفاصيل الشخص',
     'Phone Number': 'رقم الهاتف',
     'Please enter a phone number': 'الرجاء إدخال رقم الهاتف',
     'Place': 'المكان',
     'Please enter a place': 'الرجاء إدخال المكان',
     'Person added successfully': 'تمت إضافة الشخص بنجاح',
     'Failed to add person': 'فشل إضافة الشخص',

     // Printer Settings Screen
  'Printer Settings': 'إعدادات الطابعة',
  'Thermal Printer Configuration': 'تهيئة الطابعة الحرارية',
  'Printer IP Address': 'عنوان IP للطابعة',
  'Enter the IP address of your network printer': 'أدخل عنوان IP لطابعة الشبكة',
  'e.g., 192.168.1.100': 'مثال: 192.168.1.100',
  'Printer Port': 'منفذ الطابعة',
  'Default port for most thermal printers is 9100': 'المنفذ الافتراضي لمعظم الطابعات الحرارية هو 9100',
  'e.g., 9100': 'مثال: 9100',
  'Save Settings': 'حفظ الإعدادات',
  'Test Connection': 'اختبار الاتصال',
  'Testing Connection...': 'جاري اختبار الاتصال...',
  'Printer Discovery': 'اكتشاف الطابعة',
  'Automatically find network printers on your local network': 'اكتشف الطابعات على شبكتك المحلية تلقائياً',
  'Discover Printers': 'اكتشاف الطابعات',
  'Discovering...': 'جاري الاكتشاف...',
  'Printer Setup Help': 'مساعدة إعداد الطابعة',
  '1. Make sure your printer is connected to the same WiFi network as this tablet': '1. تأكد من أن الطابعة متصلة بنفس شبكة الواي فاي مثل هذا الجهاز',
  '2. Enter the printer\'s IP address (check your printer settings or router)': '2. أدخل عنوان IP للطابعة (تحقق من إعدادات الطابعة أو الراوتر)',
  '3. Port 9100 is the standard port for most network printers': '3. المنفذ 9100 هو المنفذ القياسي لمعظم طابعات الشبكة',
  '4. Click "Test Connection" to verify the printer is working': '4. انقر على "اختبار الاتصال" للتحقق من عمل الطابعة',
  'Discovered Printers': 'الطابعات المكتشفة',
  'Select': 'تحديد',
  'Please enter a valid IP address': 'الرجاء إدخال عنوان IP صحيح',
  'Please enter a valid port number (1-65535)': 'الرجاء إدخال رقم منفذ صحيح (1-65535)',
  'Printer settings saved': 'تم حفظ إعدادات الطابعة',
  'Error saving printer settings': 'خطأ في حفظ إعدادات الطابعة',
  'Successfully connected to printer': 'تم الاتصال بالطابعة بنجاح',
  'Failed to connect to printer. Please check IP address and port.': 'فشل الاتصال بالطابعة. الرجاء التحقق من عنوان IP والمنفذ.',
  'Error testing printer connection': 'خطأ في اختبار اتصال الطابعة',
  'Not connected to Wi-Fi': 'غير متصل بشبكة الواي فاي',
  'No printers discovered': 'لم يتم اكتشاف أي طابعات',
  'Error discovering printers': 'خطأ في اكتشاف الطابعات',
  'Error loading printer settings' :'خطأ في تحميل إعدادات الطابعة',


    // Report Screen
  'Reports': 'التقارير',
  'Daily Report': 'تقرير يومي',
  'Monthly Report': 'تقرير شهري',
  'Custom Report': 'تقرير مخصص',
  'Selected Date:': 'التاريخ المحدد:',
  'Month': 'الشهر',
  'From:': 'من:',
  'To:': 'إلى:',
  'Save as PDF': 'حفظ كملف PDF',
  'No data available': 'لا توجد بيانات متاحة',
  'Total Orders': 'إجمالي الطلبات',
  'Total Revenue': 'إجمالي الإيرادات',
  'Items Sold': 'العناصر المباعة',
  'Cash and Bank Sales': 'مبيعات نقدية وبنكية',
  'Payment Method': 'طريقة الدفع',
  'Revenue': 'الإيرادات',
  'Total Sales': 'إجمالي المبيعات',
  'Total Cash Sales': 'إجمالي المبيعات النقدية',
  'Total Bank Sales': 'إجمالي المبيعات البنكية',
  'Revenue Breakdown': 'تفصيل الإيرادات',
  'Discounts': 'الخصومات',
  'Top Selling Items': 'أكثر العناصر مبيعاً',
  'No items data available': 'لا توجد بيانات للعناصر', 
  'sold': 'مباع',
  'orders': 'طلبات',
  'Error loading report': 'خطأ في تحميل التقرير',
  'Report saved as PDF': 'تم حفظ التقرير كملف PDF',
  'Failed to save report as PDF': 'فشل في حفظ التقرير كملف PDF',
  'No report data available to save': 'لا توجد بيانات تقرير متاحة للحفظ',
  'No sales data available':"لا توجد بيانات مبيعات متاحة",
  'No sales data found':'لم يتم العثور على بيانات المبيعات',
  'Payment data not available':'بيانات الدفع غير متوفرة',




      



































      




       






















     








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