import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';

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
  bool _obscurePassword = true; // Add this variable to track password visibility

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
      if (!mounted) return;//  Prevents using context if widget was unmounted

      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (ctx) => DashboardScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Failed. Please check your credentials.')),
        );
      }
    } catch (error) {
     if (!mounted) return; // ✅ Another check before using context
    
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(' error :${error.toString()}')),
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
    return Scaffold(
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 400),
          padding: EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cafe Management',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                    focusedBorder: OutlineInputBorder(borderSide:BorderSide(color:Colors.blue[900]??Colors.blue,width:2.0)),
              
                    labelStyle: TextStyle(
                      color: Colors.black, // Default label color
                    ),
                    floatingLabelStyle: TextStyle(
                      color: Colors.blue[900], // Label color when focused
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
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
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue[900]??Colors.blue,width: 2.0)),
                     labelStyle: TextStyle(
                      color: Colors.black, // Default label color
                    ),
                    floatingLabelStyle: TextStyle(
                      color: Colors.blue[900], // Label color when focused
                    ),
                  ),
                  obscureText: _obscurePassword, // Use the state variable here
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom( // ✅ `style` moved before `child`
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Login', style: TextStyle(fontSize: 16,
                             color: Colors.blue[900])),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}