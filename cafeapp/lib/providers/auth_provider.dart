import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  String _username = '';

  // Getters
  bool get isAuth => _isAuthenticated;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String get username => _username;

  // Default credentials - in a real app, you might want to encrypt these
  // or store them in a more secure way
  static const String defaultUsername = 'admin';
  static const String defaultPassword = 'admin123';

  // Check for existing login and auto-login on app start
  Future<bool> tryAutoLogin() async {
    if (_isInitialized) return isAuth;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if user is logged in
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      if (isLoggedIn) {
        // Get stored username
        _username = prefs.getString('username') ?? '';
        _isAuthenticated = true;
        _isInitialized = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (error) {
      debugPrint('Auto-login error: $error');
    }
    
    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Login with local credentials - FIXED VERSION
  Future<bool> login(String username, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Add debugging
      debugPrint('Login attempt - Username: $username, Password length: ${password.length}');
      debugPrint('Expected - Username: $defaultUsername, Password: $defaultPassword');
      
      // Trim whitespace from inputs
      final trimmedUsername = username.trim();
      final trimmedPassword = password.trim();
      
      // Simple validation against default credentials
      bool isValid = (trimmedUsername == defaultUsername && trimmedPassword == defaultPassword);
    
      
      debugPrint('Login validation result: $isValid');
      
      if (isValid) {
        _isAuthenticated = true;
        _username = trimmedUsername;
        
        // Save login state to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('username', trimmedUsername);
        
        _isLoading = false;
        _isInitialized = true;
        notifyListeners();
        
        debugPrint('Login successful, auth state updated');
        return true;
      }
      
      _isLoading = false;
      notifyListeners();
      debugPrint('Login failed - invalid credentials');
      return false;
    } catch (error) {
      debugPrint('Login error: $error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      _isAuthenticated = false;
      _username = '';
      
      // Clear login state from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('username');
      
      notifyListeners();
    } catch (error) {
      debugPrint('Logout error: $error');
    }
  }
}