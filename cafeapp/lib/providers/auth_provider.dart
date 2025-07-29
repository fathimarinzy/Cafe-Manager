// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  String _username = '';
  String _registrationMode = 'offline'; // 'online' or 'offline'
  Map<String, dynamic> _companyDetails = {};

  // Getters
  bool get isAuth => _isAuthenticated;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String get username => _username;
  String get registrationMode => _registrationMode;
  Map<String, dynamic> get companyDetails => _companyDetails;

  // Default credentials for offline mode
  static const String defaultUsername = 'admin';
  static const String defaultPassword = 'admin123';

  // Check for existing login and auto-login on app start
  Future<bool> tryAutoLogin() async {
    if (_isInitialized) return isAuth;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get registration mode
      _registrationMode = prefs.getString('device_mode') ?? 'offline';
      
      // Check if user is logged in
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      if (isLoggedIn) {
        // Get stored username
        _username = prefs.getString('username') ?? '';
        
        if (_registrationMode == 'online') {
          // For online mode, verify with Firebase
          final deviceId = prefs.getString('device_id') ?? '';
          if (deviceId.isNotEmpty) {
            final result = await FirebaseService.getCompanyDetails(deviceId);
            if (result['success'] && result['isRegistered']) {
              _companyDetails = result;
              _isAuthenticated = true;
              // Update last login
              if (_companyDetails['companyId'] != null) {
                await FirebaseService.updateLastLogin(_companyDetails['companyId']);
              }
            }
          }
        } else {
          // For offline mode, use local authentication
          _isAuthenticated = true;
        }
        
        _isInitialized = true;
        _isLoading = false;
        notifyListeners();
        return _isAuthenticated;
      }
    } catch (error) {
      debugPrint('Auto-login error: $error');
    }
    
    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Login with credentials
  Future<bool> login(String username, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Add debugging
      debugPrint('Login attempt - Username: $username, Password length: ${password.length}');
      debugPrint('Registration mode: $_registrationMode');
      
      // Trim whitespace from inputs
      final trimmedUsername = username.trim();
      final trimmedPassword = password.trim();
      
      bool isValid = false;
      
      if (_registrationMode == 'online') {
        // For online mode, check if company is registered in Firebase
        final prefs = await SharedPreferences.getInstance();
        final deviceId = prefs.getString('device_id') ?? '';
        
        if (deviceId.isNotEmpty) {
          final result = await FirebaseService.getCompanyDetails(deviceId);
          if (result['success'] && result['isRegistered']) {
            // Company is registered, use default credentials for login
            isValid = (trimmedUsername == defaultUsername && trimmedPassword == defaultPassword);
            if (isValid) {
              _companyDetails = result;
              // Update last login
              if (_companyDetails['companyId'] != null) {
                await FirebaseService.updateLastLogin(_companyDetails['companyId']);
              }
            }
          }
        }
      } else {
        // For offline mode, use default credentials
        isValid = (trimmedUsername == defaultUsername && trimmedPassword == defaultPassword);
      }
      
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
      _companyDetails = {};
      
      // Clear login state from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('username');
      
      notifyListeners();
    } catch (error) {
      debugPrint('Logout error: $error');
    }
  }

  // Get company status for display
  String getCompanyStatus() {
    if (_registrationMode == 'online' && _companyDetails.isNotEmpty) {
      if (_companyDetails['isActive'] == true) {
        return 'Active';
      } else {
        return 'Inactive';
      }
    }
    return 'Offline Mode';
  }

  // Get company name
  String getCompanyName() {
    if (_registrationMode == 'online' && _companyDetails.isNotEmpty) {
      return _companyDetails['customerName'] ?? 'Unknown Company';
    }
    return 'Local Business';
  }

  // Check if device is registered with Firebase (for online mode)
  Future<Map<String, dynamic>> checkOnlineRegistration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? '';
      
      if (deviceId.isEmpty) {
        return {
          'success': false,
          'message': 'Device ID not found',
        };
      }
      
      return await FirebaseService.getCompanyDetails(deviceId);
    } catch (e) {
      debugPrint('Error checking online registration: $e');
      return {
        'success': false,
        'message': 'Error checking registration: $e',
      };
    }
  }
}