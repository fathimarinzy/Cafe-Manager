import 'package:cafeapp/providers/logo_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'dart:async';

// Desktop-specific imports
import 'package:window_manager/window_manager.dart';

// Database helper
import 'utils/database_helper.dart';
import 'utils/logger.dart';

import 'screens/login_screen.dart';
import 'screens/person_form_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/device_registration_screen.dart';
import 'screens/company_registration_screen.dart';
import 'screens/online_company_registration_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/printer_settings_screen.dart';
import 'screens/expense_screen.dart';
import 'screens/expense_history_screen.dart';
import 'screens/report_screen.dart';
import 'screens/renewal_screen.dart';

import 'providers/table_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/menu_provider.dart';
import 'providers/order_provider.dart';
import 'providers/person_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/order_history_provider.dart';
import 'providers/delivery_boy_provider.dart';
import 'providers/lan_sync_provider.dart';

import 'repositories/local_menu_repository.dart';
import 'repositories/local_expense_repository.dart';
import 'services/firebase_service.dart';
import 'services/demo_service.dart';
import 'services/offline_sync_service.dart';
import 'services/connectivity_monitor.dart';


// const bool forceSafeMode = true; // 🛡️ REMOVED: Replaced by dynamic detection

void main() async {
  // 🛡️ CRITICAL: Set up global error logging immediately
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Load environment variables early
    try {
      await dotenv.load(fileName: ".env");
      await logErrorToFile('✅ Environment variables loaded');
    } catch (e) {
      await logErrorToFile('⚠️ Error loading .env file: $e - Continuing without .env');
    }

    // 🛡️ DYNAMIC SAFE MODE DETECTION
    bool isSafeMode = false;
    
    // 1. Check for marker file (easiest for users)
    final markerFile = File('safe_mode.txt');
    if (markerFile.existsSync()) {
      isSafeMode = true;
      await logErrorToFile('🛡️ Safe Mode detected via safe_mode.txt marker file');
    }
    
    // 2. Check .env variable
    if (!isSafeMode && dotenv.env['SAFE_MODE'] == 'true') {
      isSafeMode = true;
      await logErrorToFile('🛡️ Safe Mode detected via .env SAFE_MODE=true');
    }

    // Log app start with mode
    await logErrorToFile('App starting... (Safe Mode: $isSafeMode)');
    
    await _setupPortableDataPaths();
    
    // CRITICAL FIX: Initialize database with proper error handling
    bool isDatabaseInitialized = false;
    try {
      await DatabaseHelper.initializePlatform();
      isDatabaseInitialized = true;
      await logErrorToFile('✅ Database helper initialized for platform: ${DatabaseHelper.platformName}');
    } catch (e, stack) {
      await logErrorToFile('⚠️ Error initializing database helper: $e\n$stack');
      if (!DatabaseHelper.isSupported) {
        await logErrorToFile('❌ SQLite is not supported on this platform');
        if (!isDesktop()) {
          return;
        }
      }
    }

    // Desktop-specific window configuration
    if (isDesktop()) {
      try {
        if (isSafeMode) {
           await logErrorToFile('🛡️ Safe Mode: Skipping WindowManager configuration');
        } else {
           await configureDesktopWindow();
        }
      } catch (e, stack) {
        await logErrorToFile('❌ Error configuring window: $e\n$stack');
      }
    }

    // Quick initialization - only critical components
    try {
      await quickInitialization(isDatabaseInitialized, isSafeMode);
    } catch (e, stack) {
      await logErrorToFile('❌ Error in quick initialization: $e\n$stack');
    }

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      final errorMsg = '❌ Flutter Error: ${details.exception}\n${details.stack}';
      logErrorToFile(errorMsg);
    };

    runApp(const MyApp());
  }, (error, stackTrace) async {
    final errorMsg = '☠️ UNCAUGHT ERROR: $error\n$stackTrace';
    await logErrorToFile(errorMsg);
    // 🔔 Show visible popup for fatal crashes
    if (Platform.isWindows) {
      await showWindowsErrorDialog('Critical App Crash', 'The app has encountered a critical error and needs to close.\n\nError: $error\n\nPlease send this photo to support.');
    }
  });
}



// 🔔 Show native Windows MessageBox
Future<void> showWindowsErrorDialog(String title, String message) async {
  try {
    // Escape quotes for PowerShell
    final safeTitle = title.replaceAll('"', '\\"');
    final safeMessage = message.replaceAll('"', '\\"').replaceAll('\n', '`n');
    
    await Process.run(
      'powershell', 
      [
        '-Command', 
        'Add-Type -AssemblyName PresentationFramework;[System.Windows.MessageBox]::Show("$safeMessage", "$safeTitle")'
      ],
      runInShell: true,
    );
  } catch (e) {
    debugPrint('Failed to show error dialog: $e');
  }
}

