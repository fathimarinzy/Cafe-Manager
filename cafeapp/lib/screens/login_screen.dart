import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';
import '../utils/app_localization.dart';
import '../providers/settings_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true; // Track password visibility

  @override
  void initState() {
    super.initState();
    
    // Check if we're already authenticated, if yes, navigate to dashboard
    // This is a safety check in case the navigation in main.dart doesn't work
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuth) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (ctx) => const DashboardScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await Provider.of<AuthProvider>(context, listen: false).login(
        _usernameController.text,
        _passwordController.text,
      );
      if (!mounted) return; // Prevents using context if widget was unmounted

      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (ctx) => const DashboardScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Login Failed. Please check your credentials.'.tr())),
        );
      }
    } catch (error) {
      if (!mounted) return; // Another check before using context
    
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${error.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
     // Get settings provider to access business name
    final settingsProvider = Provider.of<SettingsProvider>(context);
    
    // Get business name from settings (or use default)
    final String businessName = settingsProvider.businessName.isNotEmpty 
        ? settingsProvider.businessName
        : 'SIMS RESTO CAFE';

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  businessName.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.blue[900] ?? Colors.blue,
                        width: 2.0
                      )
                    ),
                    labelStyle: const TextStyle(
                      color: Colors.black, // Default label color
                    ),
                    floatingLabelStyle: TextStyle(
                      color: Colors.blue[900], // Label color when focused
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    // Add suffix icon for toggling password visibility
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.blue[900] ?? Colors.blue,
                        width: 2.0
                      )
                    ),
                    labelStyle: const TextStyle(
                      color: Colors.black, // Default label color
                    ),
                    floatingLabelStyle: TextStyle(
                      color: Colors.blue[900], // Label color when focused
                    ),
                  ),
                  obscureText: _obscurePassword, // Use the state variable here
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom( // `style` moved before `child`
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.white,
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, 
                            color: Colors.blue[900]
                          ),
                        )
                      : Text(
                          'Login'.tr(), 
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}