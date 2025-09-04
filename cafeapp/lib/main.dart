// import 'package:flutter/material.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         // This is the theme of your application.
//         //
//         // TRY THIS: Try running your application with "flutter run". You'll see
//         // the application has a purple toolbar. Then, without quitting the app,
//         // try changing the seedColor in the colorScheme below to Colors.green
//         // and then invoke "hot reload" (save your changes or press the "hot
//         // reload" button in a Flutter-supported IDE, or press "r" if you used
//         // the command line to start the app).
//         //
//         // Notice that the counter didn't reset back to zero; the application
//         // state is not lost during the reload. To reset the state, use hot
//         // restart instead.
//         //
//         // This works for code too, not just values: Most code changes can be
//         // tested with just a hot reload.
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//       ),
//       home: const MyHomePage(title: 'Flutter Demo Home Page'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   // This widget is the home page of your application. It is stateful, meaning
//   // that it has a State object (defined below) that contains fields that affect
//   // how it looks.

//   // This class is the configuration for the state. It holds the values (in this
//   // case the title) provided by the parent (in this case the App widget) and
//   // used by the build method of the State. Fields in a Widget subclass are
//   // always marked "final".

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;

//   void _incrementCounter() {
//     setState(() {
//       // This call to setState tells the Flutter framework that something has
//       // changed in this State, which causes it to rerun the build method below
//       // so that the display can reflect the updated values. If we changed
//       // _counter without calling setState(), then the build method would not be
//       // called again, and so nothing would appear to happen.
//       _counter++;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // This method is rerun every time setState is called, for instance as done
//     // by the _incrementCounter method above.
//     //
//     // The Flutter framework has been optimized to make rerunning build methods
//     // fast, so that you can just rebuild anything that needs updating rather
//     // than having to individually change instances of widgets.
//     return Scaffold(
//       appBar: AppBar(
//         // TRY THIS: Try changing the color here to a specific color (to
//         // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
//         // change color while the other colors stay the same.
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         // Here we take the value from the MyHomePage object that was created by
//         // the App.build method, and use it to set our appbar title.
//         title: Text(widget.title),
//       ),
//       body: Center(
//         // Center is a layout widget. It takes a single child and positions it
//         // in the middle of the parent.
//         child: Column(
//           // Column is also a layout widget. It takes a list of children and
//           // arranges them vertically. By default, it sizes itself to fit its
//           // children horizontally, and tries to be as tall as its parent.
//           //
//           // Column has various properties to control how it sizes itself and
//           // how it positions its children. Here we use mainAxisAlignment to
//           // center the children vertically; the main axis here is the vertical
//           // axis because Columns are vertical (the cross axis would be
//           // horizontal).
//           //
//           // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
//           // action in the IDE, or press "p" in the console), to see the
//           // wireframe for each widget.
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             const Text('You have pushed the button this many times:'),
//             Text(
//               '$_counter',
//               style: Theme.of(context).textTheme.headlineMedium,
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Increment',
//         child: const Icon(Icons.add),
//       ), // This trailing comma makes auto-formatting nicer for build methods.
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
import 'services/offline_sync_service.dart'; // NEW: Import sync service
import 'services/connectivity_monitor.dart'; // NEW: Import connectivity monitor
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Quick initialization - only critical components
  await quickInitialization();
  
   // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Error loading .env file: $e');
    // Handle the error appropriately for your app
  }

  runApp(const MyApp());
}

Future<void> quickInitialization() async {
  try {
    // Reduce overall timeout from 15s to 3s
    await Future.any([
      _performQuickInitialization(),
      Future.delayed(const Duration(seconds: 3), () {
        debugPrint('Warning: Quick initialization timed out - continuing anyway');
      }),
    ]);
  } catch (e) {
    debugPrint('Warning: Quick initialization error: $e');
    // Continue anyway - app should work in offline mode
  }
}

Future<void> _performQuickInitialization() async {
  // Initialize only critical local database
  await initializeLocalDatabase();
  
  // Initialize Firebase without waiting for connection test
  FirebaseService.initializeQuickly(); // Don't await this
  
  // NEW: Start connectivity monitoring for offline sync
  _startConnectivityMonitoring();
  
  debugPrint('Quick initialization completed');
}