Future<void> _setupPortableDataPaths() async {
  try {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final executableDir = Directory(Platform.resolvedExecutable).parent;
      final portableDataDir = Directory('${executableDir.path}/AppData');
      
      // Create portable data directory if it doesn't exist
      if (!await portableDataDir.exists()) {
        await portableDataDir.create(recursive: true);
      }
      
      await logErrorToFile('📁 Portable data directory: ${portableDataDir.path}');
    }
  } catch (e) {
    await logErrorToFile('⚠️ Portable data setup error: $e');
  }
}
bool isDesktop() {
  try {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  } catch (e) {
    return false; // Web or unknown platform
  }
}

Future<void> configureDesktopWindow() async {
  try {
    await logErrorToFile('🪟 Configuring desktop window...');
    await WindowManager.instance.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'SIMS CAFE',
    );

    WindowManager.instance.waitUntilReadyToShow(windowOptions, () async {
      await WindowManager.instance.show();
      await WindowManager.instance.focus();
    });

    await logErrorToFile('✅ Desktop window configured');
  } catch (e) {
    await logErrorToFile('⚠️ Error configuring desktop window: $e');
  }
}

Future<void> quickInitialization(bool isDatabaseInitialized, bool isSafeMode) async {
  try {
    await logErrorToFile('🚀 Starting quick initialization...');
    await Future.any([
      _performQuickInitialization(isDatabaseInitialized, isSafeMode),
      Future.delayed(const Duration(seconds: 3), () {
        logErrorToFile('⚠️ Quick initialization timed out - continuing anyway');
      }),
    ]);
  } catch (e) {
    await logErrorToFile('⚠️ Quick initialization error: $e');
  }
}

Future<void> _performQuickInitialization(bool isDatabaseInitialized, bool isSafeMode) async {
  // Initialize local database only if it was properly initialized
  if (isDatabaseInitialized) {
    try {
      await initializeLocalDatabase();
      await logErrorToFile('✅ Local databases initialized in quick init');
    } catch (e) {
      await logErrorToFile('⚠️ Could not initialize local database: $e');
    }
  }

  // Initialize Firebase - works for all platforms now
  try {
    if (isSafeMode) {
       await logErrorToFile('🛡️ Safe Mode (Legacy): Initializing Firebase with Firedart (No AVX2)');
       // Pass true to enable Legacy Mode (Firedart)
       FirebaseService.initializeQuickly(useLegacyMode: true);
       await logErrorToFile('✅ Firebase Legacy initialization started');
    } else {
      await logErrorToFile('🔥 Initializing Firebase (Native)...');
      FirebaseService.initializeQuickly(useLegacyMode: false);
      await logErrorToFile('✅ Firebase Native initialization started');
    }
  } catch (e) {
    await logErrorToFile('⚠️ Firebase initialization error: $e');
  }

  // Start connectivity monitoring with delay
  _startConnectivityMonitoring();

  await logErrorToFile('✅ Quick initialization completed');
}


// // NEW: Desktop-specific Firebase initialization
// Future<void> _initializeFirebaseForDesktop() async {
//   try {
//     // On desktop, Firebase initialization might need special handling
//     // Make sure you have firebase_core configured for desktop in your Firebase console
    
//     // Check if internet is available first
//     final hasInternet = await _checkInternetConnection();
//     debugPrint('Internet connection available: $hasInternet');
    
//     if (hasInternet) {
//       FirebaseService.initializeQuickly();
//     } else {
//       debugPrint('⚠️ No internet connection detected - skipping Firebase initialization');
//     }
//   } catch (e) {
//     debugPrint('⚠️ Error in desktop Firebase initialization: $e');
//   }
// }

// NEW: Check internet connection for desktop
Future<bool> _checkInternetConnection() async {
  try {
    // Try to resolve a reliable host
    final result = await InternetAddress.lookup('google.com')
        .timeout(const Duration(seconds: 3));
    
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      // debugPrint('✅ Internet connection verified');
      return true;
    }
  } catch (e) {
    // debugPrint('❌ No internet connection: $e');
  }
  return false;
}

