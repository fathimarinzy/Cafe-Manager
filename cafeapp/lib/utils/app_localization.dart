
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
      'ORDER LIST':'قائمة الطلبات',
      'Table Service':'خدمة الطاولة',
      "Local Delivery":'توصيل محلي',
      "Web Orders":'طلبات الويب',
      'Counter Pickup':'استلام العداد',
      "Quick Service":'خدمة سريعة',
      "Large Events":'خدمة سريعة',
      'Drive Thru':'خدمة السيارات',
      'Online':'عبر الإنترنت',
      'Dining':'تناول الطعام',
      'Delivery':'توصيل',
      'Takeout':'طلب خارجي',
      'Drive Through':'خدمة السيارات',
      'Catering':'تموين',
      'Online Order':'طلب عبر الإنترنت',
      'Report': 'تقرير',
      'Do you want to see the report before logging out?': 'هل تريد رؤية التقرير قبل تسجيل الخروج؟',
      'Location': 'الموقع',
      'Contact': 'اتصال',
      'Manage dine-in orders': 'إدارة طلبات تناول الطعام في المطعم',
      'Track delivery orders': 'تتبع طلبات التوصيل',
      'Quick drive-through service': 'خدمة سريعة من خلال السيارة',
      'Large event orders': 'طلبات الأحداث الكبيرة',
      'Pickup orders ready': 'طلبات الاستلام جاهزة',
      'View all orders': 'عرض جميع الطلبات',
      'Toggle UI Style': 'تبديل نمط واجهة المستخدم',
      'SIMS CAFE': 'سيمز كافيه',
      'Light Mode': 'الوضع الفاتح',
      'Dark Mode': 'الوضع الداكن',
      'Powered by': 'مشغل بواسطة',
      'appTitle': 'مقهى سيمز ريستو',
      'dashboard': 'لوحة التحكم',
      'dining': 'تناول الطعام',
      'takeout': 'طلب خارجي',
      'delivery': 'توصيل',
      'driveThrough': 'خدمة السيارات',
      'catering': 'تموين',
      'orderList': 'قائمة الطلبات',
      'Demo expired. Please contact support to continue using this feature.': 'انتهت صلاحية العرض التجريبي. يرجى الاتصال بالدعم لمواصلة استخدام هذه الميزة.',
      'License expired. Please contact support to renew your license.': 'انتهت صلاحية الترخيص. يرجى الاتصال بالدعم لتجديد ترخيصك.',
      'Feature not available.': 'الميزة غير متاحة.',
      'Your 30-day demo period has expired.\\nTo continue using all features, upgrade your plan.': 'انتهت فترة العرض التجريبي لمدة 30 يومًا.\\nلمواصلة استخدام جميع الميزات، قم بترقية خطتك.',
      'Your 1-year license has expired.\\nTo continue using all features, please contact support for license renewal.': 'انتهت صلاحية ترخيصك لمدة عام واحد.\\nلمواصلة استخدام جميع الميزات، يرجى الاتصال بالدعم لتجديد الترخيص.',
      'Contact Support:': 'اتصل بالدعم:',
      'Renew License': 'تجديد الترخيص',
      'Later': 'لاحقاً',
      'Upgrade Now': 'الترقية الآن',
      'settings': 'الإعدادات',
      'Device Setup':'إعداد الجهاز',
      'Choose how to set up this device':'اختر كيفية إعداد هذا الجهاز',
      'Set as Main Device':'تعيين كجهاز رئيسي',
      'Link to Main Device':'ربط إلى الجهاز الرئيسي',
       "Main Device Actions": "إجراءات الجهاز الرئيسي",
       'Generate Code for Device':'توليد رمز لجهاز',
       'Device Code':'رمز الجهاز',
       
      // Login screen
      'Login': 'تسجيل الدخول',
      'Username': 'اسم المستخدم',
      'Password': 'كلمة المرور',
      'Please enter your username': 'الرجاء إدخال اسم المستخدم الخاص بك',
      'Please enter your password': 'الرجاء إدخال كلمة المرور',
      'Login Failed. Please check your credentials.': 'فشل تسجيل الدخول. يرجى التحقق من بيانات الاعتماد الخاصة بك.',
      'Invalid username or password':'اسم المستخدم أو كلمة المرور غير صالحة',

       // Menu screen
      'Select Menu Layout':'اختر تخطيط القائمة',
      'Menu Layout': 'تخطيط القائمة',
      'Menu layout saved': 'تم حفظ تخطيط القائمة',
      'Same as above': 'نفس ما ورد أعلاه',
      'Mobile Performance': 'أداء الجوال',
      'Ultimate (Dark)': 'المظلم الفائق',
      'Classic Grid': 'الشبكة الكلاسيكية',
      'Sidebar': 'الشريط الجانبي',
      'Modern': 'حديث',
      'Card Style': 'نمط البطاقة',
      '3x3 Layout': 'تخطيط 3x3',
      '4x4 Layout': 'تخطيط 4x4',
      '4x5 Layout': 'تخطيط 4x5',
      '4x6 Layout': 'تخطيط 4x6',
      '4x7 Layout': 'تخطيط 4x7',
      '5x8 Layout': 'تخطيط 5x8',
      'Search customer name or phone...': 'ابحث عن اسم العميل أو الهاتف...',
      'No customers found': 'لم يتم العثور على عملاء',
      'Select delivery boy': 'اختر عامل التوصيل',
      'Charge': 'الرسوم',
      'Invalid': 'غير صالح',
      'Start Order': 'ابدأ الطلب',
      'Delivery Information': 'معلومات التوصيل',
      'Enter guest count': 'أدخل عدد الضيوف',
      'Enter token number': 'أدخل رقم الرمز',
      'Customer (Optional)': 'العميل (اختياري)',
      'Select Customer': 'اختر العميل',
      'Select': 'اختار',
      'Search by name': 'بحث بالاسم',
      'No results found': 'لم يتم العثور على نتائج',
      'No customers added yet': 'لم يتم إضافة عملاء بعد',
      'Credit:': 'رصيد:',
      'Add Customer': 'أضف عميل',
      'Add Delivery Boy': 'إضافة عامل توصيل',
      'Edit Delivery Boy': 'تعديل عامل توصيل',
      'Name': 'الاسم',
      'Please enter name': 'الرجاء إدخال الاسم',
      'Phone': 'هاتف',
      'Please enter phone': 'الرجاء إدخال الهاتف',
      'Delivery Boy added successfully': 'تم إضافة عامل التوصيل بنجاح',
      'Delivery Boy updated successfully': 'تم تحديث عامل التوصيل بنجاح',
      'Failed to save: ': 'فشل الحفظ: ',
      'Save': 'حفظ',
      'Delete Delivery Boy': 'حذف عامل التوصيل',
      'Are you sure you want to delete this delivery boy?': 'هل أنت متأكد أنك تريد حذف عامل التوصيل هذا؟',
      'Delete': 'حذف',
      'Delivery Boy Management': 'إدارة عمال التوصيل',
      'No delivery boys found': 'لم يتم العثور على عمال توصيل',
      'Delivery Setup': 'إعداد التوصيل',
      'Customer': 'العميل',
      'Please enter address': 'الرجاء إدخال العنوان',
      'Delivery Boy': 'عامل التوصيل',
      'Drive Through Management': 'إدارة خدمة السيارات',
      'New Vehicle Entry': 'دخول مركبة جديدة',
      'Enter vehicle details to add to queue': 'أدخل تفاصيل المركبة للإضافة إلى قائمة الانتظار',
      'Vehicle Number': 'رقم المركبة',
      'e.g. KL-01-AB-1234': 'مثال: KL-01-AB-1234',
      'Vehicle Type': 'نوع المركبة',
      'Add to Queue': 'إضافة إلى قائمة الانتظار',
      'Active Queue': 'قائمة الانتظار النشطة',
      'No vehicles in queue': 'لا توجد مركبات في قائمة الانتظار',
      'Length: ': 'الطول: ',
      'Car': 'سيارة',
      'Bike': 'دراجة',
      'Truck': 'شاحنة',
      'Other': 'أخرى',
      'Save Quote': 'حفظ العرض',
      'Save Quotation?': 'هل تريد حفظ العرض؟',
      'Do you want to save the current items as a quotation?': 'هل تريد حفظ العنصر الحالي كعرض؟',
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
      'Welcome Back,': 'أهلاً بك،',
      'Tap to change logo': 'اضغط لتغيير الشعار',
      'Orders Today': 'طلبات اليوم',
      'Pending Orders': 'الطلبات المعلقة',
      'Active Tables': 'الطاولات النشطة',
      'Services': 'الخدمات',
      'Actions': 'إجراءات',
      'View All': 'عرض الكل',
      'Connected': 'متصل',
      'Mobile Performance Mode': 'وضع الأداء للجوال',
      'Search...': 'بحث...',
      'Email': 'البريد الإلكتروني',
      'Enter Order #, Token #, or Customer Name': 'أدخل رقم الطلب, رقم الرمز أو اسم العميل',
      'Search Orders': 'بحث الطلبات',
      'Recent Activity': 'النشاط الأخير',
      'No orders yet': 'لا توجد طلبات بعد',

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
       'Kitchen Printer Connected': 'طابعة المطبخ متصلة',
      'Kitchen Printer Disconnected': 'طابعة المطبخ غير متصلة',
      'Kitchen printer connected successfully': 'تم توصيل طابعة المطبخ بنجاح',
      'Kitchen printer disabled': 'تم تعطيل طابعة المطبخ',
      'Failed to connect to kitchen printer. Check settings.': 'فشل الاتصال بطابعة المطبخ. تحقق من الإعدادات.',
      'Error with kitchen printer connection': 'خطأ في اتصال طابعة المطبخ',



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
      'Select Card Type': 'اختر نوع البطاقة',


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
     
      'Delete row':'حذف الصف',

      //Modifier Screen 
      'Per Plate Pricing':'التسعير لكل طبق',
      'Price is per person based on event guest count':'السعر لكل شخص بناءً على عدد ضيوف الحدث',
      'Tax Exempt':'معفى من الضرائب',
       'Enable this to exclude tax for this item': 'قم بتمكين هذا لاستبعاد الضريبة عن هذا العنصر',
       'Import Menu': 'قائمة الاستيراد',
       'Export Menu': 'قائمة التصدير',
       'Import from Excel': 'استيراد من Excel',
       'Choose category handling:': 'اختر معالجة الفئة:',
       'Use category from Excel file': 'استخدام الفئة من ملف Excel',
       'Each item will use its own category from the file': 'سيستخدم كل عنصر فئته الخاصة من الملف',
       'Assign all items to one category': 'تعيين جميع العناصر إلى فئة واحدة',
       'All imported items will use the selected category': 'ستستخدم جميع العناصر المستوردة الفئة المحددة',
       'Select Category': 'اختر الفئة',
       'Download Template': 'تنزيل القالب',
       'Excel Format:': 'تنسيق Excel:',
      '• Columns: Name | Price | Category | Available | Image File':'• الأعمدة: الاسم | السعر | الفئة | متاح | ملف الصورة',
       '• Available values: Yes/No or True/False':'• القيم المتاحة: نعم/لا أو صحيح/خطأ',
       '• images/ folder must be in same location as Excel file. So the images loaded automatically':'• يجب أن يكون مجلد images/ في نفس موقع ملف Excel. لذا يتم تحميل الصور تلقائيًا',
       '• Image files must match names in "Image File" column':'• يجب أن تتطابق أسماء ملفات الصور مع الأسماء في عمود "ملف الصورة"',
       'Select File':'اختر ملف',
       "Reading Excel file...":"جارٍ قراءة ملف Excel...",
       'Import cancelled or file not selected':'تم إلغاء الاستيراد أو لم يتم تحديد ملف',

       'No valid items found in Excel file':'لم يتم العثور على عناصر صالحة في ملف Excel',

       'Confirm Import':'تأكيد الاستيراد',
       'items with images':'عناصر مع صور',
       'Found':'تم العثور على',
       'items to import:':'عناصر للاستيراد:',
       'items':'عناصر',
       'This will add all items to menu. Existing items not affected.':'سيؤدي ذلك إلى إضافة جميع العناصر إلى القائمة. العناصر الموجودة غير متأثرة.',
       'Import': 'يستورد',
       "Importing items...":"جارٍ استيراد العناصر...",
       "Creating template...":"جارٍ إنشاء القالب...",
       'Template saved successfully!':'تم حفظ القالب بنجاح!',
       'Template download cancelled':'تم إلغاء تنزيل القالب',
       'Edit Category':'تحرير الفئة',
       'Category Name':'اسم الفئة',
       'Category name cannot be empty':'لا يمكن أن يكون اسم الفئة فارغًا',
       "Updating category...":"جارٍ تحديث الفئة...",
       'Category updated successfully':'تم تحديث الفئة بنجاح',
       'Failed to update category. Name may already exist.':'فشل في تحديث الفئة. قد يكون الاسم موجودًا بالفعل.',
       'Delete Category':'حذف الفئة',
       'Are you sure you want to delete category':'هل أنت متأكد أنك تريد حذف الفئة',
       'This will delete':'سيؤدي ذلك إلى حذف',
       'items in this category':'العناصر في هذه الفئة',
       "Deleting category...":"جارٍ حذف الفئة...",
       'Category deleted successfully':'تم حذف الفئة بنجاح',
       'Failed to delete category. Please try again.':'فشل في حذف الفئة. يُرجى المحاولة مرة أخرى.',
       'Could not access the selected image':"لم يتمكن من الوصول إلى الصورة المحددة",
       'Error selecting image':'خطأ في اختيار الصورة',
       'Could not access the captured photo':"لم أتمكن من الوصول إلى الصورة الملتقطة",
       'Error taking photo':'خطأ أثناء التقاط الصورة',
       'No items to export. Please add items first.':'لا توجد عناصر للتصدير. يرجى إضافة عناصر أولاً.',

       'Export Menu Items':'تصدير عناصر القائمة',
       'Export Statistics':'إحصائيات التصدير',
       
       'Exporting items...':'جارٍ تصدير العناصر...',
       'Items exported successfully!':'تم تصدير العناصر بنجاح!',
       'Failed to export items. Please try again.':'فشل في تصدير العناصر. يُرجى المحاولة مرة أخرى.',
      'Total Items:':'إجمالي العناصر:',
      'Categories:':'الفئات:',
      'What will be exported:':'ما سيتم تصديره:',
      '📄 menu_items.xlsx - Excel file with all menu items':'📄 menu_items.xlsx - ملف Excel يحتوي على جميع عناصر القائمة',
      '📁 images/ - Folder with all item images':'📁 images/ - مجلد يحتوي على جميع صور العناصر',
      '📋 README sheet - Import instructions':'📋 ورقة README - تعليمات الاستيراد',
      '📊 Summary sheet - Statistics':'📊 ورقة الملخص - الإحصائيات',
      'Export':'تصدير',
      "Exporting menu items ...":"جارٍ تصدير عناصر القائمة ...",
      'This may take a moment for large menus':'قد يستغرق هذا بعض الوقت للقوائم الكبيرة',
      'Export cancelled':'تم إلغاء التصدير',
      'Export Successful!':'تم التصدير بنجاح!',
      'Export Summary:':'ملخص التصدير:',
      'Items Exported:':'العناصر المصدرة:',
      'itemsExported':'العناصر المصدرة',
      'imagesExported':'صور المصدرة',
      'Images Exported:':'صور المصدرة:',
      'Images Failed:':'فشل الصور:',
      'Export Location:':'موقع التصدير:',
      'Folder Contents:':'محتويات المجلد:',
      '📄 menu_items.xlsx':'📄 menu_items.xlsx',
      'Keep these files together for reimport':'احتفظ بهذه الملفات معًا لإعادة الاستيراد',
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
      'No people added yet':'لم تتم إضافة أي أشخاص بعد',
      'Visited on':'تمت الزيارة في',

      // Order Confirmation Screen
      'Order Confirmation': 'تأكيد الطلب',
      'Order Summary': 'ملخص الطلب',
      'Date: %s at %s': 'التاريخ: %s في %s',
      'Service Type': 'نوع الخدمة',
      'at': 'في',
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
      'Event Details': 'تفاصيل الحدث',
      'Event Type': 'نوع الحدث',
      'Guests': 'الزائرين',
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
      'Reprint KOT': 'إعادة طباعة KOT',
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
    


      // Order List Screen
      'Search':'بحث',
      "quote": "العرض",
     'Advanced': 'متقدم',
     'Token:': 'رمز:',
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
     'Network (WiFi/Ethernet)': 'الشبكة (واي فاي/إيثرنت)',
      'System Printer (USB/Driver)': 'طابعة النظام (يو اس بي/سائق)',
      'Configuration': 'التكوين',
      'KOT Status': 'حالة المطبخ',
      'Network:': 'الشبكة:',
      'USB:': 'يو اس بي:',
      'Select Printer': 'اختر الطابعة',
      'Refresh Printers': 'تحديث الطابعات',
      'Choose a printer': 'اختر طابعة',
      'Scan Printers': 'مسح الطابعات',
      'Save Configuration': 'حفظ التكوين',
      'Connection Type': 'نوع الاتصال',
      'Connection Status': 'حالة الاتصال',
      'Enable KOT Printer': 'تمكين طابعة المطبخ',
      'Print kitchen orders to separate printer': 'طباعة طلبات المطبخ على طابعة منفصلة',
      'Receipt printer settings saved': 'تم حفظ إعدادات طابعة الإيصالات',
      'KOT printer settings saved': 'تم حفظ إعدادات طابعة المطبخ',
      'Error saving receipt printer settings': 'خطأ في حفظ إعدادات طابعة الإيصالات',
      'Error saving KOT printer settings': 'خطأ في حفظ إعدادات طابعة المطبخ',
      'Successfully connected to receipt printer': 'تم الاتصال بطابعة الإيصالات بنجاح',
      'Successfully connected to KOT printer': 'تم الاتصال بطابعة المطبخ بنجاح',
      'Failed to connect to receipt printer. Please check IP address and port.': 'فشل الاتصال بطابعة الإيصالات. يرجى التحقق من عنوان IP والمنفذ.',
      'Failed to connect to KOT printer. Please check IP address and port.': 'فشل الاتصال بطابعة المطبخ. يرجى التحقق من عنوان IP والمنفذ.',
      'Error testing receipt printer connection': 'خطأ في اختبار اتصال طابعة الإيصالات',
      'Error testing KOT printer connection': 'خطأ في اختبار اتصال طابعة المطبخ',
      'Please enter a valid IP address for Receipt Printer': 'يرجى إدخال عنوان IP صحيح لطابعة الإيصالات',
      'Please enter a valid IP address for KOT Printer': 'يرجى إدخال عنوان IP صحيح لطابعة المطبخ',
      'Please enter a valid port number (1-65535) for Receipt Printer': 'يرجى إدخال رقم منفذ صحيح (1-65535) لطابعة الإيصالات',
      'Please enter a valid port number (1-65535) for KOT Printer': 'يرجى إدخال رقم منفذ صحيح (1-65535) لطابعة المطبخ',
      'Receipt Printer': 'طابعة الإيصالات',
      'KOT Printer': 'طابعة المطبخ',
      'KOT': 'المطبخ',
      'Receipt': 'إيصال',
      'Receipt Printer Configuration': 'تكوين طابعة الإيصالات',
      'Configure your receipt printer': 'تكوين طابعة الإيصالات الخاصة بك',
      'KOT Printer Configuration': 'تكوين طابعة المطبخ',
      'Configure your KOT printer': 'تكوين طابعة المطبخ الخاصة بك',
      'Kitchen Order Ticket printer': 'طابعة تذاكر طلبات المطبخ',
      'Configure your Kitchen Order Ticket printer': 'تكوين طابعة تذاكر طلبات المطبخ',
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
    'Automatically find network printers on your local network.': 'اكتشف الطابعات على شبكتك المحلية تلقائياً',
    'Discover Printers': 'اكتشاف الطابعات',
    'Discovering...': 'جاري الاكتشاف...',
    'Printer Setup Help': 'مساعدة إعداد الطابعة',
    '1. Make sure your printers are connected to the same WiFi network as this tablet': '1. تأكد من أن الطابعات متصلة بنفس شبكة الواي فاي مثل هذا الجهاز',
    '2. Enter the printer\'s IP address (check your printer settings or router)': '2. أدخل عنوان IP للطابعة (تحقق من إعدادات الطابعة أو الراوتر)',
    '3. Port 9100 is the standard port for most network printers': '3. المنفذ 9100 هو المنفذ القياسي لمعظم طابعات الشبكة',
    '4. Click "Test Connection" to verify the printer is working': '4. انقر على "اختبار الاتصال" للتحقق من عمل الطابعة',
    'No printers found': 'لم يتم العثور على طابعات',
    'Error discovering printers': 'خطأ في اكتشاف الطابعات',
    'Printer IP is required': 'عنوان IP للطابعة مطلوب',
    'Printer Port is required': 'منفذ الطابعة مطلوب',
    'Invalid IP address format': 'تنسيق عنوان IP غير صالح',
    'Invalid port number format': 'تنسيق رقم المنفذ غير صالح',
    'Invalid port number': 'رقم المنفذ غير صالح',
    'Printer settings saved successfully': 'تم حفظ إعدادات الطابعة بنجاح',
    'Failed to save printer settings': 'فشل في حفظ إعدادات الطابعة',
    'Successfully connected to printer': 'تم الاتصال بالطابعة بنجاح',
    'Failed to connect to printer': 'فشل في الاتصال بالطابعة',
    'Error connecting to printer': 'خطأ في الاتصال بالطابعة',
    'Not connected to Wi-Fi': 'غير متصل بشبكة الواي فاي',
    'No printers discovered': 'لم يتم اكتشاف أي طابعات',
    'Discovered Printers': 'الطابعات المكتشفة',
    
    'Please enter a valid IP address': 'الرجاء إدخال عنوان IP صحيح',
    'Please enter a valid port number (1-65535)': 'الرجاء إدخال رقم منفذ صحيح (1-65535)',
    'Printer settings saved': 'تم حفظ إعدادات الطابعة',
    'Error saving printer settings': 'خطأ في حفظ إعدادات الطابعة',
    'Failed to connect to printer. Please check IP address and port.': 'فشل الاتصال بالطابعة. الرجاء التحقق من عنوان IP والمنفذ.',
    'Error testing printer connection': 'خطأ في اختبار اتصال الطابعة',
    'Error loading printer settings' :'خطأ في تحميل إعدادات الطابعة',
    'Printer Connected': 'الطابعة متصلة',
    'Printer Disconnected': 'الطابعة غير متصلة',
    'Printer connection disabled': 'تم تعطيل اتصال الطابعة',
    'Printer connection is disabled': 'اتصال الطابعة معطل',
    'Printer Disabled': 'الطابعة معطلة',
    'KOT Printer Disabled': 'طابعة المطبخ معطلة',
    'KOT printer is disabled': 'طابعة المطبخ معطلة',
    'KOT printer disabled': 'تم تعطيل طابعة المطبخ',
    'KOT Printer Not Available': 'طابعة المطبخ غير متوفرة',
    'Could not print kitchen receipt to KOT printer. Would you like to save it as a PDF?': 'تعذر طباعة إيصال المطبخ على طابعة المطبخ. هل تريد حفظه كملف PDF؟',
    'Kitchen receipt skipped (KOT printer disabled)': 'تم تخطي إيصال المطبخ (طابعة المطبخ معطلة)',
    'Kitchen receipt skipped (printer disabled)': 'تم تخطي إيصال المطبخ (الطابعة معطلة)',
    'Would you like to save kitchen receipt as PDF?': 'هل تريد حفظ إيصال المطبخ كملف PDF؟',
    'KOT printer connection is disabled': 'اتصال طابعة المطبخ معطل',
    '5. You can use the same printer for both purposes with different IP addresses or disable KOT printing': '5. يمكنك استخدام نفس الطابعة لكلا الغرضين مع عناوين IP مختلفة أو تعطيل طباعة KOT.',
    'Make sure printers are connected to the same network': 'تأكد من أن الطابعات متصلة بنفس الشبكة',
    'Select a printer to configure:': 'حدد طابعة لتكوينها:',
    'Network Printer': 'طابعة الشبكة',
    'Set as Receipt Printer': 'تعيين كطابعة إيصالات',
    'Set as KOT Printer': 'تعيين كطابعة KOT',
    'Receipt printer configured with {ip}': 'تم تكوين طابعة الإيصالات مع {ip}',
    'KOT printer configured with {ip}': 'تم تكوين طابعة KOT مع {ip}',
    'Close': 'إغلاق',
    'Enter the IP address of your printer': 'أدخل عنوان IP للطابعة الخاصة بك',


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
    'Could not connect to the thermal printer. Would you like to save the report as a PDF instead?':'تعذر الاتصال بالطابعة الحرارية. هل ترغب في حفظ التقرير كملف PDF؟',
    'Error loading report': 'خطأ في تحميل التقرير',
    'Report saved as PDF': 'تم حفظ التقرير كملف PDF',
    'Failed to save report as PDF': 'فشل في حفظ التقرير كملف PDF',
    'No report data available to save': 'لا توجد بيانات تقرير متاحة للحفظ',
    'No sales data available':"لا توجد بيانات مبيعات متاحة",
    'No sales data found':'لم يتم العثور على بيانات المبيعات',
    'Payment data not available':'بيانات الدفع غير متوفرة',
    'No report data available to print':"لا توجد بيانات تقرير متاحة للطباعة",
    'Report printed successfully':'تم طباعة التقرير بنجاح',
    'Error printing report':'خطأ في طباعة التقرير',

    // Settings screen 
    'Registered Devices':'الأجهزة المسجلة',
    'Link Device':'ربط الجهاز',
    'Show menu':'عرض القائمة',
    'MAIN':'الرئيسية',
    'THIS DEVICE':'هذا الجهاز',
    'Last Synced':'آخر مزامنة',
    'Enable Device Sync':'تمكين مزامنة الجهاز',
    'Automatically sync across all devices':'المزامنة تلقائيًا عبر جميع الأجهزة',
    'Management': 'الإدارة',
    'Device Management':'إدارة الجهاز',
    'Device Sync':'مزامنة الجهاز',
    'Manage devices and enable syncing':'إدارة الأجهزة وتمكين المزامنة',
    "Customers":"العملاء",
    'Dashboard Layout':'تخطيط لوحة القيادة',
    'Delivery Boys':'موظفو التوصيل',
    'View and manage customer list':'عرض وإدارة قائمة العملاء',
    'Manage delivery personnel':'إدارة موظفي التوصيل',
    'Reset to First Time Setup':'إعادة التعيين إلى الإعداد الأولي',
    'Clear registration and restart app':'مسح التسجيل وإعادة تشغيل التطبيق',
    'Reset Data':'إعادة تعيين البيانات',
    'Clear all app data':'مسح جميع بيانات التطبيق',
    'This will:':'سيؤدي هذا إلى:',
    'Reset to Setup':'إعادة تعيين إلى الإعدادات',
    '• Clear all app data':'• مسح جميع بيانات التطبيق',
    '• Reset device registration':'• إعادة تعيين تسجيل الجهاز',
    '• Reset company registration':'• إعادة تعيين تسجيل الشركة',
    '• Return to device registration screen':'• العودة إلى شاشة تسجيل الجهاز',
    'This action cannot be undone!':'لا يمكن التراجع عن هذا الإجراء!',
    'Resetting app... Please wait.':'إعادة تعيين التطبيق... يرجى الانتظار.',
    'Reset Complete':'إعادة التعيين مكتملة',
    'The app has been reset to first-time setup. Press OK to restart the registration process.':'تم إعادة تعيين التطبيق إلى الإعداد الأولي. اضغط على "موافق" لإعادة بدء عملية التسجيل.',
    'Settings': 'الإعدادات',
    'Owner': 'المالك',
    'Business Information': 'معلومات العمل',
    'Expense': 'المصروفات',
    'Tax Settings': 'إعدادات الضريبة',
    'Data & Backup': 'البيانات والنسخ الاحتياطي',
    'Appearance': 'المظهر',
    'Language': 'اللغة',
    'English': 'إنجليزي',
    'Arabic': 'عربي',
    'Version 1.0.1': 'الإصدار 1.0.1',
    'Configure restaurant details': 'تكوين تفاصيل المطعم',
    'Restaurant Name': 'اسم المطعم',
    'Enter your restaurant name': 'أدخل اسم المطعم',
    'Please enter restaurant name': 'الرجاء إدخال اسم المطعم',
    'Second Restaurant Name': 'اسم المطعم الثاني',
    'Enter second restaurant name (optional)': 'أدخل اسم المطعم الثاني (اختياري)',
    'Address': 'العنوان',
    'Enter your restaurant address': 'أدخل عنوان المطعم',
    'Enter your restaurant phone number': 'أدخل رقم هاتف المطعم',
    'Update': 'تحديث',
    'Business information updated (not saved yet)': 'تم تحديث معلومات العمل (لم يتم الحفظ بعد)',
    'Current Tax Rate': 'معدل الضريبة الحالي',
    'Sales Tax Rate (%)': 'معدل ضريبة المبيعات (%)',
    'Enter your tax rate (e.g., 5.0)': 'أدخل معدل الضريبة الخاص بك (مثل 5.0)',
    'Please enter tax rate': 'الرجاء إدخال معدل الضريبة',
    'Tax rate must be between 0 and 100': 'يجب أن يكون معدل الضريبة بين 0 و 100',
    'Tax rate updated (not saved yet)': 'تم تحديث معدل الضريبة (لم يتم الحفظ بعد)',
    'Expense Management': 'إدارة المصروفات',
    'Track and manage your expenses': 'تتبع وإدارة مصروفاتك',
    'View daily and monthly sales reports': 'عرض التقارير اليومية والشهرية للمبيعات',
    'Product Management': 'إدارة المنتجات',
    'Add, edit, or remove menu items': 'إضافة أو تعديل أو إزالة عناصر القائمة',
    'Table Management': 'إدارة الطاولات',
    'Configure dining tables and layout': 'تكوين طاولات الطعام والتخطيط',
    'Dining Table Layout': 'تخطيط طاولة الطعام',
    'Configure table rows and columns': 'تكوين صفوف وأعمدة الطاولة',
    'Printer Configuration': 'تكوين الطابعة',
    'Configure thermal printer settings': 'تكوين إعدادات الطابعة الحرارية',
    'Select Table Layout': 'حدد تخطيط الطاولة',
    'Table layout saved': 'تم حفظ تخطيط الطاولة',
    'Backup & Restore': 'النسخ الاحتياطي والاستعادة',
    'Create, restore, and manage backups': 'إنشاء واستعادة وإدارة النسخ الاحتياطية',
    'Reset All Data': 'إعادة تعيين جميع البيانات',
    'This will delete all app data. This action cannot be undone. Are you sure you want to continue?': 'سيؤدي هذا إلى حذف جميع بيانات التطبيق. لا يمكن التراجع عن هذا الإجراء. هل أنت متأكد أنك تريد المتابعة؟',
    'No': 'لا',
    'Yes': 'نعم',
    'Enter Password:': 'أدخل كلمة المرور:',
    'Please enter the password': 'الرجاء إدخال كلمة المرور',
    'Incorrect password': 'كلمة مرور غير صحيحة',
    'Verify': 'تحقق',
    'Resetting data... Please wait.': 'إعادة تعيين البيانات... يرجى الانتظار.',
    'This may take a moment. Do not close the app.': 'قد يستغرق هذا لحظة. لا تغلق التطبيق.',
    'All data has been reset successfully. You must restart the app for changes to take effect completely.': 'تم إعادة تعيين جميع البيانات بنجاح. يجب إعادة تشغيل التطبيق لتصبح التغييرات سارية المفعول بالكامل.',
    'Error loading settings': 'خطأ في تحميل الإعدادات',
    'Settings saved successfully': 'تم حفظ الإعدادات بنجاح',
    'Error saving settings': 'خطأ في حفظ الإعدادات',
    'Error resetting data': 'خطأ في إعادة تعيين البيانات',
    'Language changed successfully': 'تم تغيير اللغة بنجاح',
    'Are you sure you want to logout?': 'هل أنت متأكد أنك تريد تسجيل الخروج؟',
    'Logout':'تسجيل الخروج',
    'License Active': 'ترخيص نشط',
    'License Expired': 'انتهت صلاحية الترخيص',
    'License will expire in {days} days': 'ستنتهي صلاحية الترخيص في {days} يومًا',
    'Contact support for assistance': 'اتصل بالدعم للمساعدة',
    'License expiring soon. Contact support for renewal:': 'ترخيصك على وشك الانتهاء. اتصل بالدعم لتجديده:',
    'Contact support for license renewal:': 'اتصل بالدعم لتجديد الترخيص:',
    'Demo Expired': 'انتهت صلاحية العرض التجريبي',
    'days left': 'أيام متبقية',
    'Demo Mode Active': 'وضع العرض التجريبي نشط',
    'Contact support for full registration:': 'اتصل بالدعم للتسجيل الكامل:',
    'Demo expiring soon. Contact support for full registration:': 'العرض التجريبي على وشك الانتهاء. اتصل بالدعم للتسجيل الكامل:',
    'Demo expired. Settings cannot be modified.': 'انتهت صلاحية العرض التجريبي. لا يمكن تعديل الإعدادات.',
    'Changes saved locally. Will sync when internet is available.': 'تم حفظ التغييرات محلياً. ستتم المزامنة عند توفر الإنترنت.',
    'Changes saved locally. Sync will retry automatically.': 'تم حفظ التغييرات محلياً. ستحاول المزامنة مرة أخرى تلقائياً.',
    'Business information synced to cloud': 'تم مزامنة معلومات العمل مع السحابة',
    'Email Address': 'عنوان البريد الإلكتروني',
    'Enter your email address': 'أدخل عنوان بريدك الإلكتروني',
    'Contact support for assistance:': 'اتصل بالدعم للمساعدة:',
    'Show Logo in Receipts': 'إظهار الشعار في الإيصالات',
    'Display logo on printed and PDF receipts': 'عرض الشعار على الإيصالات المطبوعة وملفات PDF',
     'Logo will be shown in receipts': 'سيظهر الشعار في الإيصالات',
     'Logo will be hidden in receipts': 'لن يظهر الشعار في الإيصالات',
     'Remove Logo': 'إزالة الشعار',
    'Are you sure you want to remove the logo?': 'هل أنت متأكد أنك تريد إزالة الشعار؟',
     'Logo removed successfully': 'تمت إزالة الشعار بنجاح',
    'Upload Logo': 'رفع الشعار',
    'Change Logo': 'تغيير الشعار',
    'Logo updated successfully': 'تم تحديث الشعار بنجاح',
    'No logo uploaded': 'لا يوجد شعار تم رفعه',
    'Business Logo Settings': 'إعدادات شعار العمل',
    'Business Logo': 'شعار العمل',
    'Logo uploaded': 'تم رفع الشعار',
     'VAT Type': 'نوع ضريبة القيمة المضافة',
     'Exclusive VAT': 'ضريبة القيمة المضافة الحصرية',
    'Tax added on top of price': 'الضريبة مضافة على السعر',
    'Inclusive VAT': 'ضريبة القيمة المضافة الشاملة',
    'Tax included in price': 'الضريبة مشمولة في السعر',
    
    // Settings Password Dialog
    'Enter Password': 'أدخل كلمة المرور',
    'Please enter the password to access settings': 'الرجاء إدخال كلمة المرور للوصول إلى الإعدادات',
    'Please enter a password': 'الرجاء إدخال كلمة المرور',
    'Invalid password': 'كلمة مرور غير صحيحة',
    'Error verifying password': 'خطأ في التحقق من كلمة المرور',

    // Table Management Screen
    'No tables available. Add a table to get started.': 'لا توجد طاولات متاحة. أضف طاولة للبدء.',
    'Capacity': 'السعة',
    'Delete Table': 'حذف الطاولة',
    'This action cannot be undone.': 'لا يمكن التراجع عن هذا الإجراء.',
    'Add Table': 'إضافة طاولة',
    'Table Number': 'رقم الطاولة',
    'Number of seats at this table': 'عدد المقاعد في هذه الطاولة',
    'Note': 'ملاحظة',
    'Optional information about this table': 'معلومات اختيارية حول هذه الطاولة',
    'Table Status': 'حالة الطاولة',
    'Add': 'إضافة',
    'Please enter a valid table number': 'الرجاء إدخال رقم طاولة صحيح',
    'Please enter a valid capacity': 'الرجاء إدخال سعة صحيحة',
    'Edit Table': 'تعديل الطاولة',

    
    // Backup Manager Widget
    'Error loading backups': 'خطأ في تحميل النسخ الاحتياطية',
    'Backup created successfully': 'تم إنشاء النسخة الاحتياطية بنجاح',
    'Failed to create backup': 'فشل في إنشاء النسخة الاحتياطية',
    'Error creating backup': 'خطأ في إنشاء النسخة الاحتياطية',
    'Confirm Restore': 'تأكيد الاستعادة',
    'Restoring will overwrite all current data with the selected backup. This action cannot be undone. Are you sure you want to continue?': 'ستؤدي الاستعادة إلى الكتابة فوق جميع البيانات الحالية بالنسخة الاحتياطية المحددة. لا يمكن التراجع عن هذا الإجراء. هل أنت متأكد أنك تريد المتابعة؟',
    'Restore': 'استعادة',
    'Restore completed successfully': 'اكتملت الاستعادة بنجاح',
    'Restart Required': 'إعادة التشغيل مطلوبة',
    'The app needs to be restarted to apply the restored settings. Please close and reopen the app.': 'يحتاج التطبيق إلى إعادة التشغيل لتطبيق الإعدادات المستعادة. يرجى إغلاق التطبيق وإعادة فتحه.',
    'Failed to restore backup': 'فشل في استعادة النسخة الاحتياطية',
    'Error restoring backup': 'خطأ في استعادة النسخة الاحتياطية',
    'Confirm Delete': 'تأكيد الحذف',
    'Are you sure you want to delete this backup? This action cannot be undone.': 'هل أنت متأكد أنك تريد حذف هذه النسخة الاحتياطية؟ لا يمكن التراجع عن هذا الإجراء.',
    'Backup deleted successfully': 'تم حذف النسخة الاحتياطية بنجاح',
    'Failed to delete backup': 'فشل في حذف النسخة الاحتياطية',
    'Error deleting backup': 'خطأ في حذف النسخة الاحتياطية',
    'Delete Old Backups': 'حذف النسخ الاحتياطية القديمة',
    'Delete backups older than:': 'حذف النسخ الاحتياطية الأقدم من:',
    '7 days': '7 أيام',
    '30 days': '30 يوم',
    '90 days': '90 يوم',
    'Deleted': 'تم حذف',
    'old backup(s)': 'نسخة احتياطية قديمة',
    'Error deleting old backups': 'خطأ في حذف النسخ الاحتياطية القديمة',
    'Keep Recent Backups': 'الاحتفاظ بالنسخ الاحتياطية الحديثة',
    'Keep only the most recent:': 'الاحتفاظ فقط بالأحدث:',
    '3 backups': '3 نسخ احتياطية',
    '5 backups': '5 نسخ احتياطية',
    '10 backups': '10 نسخ احتياطية',
    'Kept': 'تم الاحتفاظ بـ',
    'recent backup(s), deleted': 'نسخة احتياطية حديثة، تم حذف',
    'Error managing backups': 'خطأ في إدارة النسخ الاحتياطية',
    'Failed to share backup': 'فشل في مشاركة النسخة الاحتياطية',
    'Error sharing backup': 'خطأ في مشاركة النسخة الاحتياطية',
    'Backup exported to Downloads folder': 'تم تصدير النسخة الاحتياطية إلى مجلد التنزيلات',
    'Failed to export backup': 'فشل في تصدير النسخة الاحتياطية',
    'Error exporting backup': 'خطأ في تصدير النسخة الاحتياطية',
    'Backup exported to Google Drive': 'تم تصدير النسخة الاحتياطية إلى Google Drive',
    'Failed to export to Google Drive': 'فشل في التصدير إلى Google Drive',
    'Note: Google Drive export requires additional setup': 'ملاحظة: تصدير Google Drive يتطلب إعداد إضافي',
    'Error exporting to Google Drive': 'خطأ في التصدير إلى Google Drive',
    'Restore from this backup': 'الاستعادة من هذه النسخة الاحتياطية',
    'Share backup': 'مشاركة النسخة الاحتياطية',
    'Export to Downloads folder': 'تصدير إلى مجلد التنزيلات',
    'Export to Google Drive': 'تصدير إلى Google Drive',
    'Delete backup': 'حذف النسخة الاحتياطية',
    'Delete old backups': 'حذف النسخ الاحتياطية القديمة',
    'Keep only recent backups': 'الاحتفاظ بالنسخ الاحتياطية الحديثة فقط',
    'Error loading Google Drive backups': 'خطأ في تحميل النسخ الاحتياطية من Google Drive',
    'Confirm Restore from Google Drive': 'تأكيد الاستعادة من Google Drive',
    'Restoring will download the backup from Google Drive and overwrite all current data. This action cannot be undone. Are you sure you want to continue?': 'ستقوم الاستعادة بتنزيل النسخة الاحتياطية من Google Drive والكتابة فوق جميع البيانات الحالية. لا يمكن التراجع عن هذا الإجراء. هل أنت متأكد أنك تريد المتابعة؟',
    'Restore from Google Drive completed successfully': 'اكتملت الاستعادة من Google Drive بنجاح',
    'Failed to restore from Google Drive': 'فشل في الاستعادة من Google Drive',
    'Error restoring from Google Drive': 'خطأ في الاستعادة من Google Drive',
    'Restore from this Google Drive backup': 'الاستعادة من هذه النسخة الاحتياطية في Google Drive',
    'Download to device': 'تنزيل إلى الجهاز',
    'Delete from Google Drive': 'حذف من Google Drive',
    'Are you sure you want to delete this backup from Google Drive? This action cannot be undone.': 'هل أنت متأكد أنك تريد حذف هذه النسخة الاحتياطية من Google Drive؟ لا يمكن التراجع عن هذا الإجراء.',
    'Backup deleted from Google Drive': 'تم حذف النسخة الاحتياطية من Google Drive',
    'Failed to delete backup from Google Drive': 'فشل في حذف النسخة الاحتياطية من Google Drive',
    'Backup downloaded from Google Drive': 'تم تنزيل النسخة الاحتياطية من Google Drive',
    'Failed to download backup from Google Drive': 'فشل في تنزيل النسخة الاحتياطية من Google Drive',
    'Error downloading backup': 'خطأ في تنزيل النسخة الاحتياطية',
    'Device Backups': 'النسخ الاحتياطية للجهاز',
    'Google Drive': 'Google Drive',
    'No backups found on Google Drive': 'لم يتم العثور على نسخ احتياطية في Google Drive',
    'Refresh': 'تحديث',
    'No local backups found': 'لم يتم العثور على نسخ احتياطية محلية',
    'Full backup': 'نسخة احتياطية كاملة',
    'Settings only': 'الإعدادات فقط',
    'Unknown date': 'تاريخ غير معروف',


    // Kitchen Note Dialog
    'Enter kitchen note here...': 'أدخل ملاحظة المطبخ هنا...',
    'Printing...': 'جاري الطباعة...',

    // Table Orders Screen
    'Failed to load orders': 'فشل في تحميل الطلبات',
    'No orders found for Table': 'لم يتم العثور على طلبات للطاولة',
    'This table has no active or completed orders': 'هذه الطاولة ليس لديها طلبات نشطة أو مكتملة',
    'Create Order': 'إنشاء طلب',
    'View Details': 'عرض التفاصيل',
    'more item': 'عنصر إضافي',
    'more items': 'عناصر إضافية',
    'Completed': 'مكتمل',
    'Cancelled': 'ملغي',


    // Tender Screen
    'Receipt #': 'إيصال #',
    'Click "Open PDF" to view in your default PDF viewer': 'انقر على "فتح PDF" للعرض في عارض PDF الافتراضي الخاص بك',
    'Open PDF': 'فتح PDF',
    'Could not open PDF viewer': 'تعذر فتح عارض PDF',
    'Cancel Order': 'إلغاء الطلب',
    'Processing payment...': 'جاري معالجة الدفع...',
    'Please select a payment method': 'الرجاء اختيار طريقة دفع',
    'Discount of': 'خصم قدره',
    'applied successfully': 'تم تطبيقه بنجاح',
    'Preview': 'معاينة',
    'Error loading PDF preview': 'خطأ في تحميل معاينة PDF',
    'Error generating bill preview': 'خطأ في إنشاء معاينة الفاتورة',
    'Failed to update order status, but continuing with payment processing': 'فشل في تحديث حالة الطلب، ولكن متابعة معالجة الدفع',
    'Error processing payment': 'خطأ في معالجة الدفع',
    'Apply Discount': 'تطبيق خصم',
    'Current Total': 'المجموع الحالي',
    'New Total': 'المجموع الجديد',
    'Discount Amount': 'مبلغ الخصم',
    'Apply': 'تطبيق',
    'Cancel Order?': 'إلغاء الطلب؟',
    'Are you sure you want to cancel this order?': 'هل أنت متأكد أنك تريد إلغاء هذا الطلب؟',
    'Order cancelled successfully': 'تم إلغاء الطلب بنجاح',
    'Failed to cancel order. Please try again.': 'فشل في إلغاء الطلب. يرجى المحاولة مرة أخرى.',
    'Error cancelling order': 'خطأ في إلغاء الطلب',
    'Terminal credit card': 'بطاقة ائتمان المحطة',
    'Balance amount': 'المبلغ المتبقي',
    'Received': 'مستلم',
    'Last 4 digit': 'آخر 4 أرقام',
    'Approval code': 'رمز الموافقة',
    'Please enter a valid amount': 'الرجاء إدخال مبلغ صحيح',
    'No remaining balance to pay': 'لا يوجد رصيد متبقي للدفع',
    'Confirm': 'تأكيد',
    'Do you want to print?': 'هل تريد الطباعة؟',
    'Payment of': 'دفعة بمبلغ',
    'accepted. Return change': 'مقبولة. إرجاع الباقي',
    'accepted': 'مقبولة',
    'Payment complete!': 'اكتمل الدفع!',
    'Balance amount is': 'المبلغ المتبقي هو',
    'Please select a payment method first': 'الرجاء اختيار طريقة دفع أولاً',
    'Bank': 'بنك',
    'Customer Credit': 'ائتمان العميل',
    'Credit Sale': 'بيع بالائتمان',
    'Order type': 'نوع الطلب',
    'Status': 'الحالة',
    'Total amount': 'المبلغ الإجمالي',
    'Coupon code': 'رمز القسيمة',
    'Paid amount': 'المبلغ المدفوع',
    'Printer Not Available': 'الطابعة غير متاحة',
    'No printer was found. Would you like to save the receipt as a PDF?': 'لم يتم العثور على طابعة. هل تريد حفظ الإيصال كملف PDF؟',
    'Save PDF': 'حفظ PDF',
    'View Bill': 'عرض الفاتورة',
    'Reprint': 'إعادة طباعة',
    'Printing failed and PDF save was cancelled': 'فشل الطباعة وتم إلغاء حفظ PDF',
    'Customer Credit :': 'ائتمان العميل :',
    'Add credit to customer': 'إضافة ائتمان للعميل',
    'Credit Amount:': 'مبلغ الائتمان:',
    'Current credit balance:': 'رصيد الائتمان الحالي:',
    'Credit of': 'ائتمان بقيمة',
    'added to': 'تم إضافته إلى',
    'after discount of': 'بعد خصم قدره',
    'Error processing customer credit': 'خطأ في معالجة ائتمان العميل',
    'Error completing credit payment': 'خطأ في إكمال دفع الائتمان',
    'Credit payment completed via': 'تم إكمال دفع الائتمان عبر',
    'Error reprinting receipt': 'خطأ في إعادة طباعة الإيصال',
    'no receipt printed': 'لم تتم طباعة الإيصال',
    'Add Credit':' إضافة ائتمان',
    'Visited On :':'تمت الزيارة في :',
    'Credit Transactions -':'معاملات الائتمان -',
    'No credit transactions found':'لم يتم العثور على معاملات ائتمان',
    'No pending credit transactions for':'لا توجد معاملات ائتمان معلقة لـ',
    'Customer has no credit balance':'العميل ليس لديه رصيد ائتماني',
    'Total Credit Balance:':'إجمالي رصيد الائتمان:',
    'Amount:':'المبلغ:',
   'credit_completion':'إكمال الائتمان',

    //bill Service
    'Could not connect to the thermal printer. Would you like to save the bill as a PDF?':'تعذر الاتصال بالطابعة الحرارية. هل ترغب في حفظ الفاتورة بصيغة PDF؟',
    'Order processed and bill printed successfully':'تم معالجة الطلب وطباعة الفاتورة بنجاح',
    'Order processed, but bill was not printed or saved':'تم معالجة الطلب، ولكن لم يتم طباعة الفاتورة أو حفظها',
    'Order processed and bill saved as PDF':'تم معالجة الطلب وحفظ الفاتورة بصيغة PDF',
    'Failed to save the bill':"فشل في حفظ الفاتورة",
    'Could not print kitchen receipt. Would you like to save it as a PDF?':'تعذر طباعة إيصال المطبخ. هل ترغب في حفظه كملف PDF؟',
    'Kitchen receipt saved as PDF':'إيصال المطبخ محفوظ بصيغة PDF',
    'Failed to print or save kitchen receipt':'فشل في طباعة أو حفظ إيصال المطبخ',
    'KOT printer is disabled. Would you like to save kitchen receipt as PDF?':'تم تعطيل طابعة KOT. هل ترغب في حفظ إيصال المطبخ كملف PDF؟',
    'Could not print kitchen receipt to KOT printer. Would you like to save it as PDF to your device?':'تعذر طباعة إيصال المطبخ على طابعة KOT. هل ترغب في حفظه كملف PDF على جهازك؟',
     // Renewal Screen translations
      'Demo Renewal': 'تجديد العرض التجريبي',
      'License Renewal': 'تجديد الترخيص',
      'Upgrade Plan': 'ترقية الخطة',
      'Renew your license for another year': 'جدد ترخيصك لعام آخر',
      'Generate Renewal Keys': 'توليد مفاتيح التجديد',
      'Click the button below to generate your unique renewal keys': 'انقر على الزر أدناه لتوليد مفاتيح التجديد الفريدة الخاصة بك',
      'Generate': 'توليد',
      'Contact for Keys': 'اتصل للحصول على المفاتيح',
      'Renewal keys have been generated for your device. Please contact support to get your keys:': 'تم توليد مفاتيح التجديد لجهازك. يرجى الاتصال بالدعم للحصول على مفاتيحك:',
      'Keys are valid for 7 days. Please complete renewal within this time.': 'المفاتيح صالحة لمدة 7 أيام. يرجى إكمال التجديد خلال هذا الوقت.',
      'Enter Your Renewal Keys:': 'أدخل مفاتيح التجديد الخاصة بك:',
      'Renew': 'تجديد',
      'Renewal keys generated successfully! Contact support to get your keys.': 'تم توليد مفاتيح التجديد بنجاح! اتصل بالدعم للحصول على مفاتيحك.',
      'Please fill all renewal key fields': 'يرجى ملء جميع حقول مفاتيح التجديد',
      'Renewal successful!': 'تم التجديد بنجاح!',
      'These renewal keys have already been used. Please contact support for new keys.': 'تم استخدام مفاتيح التجديد هذه بالفعل. يرجى الاتصال بالدعم للحصول على مفاتيح جديدة.',
      'These renewal keys were just used. Please contact support for new keys.': 'تم استخدام مفاتيح التجديد هذه للتو. يرجى الاتصال بالدعم للحصول على مفاتيح جديدة.',
      'Invalid renewal keys. Please check and try again.': 'مفاتيح تجديد غير صالحة. يرجى التحقق والمحاولة مرة أخرى.',
      'No pending renewal found. Please generate keys first.': 'لم يتم العثور على تجديد معلق. يرجى توليد المفاتيح أولاً.',
      'Renewal keys have expired. Please generate new ones.': 'انتهت صلاحية مفاتيح التجديد. يرجى توليد مفاتيح جديدة.',
      'You already have pending renewal keys. Please use those keys to complete renewal.': 'لديك بالفعل مفاتيح تجديد معلقة. يرجى استخدام تلك المفاتيح لإكمال التجديد.',
      'Your previous renewal keys have expired. You can generate new ones.': 'انتهت صلاحية مفاتيح التجديد السابقة. يمكنك توليد مفاتيح جديدة.',
      'Failed to generate renewal keys': 'فشل في توليد مفاتيح التجديد',
      'Failed to generate keys. Please check your internet connection and try again.': 'فشل في توليد المفاتيح. يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.',
      'This device already has pending renewal keys. Please use those keys or contact support.': 'هذا الجهاز لديه بالفعل مفاتيح تجديد معلقة. يرجى استخدام تلك المفاتيح أو الاتصال بالدعم.',
      'Renewal failed. Please check your internet connection and try again.': 'فشل التجديد. يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.',
      'Delivery Address':'العنوان للتسليم',
      //crossplatform pdf
      'Printer not available. Would you like to save the receipt as PDF to your device?': 'تعذر العثور على الطابعة. هل ترغب في حفظ الإيصال كملف PDF على جهازك؟',
      'Printer not available. Would you like to save the receipt as PDF?':' تعذر العثور على الطابعة. هل ترغب في حفظ الإيصال كملف PDF؟',

      //Quotation list screen
      'Convert to Order?': 'تحويل إلى طلب؟',
      'Are you sure you want to convert this quotation to an order?': 'هل أنت متأكد أنك تريد تحويل نموذج عرض السعر هذا إلى طلب؟',
      'This will move the quotation to active orders.': 'سيؤدي هذا إلى نقل عرض السعر إلى الطلبات النشطة.',
      'Convert': 'تحويل',
      'Quotations': 'عروض الأسعار',
      'No Quotations Found': 'لم يتم العثور على عروض أسعار',
      'Quote': 'عرض سعر',
      'Service': 'الخدمة',
      'Customer ID': 'هوية العميل',
      'Share': 'مشاركة',
      'Convert to Order': 'تحويل إلى طلب',
      'Converted to Order successfully': 'تم التحويل إلى طلب بنجاح',
      'Failed to convert': 'فشل التحويل',
      'Quotation': 'عرض سعر',
      'Quotation List': 'قائمة عروض الأسعار',
      'Quotations List': 'قائمة عروض الأسعار',
      'Error sharing quote': 'خطأ في مشاركة العرض',
      'QUOTATION': 'عرض سعر',
      // Device Management
      'Set Up Main Device': 'إعداد الجهاز الرئيسي',
      'Main Device Name': 'اسم الجهاز الرئيسي',
      'Please enter device name': 'الرجاء إدخال اسم الجهاز',
      'This device will be set as the main device . You can generate codes to link other devices.': 'سيتم تعيين هذا الجهاز كجهاز رئيسي. يمكنك إنشاء رموز لربط الأجهزة الأخرى.',
      'Main device set successfully!': 'تم تعيين الجهاز الرئيسي بنجاح!',
      'Failed to set main device': 'فشل تعيين الجهاز الرئيسي',
      '6-Digit Code': 'رمز مكون من 6 أرقام',
      'Enter code from main device': 'أدخل الرمز من الجهاز الرئيسي',
      'Please enter the code': 'الرجاء إدخال الرمز',
      'Code must be 6 digits': 'يجب أن يتكون الرمز من 6 أرقام',
      'Device Name': 'اسم الجهاز',
      'Get the 6-digit code from the main device to link this device.': 'احصل على الرمز المكون من 6 أرقام من الجهاز الرئيسي لربط هذا الجهاز.',
      'Device Linked!': 'تم ربط الجهاز!',
      'Successfully linked to:': 'تم الربط بنجاح بـ:',
      'This device will now sync with all devices.': 'سيقوم هذا الجهاز الآن بالمزامن مع جميع الأجهزة.',
      'Continue': 'استمرار',
      'Failed to link device': 'فشل ربط الجهاز',
      'Link Code': 'رمز الربط',
      'Expires in 24 hours': 'تنتهي الصلاحية خلال 24 ساعة',
      'Enter this code on the device to link it to this Main Device.': 'أدخل هذا الرمز على الجهاز لربطه بهذا الجهاز الرئيسي.',
      'Code copied to clipboard': 'تم نسخ الرمز إلى الحافظة',
      'Copy Code': 'نسخ الرمز',
      'Set Main Device': 'تعيين جهاز رئيسي',
      'Set as Main Device Confirmation': 'تعيين "%name%" كجهاز رئيسي؟ سيكون هذا الجهاز قادرًا على إنشاء رموز ربط للأجهزة.',
     
      'Main device set successfully': 'تم تعيين الجهاز الرئيسي بنجاح',
      'Remove Device': 'إزالة الجهاز',
      'Remove Device Confirmation': 'إزالة "%name%" من المزامنة؟ لن يستقبل هذا الجهاز أي شيء بعد الآن.',
      'Device removed successfully': 'تمت إزالة الجهاز بنجاح',
      'Failed to remove device': 'فشل إزالة الجهاز',
      'Device sync enabled': 'تم تمكين مزامنة الجهاز',
      'Device sync disabled': 'تم تعطيل مزامنة الجهاز',
      'No devices registered yet': 'لم يتم تسجيل أي أجهزة بعد',
      'Failed to generate code': 'فشل إنشاء الرمز',

      // Catering Setup Screen
      'Catering Event Setup': 'إعداد حدث التموين',
      'Wedding': 'زفاف',
      'Birthday': 'عيد ميلاد',
      'Corporate': 'شركات',
      'Anniversary': 'ذكرى سنوية',
      'Select Date': 'اختر التاريخ',
      'Select Time': 'اختر الوقت',
      'Number of Guests': 'عدد الضيوف',
      'Token Number': 'رقم الرمز',
      'Venue Address': 'عنوان المكان',
      'Enter venue address': 'أدخل عنوان المكان',
      'Continue to Menu': 'المتابعة إلى القائمة',
      'Catering Orders': 'طلبات التموين',
      'Catering - Wedding': 'تموين - زفاف',
      'Catering - Birthday': 'تموين - عيد ميلاد',
      'Catering - Corporate': 'تموين - شركات',
      'Catering - Anniversary': 'تموين - ذكرى سنوية',
      'Catering - Other': 'تموين - أخرى',
      
      // Tender Screen
      'Split Payment': 'تقسيم الدفع',
      
      'Advance Mode: Enter advance amount': 'وضع الدفع المسبق: أدخل مبلغ الدفعة المقدمة',
      'Full Payment Mode': 'وضع الدفع الكامل',
      'Advance Payment': 'دفع مقدم',
      'Enter amount for:': 'أدخل المبلغ لـ:',
      'Cash Amount': 'مبلغ نقدي',
      'Bank Amount': 'مبلغ بنكي',
      'Cash Amount:': 'مبلغ نقدي',
      'Bank Amount:': 'مبلغ بنكي',
      'Balance to Pay:': 'الرصيد للدفع:',
      'Delivery Fee:': 'رسوم التوصيل:',
      'Advance Paid:': 'مدفوع مقدماً:',
      'Balance:': 'الرصيد:',
      'Remaining:': 'المتبقي:',
      'Record Advance of': 'تسجيل دفعة مقدمة بقيمة',
      'Confirm Advance': 'تأكيد الدفعة المقدمة',
      'Advance recorded successfully': 'تم تسجيل الدفعة المقدمة بنجاح',
      'Error recording advance': 'خطأ في تسجيل الدفعة المقدمة',
      'Receipt reprinted successfully': 'تم إعادة طباعة الإيصال بنجاح',
      'Failed to reprint receipt': 'فشل إعادة طباعة الإيصال',
      'Advance must be less than total. Use full payment instead.': 'يجب أن تكون الدفعة المقدمة أقل من المجموع. استخام الدفع الكامل بدلاً من ذلك.',
      'Please enter an advance amount': 'الرجاء إدخال مبلغ الدفعة المقدمة',
      'Discount applied': 'تم خصم',
      'Clear Discount': 'مسح الخصم',
      'Discount cleared': 'تم مسح الخصم',
      'Enter discount amount': 'أدخل مبلغ الخصم',
      'Enter discount percentage': 'أدخل نسبة الخصم',
      'Max discount exceeded': 'تجاوز الحد الأقصى للخصم',
      'Confirm Payment': 'تأكيد الدفع',
      'Total payment is less than remaining balance': 'إجمالي الدفع أقل من الرصيد المتبقي',
      'Current Balance': 'الرصيد الحالي',
      'New Balance': 'الرصيد الجديد',
      'Payment processed': 'تمت معالجة الدفع',
      'Error processing split payment': 'خطأ في معالجة تقسيم الدفع',
      
      'Terminal card': 'بطاقة الجهاز',
      
     
      'Bank + Cash': 'بنك + نقد',
      'Advance': 'مقدم',
      'Failed to add credit to customer': 'فشل إضافة الرصيد للعميل',
      
      'Original Amount:': 'المبلغ الأصلي:',
      
      // Printer Settings
      
      'Loading settings...': 'جارٍ تحميل الإعدادات...',
      
      'Receipt printer configured with': 'تم إعداد طابعة الإيصالات مع',
      'KOT printer configured with': 'تم إعداد طابعة المطبخ مع',
      
      'Please select a printer': 'يرجى اختيار طابعة',
      
      'Failed to test system printer. Please check if the printer is on and drivers are installed.': 'فشل اختبار طابعة النظام. يرجى التحقق مما إذا كانت الطابعة قيد التشغيل وبرامج التشغيل مثبتة.',
      
      'Failed to test KOT system printer. Please check if the printer is on and drivers are installed.': 'فشل اختبار طابعة نظام المطبخ. يرجى التحقق مما إذا كانت الطابعة قيد التشغيل وبرامج التشغيل مثبتة.',
     
      'Scan for printers': 'البحث عن طابعات',
      'Scan Network': 'فحص الشبكة',
      'Printer Type': 'نوع الطابعة',
      'Select Printer Type': 'ترع الطابعة',
      'Network IP': 'عنوان IP للشبكة',
      'Port': 'المنفذ',
      
      'System Printer': 'طابعة النظام',
      'Select System Printer': 'اختر طابعة النظام',
      
      'Use KOT Printer': 'استخدام طابعة المطبخ',
      'Troubleshooting Guide': 'دليل استكشاف الأخطاء وإصلاحها',
      '1. Network Printers': '1. طابعات الشبكة',
      'Ensure the printer and this device are on the same WiFi network. Determine the printer\'s IP address from its self-test page.': 'تأكد من أن الطابعة وهذا الجهاز عى نفس شبكة WiFi. حدد عنوان IP للطابعة من صفحة الاختبار الذاتي.',
      '2. Port Number': '2. رقم المنفذ',
      'Standard port for thermal printers is 9100. Only change this if you have configured your printer differently.': 'المنفذ القياسي للطابعات الحرارية هو 9100. قم بتغييره فقط إذا قمت بتكوين طابعتك بشكل مختلف.',
      '3. System Printers': '3. طابعات النظام',
      'Connect your USB printer and ensure drivers are installed. If it doesn\'t appear in the list, try refreshing or restarting the app.': 'قم بتوصيل طابعة USB وتأكد من تثبيت برامج التشغيل. إذا لم تظهر في القائمة، حاول التحديث أو إعادة تشغيل التطبيق.',
      '4. KOT Printing': '4. طباعة المطبخ',
      'You can use the same physical printer for both Receipt and KOT by entering the same settings in both tabs.': 'يمكنك استخدام نفس الطابعة الفعلية لكل من الإيصالات والمطبخ عن طريق إدخال نفس الإعدادات في كلا علامتي التبويب.',


      
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