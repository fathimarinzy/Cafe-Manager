
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/person_form_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/menu_provider.dart';
import 'providers/order_provider.dart';
import 'providers/person_provider.dart';
import 'services/api_service.dart'; 


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Using super parameter

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => AuthProvider()),
        ChangeNotifierProvider(create: (ctx) => MenuProvider()),
        ChangeNotifierProvider(create: (ctx) => OrderProvider()),
        ChangeNotifierProvider(create: (ctx) => PersonProvider(ApiService())),
      ],
      child: Consumer<AuthProvider>(
        builder: (ctx, auth, _) => MaterialApp(
          title: 'Cafe Management',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.white,
            fontFamily: 'Roboto',
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),

          home:  const LoginScreen(),
          debugShowCheckedModeBanner: false,
          routes: {
            AppRoutes.login: (ctx) => const LoginScreen(),
            AppRoutes.addperson: (ctx) => const PersonFormScreen(),
           
          },
        ),
      ),
    );
  }
}
class AppRoutes {
  static const String login = '/login';
  static const String addperson = '/add-person';
}