void _startConnectivityMonitoring() {
  Timer(const Duration(seconds: 5), () async {
    try {
      // Check internet connectivity first on desktop
      if (isDesktop()) {
        await _checkInternetConnection();
      }
      
      final hasPendingData = await OfflineSyncService.hasPendingOfflineData();

      if (hasPendingData) {
        // debugPrint('📡 Found pending offline data - starting connectivity monitoring');
        ConnectivityMonitor.instance.startMonitoring();
        OfflineSyncService.autoSync();
      }
    } catch (e) {
      debugPrint('⚠️ Error checking for pending sync data: $e');
    }
  });
}

Future<void> initializeLocalDatabase() async {
  try {
    final localRepo = LocalMenuRepository();
    await localRepo.database;

    final localExpenseRepo = LocalExpenseRepository();
    await localExpenseRepo.database;

    // debugPrint('✅ Local databases initialized');
  } catch (e) {
    await logErrorToFile('❌ Error initializing local databases: $e');
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    logErrorToFile('🏗️ MyApp build started');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) { logErrorToFile('• Provider: AuthProvider'); return AuthProvider(); }),
        ChangeNotifierProvider(create: (ctx) { logErrorToFile('• Provider: MenuProvider'); return MenuProvider(); }),
        ChangeNotifierProvider(create: (ctx) { logErrorToFile('• Provider: OrderProvider'); return OrderProvider(); }),
        ChangeNotifierProvider(create: (ctx) { logErrorToFile('• Provider: PersonProvider'); return PersonProvider(); }),
        ChangeNotifierProvider(create: (ctx) { logErrorToFile('• Provider: TableProvider'); return TableProvider(); }),
        ChangeNotifierProvider(create: (ctx) { logErrorToFile('• Provider: OrderHistoryProvider'); return OrderHistoryProvider(); }),
        ChangeNotifierProvider(create: (ctx) { logErrorToFile('• Provider: SettingsProvider'); return SettingsProvider(); }),
        ChangeNotifierProvider(create: (ctx) { logErrorToFile('• Provider: LogoProvider'); return LogoProvider(); }),
        ChangeNotifierProvider(create: (ctx) { logErrorToFile('• Provider: DeliveryBoyProvider'); return DeliveryBoyProvider(); }),
        ChangeNotifierProvider(create: (ctx) { logErrorToFile('• Provider: LanSyncProvider'); return LanSyncProvider(); }),
      ],
      child: Consumer<SettingsProvider>(
        builder: (ctx, settingsProvider, _) {
          return MaterialApp(
            title: 'SIMS Cafe',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: Colors.white,
              fontFamily: 'Roboto',
              visualDensity: VisualDensity.adaptivePlatformDensity,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: Colors.grey[900],
              fontFamily: 'Roboto',
              visualDensity: VisualDensity.adaptivePlatformDensity,
              brightness: Brightness.dark,
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.grey[850],
                foregroundColor: Colors.white,
              ),
              cardTheme: CardTheme(
                color: Colors.grey[800],
              ),
              textTheme: const TextTheme(
                bodyMedium: TextStyle(color: Colors.white),
                bodyLarge: TextStyle(color: Colors.white),
                titleMedium: TextStyle(color: Colors.white),
                titleLarge: TextStyle(color: Colors.white),
              ),
            ),
            themeMode: settingsProvider.themeMode,
            debugShowCheckedModeBanner: false,
            home: const AppInitializer(),
            routes: {
              AppRoutes.login: (ctx) => const LoginScreen(),
              AppRoutes.addperson: (ctx) => const PersonFormScreen(),
              AppRoutes.dashboard: (ctx) => const DashboardScreen(),
              AppRoutes.deviceRegistration: (ctx) => const DeviceRegistrationScreen(),
              AppRoutes.companyRegistration: (ctx) => const CompanyRegistrationScreen(),
              AppRoutes.onlineCompanyRegistration: (ctx) => const OnlineCompanyRegistrationScreen(),
              AppRoutes.demoRenewal: (ctx) => const RenewalScreen(renewalType: RenewalType.demo),
              AppRoutes.licenseRenewal: (ctx) => const RenewalScreen(renewalType: RenewalType.license),
              AppRoutes.settings: (ctx) => const SettingsScreen(),
              AppRoutes.printerConfig: (ctx) => const PrinterSettingsScreen(),
              AppRoutes.expense: (ctx) => const ExpenseScreen(),
              AppRoutes.expenseHistory: (ctx) => const ExpenseHistoryScreen(),
              AppRoutes.reports: (ctx) => const ReportScreen(),
            },
          );
        },
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    logErrorToFile('🏁 AppInitializer initState called');
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await logErrorToFile('🚀 _initializeApp started');
      final List<Future> futures = [
        Future.delayed(const Duration(milliseconds: 500)),
        _performAppInitialization(),
      ];

      await Future.any([
        Future.wait(futures),
        Future.delayed(const Duration(seconds: 4), () {
          logErrorToFile('⚠️ App initialization timed out - proceeding anyway');
        }),
      ]);
    } catch (e) {
      await logErrorToFile('⚠️ App initialization error: $e');
    }

    if (mounted) {
      _navigateToNextScreen();
    }
  }

  Future<void> _performAppInitialization() async {
    try {
      await logErrorToFile('⚙️ _performAppInitialization started');
      final prefs = await SharedPreferences.getInstance();
      final isDeviceRegistered = prefs.getBool('device_registered') ?? false;

      if (!isDeviceRegistered) {
        return;
      }

      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        await Future.any([
          authProvider.tryAutoLogin(),
          Future.delayed(const Duration(seconds: 3), () {
            debugPrint('⚠️ Auto-login timed out - proceeding to login screen');
            return false;
          }),
        ]);
      }
    } catch (e) {
      debugPrint('⚠️ Error during app initialization: $e');
    }
    try {
      if (mounted) {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        final orderHistoryProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
        LanSyncProvider.instance.onOrdersChanged = () {
          debugPrint('🔄 Refreshing orders due to LAN sync update');
          orderHistoryProvider.loadOrders();
          orderProvider.fetchOrders();
        };
        
        final tableProvider = Provider.of<TableProvider>(context, listen: false);
        LanSyncProvider.instance.onTablesChanged = () {
           debugPrint('🔄 Refreshing tables due to LAN sync update');
           tableProvider.refreshTables();
        };
        
        final personProvider = Provider.of<PersonProvider>(context, listen: false);
        LanSyncProvider.instance.onPersonsChanged = () {
          debugPrint('🔄 Refreshing persons due to LAN sync update');
          personProvider.loadPersons();
        };

        final deliveryBoyProvider = Provider.of<DeliveryBoyProvider>(context, listen: false);
        LanSyncProvider.instance.onDeliveryBoysChanged = () {
          debugPrint('🔄 Refreshing delivery boys due to LAN sync update');
          deliveryBoyProvider.loadDeliveryBoys();
        };

        final menuProvider = Provider.of<MenuProvider>(context, listen: false);
        LanSyncProvider.instance.onMenuChanged = () async {
          debugPrint('🔄 Refreshing menu due to LAN sync update');
          await menuProvider.fetchMenu(forceRefresh: true);
          await menuProvider.fetchCategories(forceRefresh: true);
        };
        
        debugPrint('✅ LAN Sync UI listeners initialized');
      }
    } catch (e) {
      debugPrint('⚠️ Error initializing LAN sync listeners: $e');
    }
  }

  void _navigateToNextScreen() {
    try {
      final prefs = SharedPreferences.getInstance();

      prefs.then((prefs) async {
        if (!mounted) return;

        final isDeviceRegistered = prefs.getBool('device_registered') ?? false;
        final isCompanyRegistered = prefs.getBool('company_registered') ?? false;

        final isDemoMode = await DemoService.isDemoMode();
        final isDemoExpired = await DemoService.isDemoExpired();

        debugPrint('Navigation: device=$isDeviceRegistered, company=$isCompanyRegistered, demo=$isDemoMode, expired=$isDemoExpired');

        if (!mounted) return;

        if (!isDeviceRegistered) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DeviceRegistrationScreen()),
          );
          return;
        }

        if (!isCompanyRegistered && !isDemoMode) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnlineCompanyRegistrationScreen()),
          );
          return;
        }

        if (isCompanyRegistered || (isDemoMode && !isDemoExpired)) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);

          if (authProvider.isAuth) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
          return;
        }

        if (isDemoMode && isDemoExpired) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
          return;
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnlineCompanyRegistrationScreen()),
        );
      }).catchError((e) {
        debugPrint('❌ Error during navigation: $e');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DeviceRegistrationScreen()),
          );
        }
      });
    } catch (e) {
      debugPrint('❌ Error in navigation logic: $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DeviceRegistrationScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}


class AppRoutes {
  static const String login = '/login';
  static const String addperson = '/add-person';
  static const String dashboard = '/dashboard';
  static const String deviceRegistration = '/device-registration';
  static const String companyRegistration = '/company-registration';
  static const String onlineCompanyRegistration = '/online-company-registration';
  static const String demoRenewal = '/demo-renewal';
  static const String licenseRenewal = '/license-renewal';
  static const String settings = '/settings';
  static const String printerConfig = '/printer-settings';
  static const String expense = '/expense';
  static const String expenseHistory = '/expense-history';
  static const String reports = '/reports';
}