// NEW: Start connectivity monitoring
void _startConnectivityMonitoring() {
  // Delay the start to avoid blocking app initialization
  Timer(const Duration(seconds: 5), () async {
    try {
      // Check if there's pending offline data that needs syncing
      final hasPendingData = await OfflineSyncService.hasPendingOfflineData();
      
      if (hasPendingData) {
        debugPrint('Found pending offline data - starting connectivity monitoring');
        ConnectivityMonitor.instance.startMonitoring();
        
        // Also start the auto-sync timer
        OfflineSyncService.autoSync();
      }
    } catch (e) {
      debugPrint('Error checking for pending sync data: $e');
    }
  });
}

Future<void> initializeLocalDatabase() async {
  try {
    // Get the database to initialize it
    final localRepo = LocalMenuRepository();
    await localRepo.database;
    
    // Initialize expense database
    final localExpenseRepo = LocalExpenseRepository();
    await localExpenseRepo.database;
    
    debugPrint('Local databases initialized');
  } catch (e) {
    debugPrint('Error initializing local databases: $e');
    rethrow; // This is critical - app can't work without local DB
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

// Updated app initializer with timeout handling
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
      // Reduce minimum splash time and total timeout
      final List<Future> futures = [
        Future.delayed(const Duration(milliseconds: 500)), // Reduced from 2 seconds
        _performAppInitialization(), // App initialization
      ];
      
      // Reduce total timeout from 12s to 4s
      await Future.any([
        Future.wait(futures),
        Future.delayed(const Duration(seconds: 4), () {
          debugPrint('Warning: App initialization timed out - proceeding anyway');
        }),
      ]);
      
    } catch (e) {
      debugPrint('Warning: App initialization error: $e');
    }
    
    // Always proceed to next screen quickly
    if (mounted) {
      _navigateToNextScreen();
    }
  }

  Future<void> _performAppInitialization() async {
    try {
      // Check device registration locally (fast)
      final prefs = await SharedPreferences.getInstance();
      final isDeviceRegistered = prefs.getBool('device_registered') ?? false;
      
      if (!isDeviceRegistered) {
        return; // Skip auth for new installations
      }
      
      // For registered devices, try quick auto-login
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        // Reduce auto-login timeout from 10s to 3s
        await Future.any([
          authProvider.tryAutoLogin(),
          Future.delayed(const Duration(seconds: 3), () {
            debugPrint('Warning: Auto-login timed out - proceeding to login screen');
            return false;
          }),
        ]);
      }
      
    } catch (e) {
      debugPrint('Warning: Error during app initialization: $e');
    }
  }

   void _navigateToNextScreen() {
    try {
      final prefs = SharedPreferences.getInstance();
      
      prefs.then((prefs) async {
        if (!mounted) return;
        
        final isDeviceRegistered = prefs.getBool('device_registered') ?? false;
        final isCompanyRegistered = prefs.getBool('company_registered') ?? false;
        
        // Check demo status
        final isDemoMode = await DemoService.isDemoMode();
        final isDemoExpired = await DemoService.isDemoExpired();
        
        debugPrint('Navigation check: device=$isDeviceRegistered, company=$isCompanyRegistered, demo=$isDemoMode, expired=$isDemoExpired');
        
        if (!mounted) return;

        if (!isDeviceRegistered) {
          // First time installation - go to device registration
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DeviceRegistrationScreen()),
          );
          return;
        }
        
        // Device is registered, check company registration or demo
        if (!isCompanyRegistered && !isDemoMode) {
          // Need company registration or demo
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnlineCompanyRegistrationScreen()),
          );
          return;
        }
        
        // Either company is registered or demo is active
        if (isCompanyRegistered || (isDemoMode && !isDemoExpired)) {
          // Check auth status for non-demo or active demo
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
        
        // Demo is expired - go directly to dashboard (restricted mode)
        if (isDemoMode && isDemoExpired) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
          return;
        }
        
        // Fallback - should not reach here but handle gracefully
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnlineCompanyRegistrationScreen()),
        );
        
      }).catchError((e) {
        debugPrint('Error during navigation: $e');
        // Fallback to device registration
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DeviceRegistrationScreen()),
          );
        }
      });
      
    } catch (e) {
      debugPrint('Error in navigation logic: $e');
      // Fallback navigation
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