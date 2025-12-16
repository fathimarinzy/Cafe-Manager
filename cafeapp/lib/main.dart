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

import 'repositories/local_menu_repository.dart';
import 'repositories/local_expense_repository.dart';
import 'services/firebase_service.dart';
import 'services/demo_service.dart';
import 'services/offline_sync_service.dart';
import 'services/connectivity_monitor.dart';
import 'services/device_sync_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
   await _setupPortableDataPaths();
  // CRITICAL FIX: Initialize database with proper error handling
  bool isDatabaseInitialized = false;
  try {
    await DatabaseHelper.initializePlatform();
    isDatabaseInitialized = true;
    debugPrint('✅ Database helper initialized for platform: ${DatabaseHelper.platformName}');
  } catch (e) {
    debugPrint('⚠️ Error initializing database helper: $e');
    if (!DatabaseHelper.isSupported) {
      debugPrint('❌ SQLite is not supported on this platform');
      // For web, show error. For desktop, continue with warning
      if (!isDesktop()) {
        // runApp(const UnsupportedPlatformApp());
        return;
      }
    }
  }

  // Desktop-specific window configuration
  if (isDesktop()) {
    await configureDesktopWindow();
  }

  // Quick initialization - only critical components
  await quickInitialization(isDatabaseInitialized);

  // Load environment variables with better error handling
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ Environment variables loaded');
  } catch (e) {
    debugPrint('⚠️ Error loading .env file: $e - Continuing without .env');
  }

  runApp(const MyApp());
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
      
      debugPrint('📁 Portable data directory: ${portableDataDir.path}');
    }
  } catch (e) {
    debugPrint('⚠️ Portable data setup error: $e');
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

    debugPrint('✅ Desktop window configured');
  } catch (e) {
    debugPrint('⚠️ Error configuring desktop window: $e');
  }
}

Future<void> quickInitialization(bool isDatabaseInitialized) async {
  try {
    await Future.any([
      _performQuickInitialization(isDatabaseInitialized),
      Future.delayed(const Duration(seconds: 3), () {
        debugPrint('⚠️ Quick initialization timed out - continuing anyway');
      }),
    ]);
  } catch (e) {
    debugPrint('⚠️ Quick initialization error: $e');
  }
}

Future<void> _performQuickInitialization(bool isDatabaseInitialized) async {
  // Initialize local database only if it was properly initialized
  if (isDatabaseInitialized) {
    try {
      await initializeLocalDatabase();
    } catch (e) {
      debugPrint('⚠️ Could not initialize local database: $e');
    }
  }

  // Initialize Firebase - works for all platforms now
  try {
    debugPrint('🔥 Initializing Firebase for all platforms...');
    FirebaseService.initializeQuickly();
    debugPrint('✅ Firebase initialization started');
  } catch (e) {
    debugPrint('⚠️ Firebase initialization error: $e');
  }

  // Start connectivity monitoring with delay
  _startConnectivityMonitoring();

  debugPrint('✅ Quick initialization completed');
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
      debugPrint('✅ Internet connection verified');
      return true;
    }
  } catch (e) {
    debugPrint('❌ No internet connection: $e');
  }
  return false;
}

void _startConnectivityMonitoring() {
  Timer(const Duration(seconds: 5), () async {
    try {
      // Check internet connectivity first on desktop
      if (isDesktop()) {
        final hasInternet = await _checkInternetConnection();
        debugPrint('Connectivity check: $hasInternet');
      }
      
      final hasPendingData = await OfflineSyncService.hasPendingOfflineData();

      if (hasPendingData) {
        debugPrint('📡 Found pending offline data - starting connectivity monitoring');
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

    debugPrint('✅ Local databases initialized');
  } catch (e) {
    debugPrint('❌ Error initializing local databases: $e');
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => AuthProvider()),
        ChangeNotifierProvider(create: (ctx) => MenuProvider()),
        ChangeNotifierProvider(create: (ctx) => OrderProvider()),
        ChangeNotifierProvider(create: (ctx) => PersonProvider()),
        ChangeNotifierProvider(create: (ctx) => TableProvider()),
        ChangeNotifierProvider(create: (ctx) => OrderHistoryProvider()),
        ChangeNotifierProvider(create: (ctx) => SettingsProvider()),
        ChangeNotifierProvider(create: (ctx) => LogoProvider()),
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
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final List<Future> futures = [
        Future.delayed(const Duration(milliseconds: 500)),
        _performAppInitialization(),
      ];

      await Future.any([
        Future.wait(futures),
        Future.delayed(const Duration(seconds: 4), () {
          debugPrint('⚠️ App initialization timed out - proceeding anyway');
        }),
      ]);
    } catch (e) {
      debugPrint('⚠️ App initialization error: $e');
    }

    if (mounted) {
      _navigateToNextScreen();
    }
  }

  Future<void> _performAppInitialization() async {
    try {
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
      final prefs = await SharedPreferences.getInstance();
      final syncEnabled = prefs.getBool('device_sync_enabled') ?? false;
      final companyId = prefs.getString('company_id') ?? '';
      
      if (syncEnabled && companyId.isNotEmpty) {
        // 🆕 SET UP ORDER CHANGE CALLBACK
        if (mounted) {
          final orderHistoryProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
          DeviceSyncService.setOnOrdersChangedCallback(() {
            debugPrint('🔄 Refreshing order history due to sync update');
            orderHistoryProvider.loadOrders();
          });
          
          final tableProvider = Provider.of<TableProvider>(context, listen: false);
          DeviceSyncService.setOnTablesChangedCallback(() {
             debugPrint('🔄 Refreshing tables due to sync update');
             tableProvider.refreshTables();
          });
        }
        DeviceSyncService.startAutoSync(companyId);
        debugPrint('✅ Device sync initialized');
        // 🆕 ALSO INITIALIZE MENU PROVIDER WITH SYNC
        if (mounted) {
        final menuProvider = Provider.of<MenuProvider>(context, listen: false);
        await menuProvider.setSyncEnabled(true);
        debugPrint('✅ Menu provider sync enabled');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error initializing device sync: $e');
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