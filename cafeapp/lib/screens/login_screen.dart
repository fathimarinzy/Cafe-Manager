import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';
import '../utils/app_localization.dart';
import '../providers/settings_provider.dart';
import '../utils/keyboard_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  
    // Check if we're already authenticated, if yes, navigate to dashboard
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
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TRIM THE INPUT VALUES HERE
      final trimmedUsername = _usernameController.text.trim();
      final trimmedPassword = _passwordController.text.trim();
      
      debugPrint('Attempting login with username: "$trimmedUsername"');
      debugPrint('Original username: "${_usernameController.text}"');
      debugPrint('Username length: ${_usernameController.text.length}, Trimmed length: ${trimmedUsername.length}');
      
      final success = await Provider.of<AuthProvider>(context, listen: false).login(
        trimmedUsername,
        trimmedPassword,
      );
      
      if (!mounted) return;

      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (ctx) => const DashboardScreen()),
        );
      } else {
        setState(() {
          _errorMessage = 'Invalid username or password'.tr();
          _isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
    
      setState(() {
        _errorMessage = 'Login Failed. Please check your credentials.'.tr();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get settings provider to access business name
    final settingsProvider = Provider.of<SettingsProvider>(context);
    
    // Get business name from settings (or use default)
    final String businessName = settingsProvider.businessName.isNotEmpty 
        ? settingsProvider.businessName
        : 'SIMS CAFE';

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
                
                // Username field
                DoubleTapKeyboardListener(
                  focusNode: _usernameFocus,
                  child: TextFormField(
                    controller: _usernameController,
                    focusNode: _usernameFocus,
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
                        color: Colors.black,
                      ),
                      floatingLabelStyle: TextStyle(
                        color: Colors.blue[900],
                      ),
                    ),
                    // Add input formatters to prevent/handle whitespace
                    onChanged: (value) {
                      // Optional: Remove this if you want to allow whitespace and just trim it
                      if (value.endsWith(' ')) {
                        _usernameController.text = value.trimRight();
                        _usernameController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _usernameController.text.length),
                        );
                      }
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your username'.tr();
                      }
                      return null;
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Password field
                DoubleTapKeyboardListener(
                  focusNode: _passwordFocus,
                  child: TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    decoration: InputDecoration(
                      labelText: 'Password'.tr(),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
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
                        color: Colors.black,
                      ),
                      floatingLabelStyle: TextStyle(
                        color: Colors.blue[900],
                      ),
                    ),
                    obscureText: _obscurePassword,
                    onChanged: (value) {
                      // Optional: Remove this if you want to allow whitespace and just trim it
                      if (value.endsWith(' ')) {
                        _passwordController.text = value.trimRight();
                        _passwordController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _passwordController.text.length),
                        );
                      }
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your password'.tr();
                      }
                      return null;
                    },
                  ),
                ),
                
                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Login button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
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
                            color: Colors.blue[900],
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