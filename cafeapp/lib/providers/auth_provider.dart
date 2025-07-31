import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import 'dart:async';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  String _username = '';
  String _registrationMode = 'offline'; // 'online' or 'offline'
  Map<String, dynamic> _companyDetails = {};
  bool _isOfflineMode = false;

  // Getters
  bool get isAuth => _isAuthenticated;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String get username => _username;
  String get registrationMode => _registrationMode;
  Map<String, dynamic> get companyDetails => _companyDetails;
  bool get isOfflineMode => _isOfflineMode;

  // Default credentials
  static const String defaultUsername = 'admin';
  static const String defaultPassword = 'admin123';

  // Check for existing login and auto-login on app start
  Future<bool> tryAutoLogin() async {
    if (_isInitialized) return isAuth;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      debugPrint('🔵 Attempting auto-login...');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Get registration mode
      _registrationMode = prefs.getString('device_mode') ?? 'offline';
      debugPrint('📱 Registration mode: $_registrationMode');
      
      // Check if user is logged in
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      if (isLoggedIn) {
        // Get stored username
        _username = prefs.getString('username') ?? '';
        debugPrint('👤 Found stored login for: $_username');
        
        if (_registrationMode == 'online') {
          // For online mode, verify with Firebase (with timeout)
          await _verifyOnlineRegistration(prefs);
        } else {
          // For offline mode, use local authentication
          _isAuthenticated = true;
          _isOfflineMode = false;
          debugPrint('✅ Auto-login successful (offline mode)');
        }
        
        _isInitialized = true;
        _isLoading = false;
        notifyListeners();
        return _isAuthenticated;
      } else {
        debugPrint('ℹ️ No stored login found');
      }
    } catch (error) {
      debugPrint('❌ Auto-login error: $error');
      // Continue with offline mode if there's an error
      _isOfflineMode = true;
    }
    
    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Verify online registration with timeout
  Future<void> _verifyOnlineRegistration(SharedPreferences prefs) async {
    try {
      debugPrint('🔵 Verifying online registration...');
      
      final deviceId = prefs.getString('device_id') ?? '';
      if (deviceId.isNotEmpty) {
        // Add timeout for Firebase check
        final result = await Future.any([
          FirebaseService.getCompanyDetails(deviceId),
          Future.delayed(const Duration(seconds: 8), () {
            return {
              'success': true,
              'isRegistered': false,
              'isTimeout': true,
              'message': 'Connection timeout - using offline mode',
            };
          }),
        ]);

        if (result['success'] && result['isRegistered']) {
          _companyDetails = result;
          _isAuthenticated = true;
          _isOfflineMode = false;
          debugPrint('✅ Auto-login successful (online mode)');
          
          // Update last login (non-blocking)
          if (_companyDetails['companyId'] != null) {
            FirebaseService.updateLastLogin(_companyDetails['companyId']).catchError((e) {
              debugPrint('⚠️ Failed to update last login: $e');
            });
          }
        } else if (result['isTimeout'] == true || result['isOffline'] == true) {
          // Timeout or offline - use local auth
          _isAuthenticated = true;
          _isOfflineMode = true;
          debugPrint('✅ Auto-login successful (offline mode due to connection issues)');
        } else {
          // Not registered online
          _isAuthenticated = false;
          _isOfflineMode = false;
          debugPrint('❌ Auto-login failed - not registered online');
        }
      } else {
        // No device ID - treat as offline
        _isAuthenticated = true;
        _isOfflineMode = true;
        debugPrint('✅ Auto-login successful (offline mode - no device ID)');
      }
    } catch (e) {
      debugPrint('❌ Error verifying online registration: $e');
      // Fallback to offline mode
      _isAuthenticated = true;
      _isOfflineMode = true;
      debugPrint('✅ Auto-login successful (offline mode - error fallback)');
    }
  }

  // Login with credentials
  Future<bool> login(String username, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      debugPrint('🔵 Login attempt - Username: $username');
      debugPrint('📱 Registration mode: $_registrationMode');
      
      // Trim whitespace from inputs
      final trimmedUsername = username.trim();
      final trimmedPassword = password.trim();
      
      bool isValid = false;
      
      if (_registrationMode == 'online' && !_isOfflineMode) {
        // For online mode, check if company is registered in Firebase
        await _validateOnlineLogin(trimmedUsername, trimmedPassword);
        isValid = _isAuthenticated;
      } else {
        // For offline mode, use default credentials
        isValid = (trimmedUsername == defaultUsername && trimmedPassword == defaultPassword);
        _isOfflineMode = _registrationMode == 'offline' || _isOfflineMode;
      }
      
      debugPrint('📊 Login validation result: $isValid');
      
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
        
        debugPrint('✅ Login successful');
        return true;
      }
      
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Login failed - invalid credentials');
      return false;
    } catch (error) {
      debugPrint('❌ Login error: $error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Validate online login with timeout
  Future<void> _validateOnlineLogin(String username, String password) async {
    try {
      debugPrint('🔵 Validating online login...');
      
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? '';
      
      if (deviceId.isNotEmpty) {
        // Add timeout for Firebase check
        final result = await Future.any([
          FirebaseService.getCompanyDetails(deviceId),
          Future.delayed(const Duration(seconds: 8), () {
            return {
              'success': true,
              'isRegistered': false,
              'isTimeout': true,
            };
          }),
        ]);

        if (result['success'] && result['isRegistered']) {
          // Company is registered, use default credentials for login
          final isValid = (username == defaultUsername && password == defaultPassword);
          if (isValid) {
            _companyDetails = result;
            _isAuthenticated = true;
            _isOfflineMode = false;
            debugPrint('✅ Online login validation successful');
            
            // Update last login (non-blocking)
            if (_companyDetails['companyId'] != null) {
              FirebaseService.updateLastLogin(_companyDetails['companyId']).catchError((e) {
                debugPrint('⚠️ Failed to update last login: $e');
              });
            }
          } else {
            debugPrint('❌ Invalid credentials for registered company');
          }
        } else if (result['isTimeout'] == true || result['isOffline'] == true) {
          // Timeout - use offline validation
          final isValid = (username == defaultUsername && password == defaultPassword);
          if (isValid) {
            _isAuthenticated = true;
            _isOfflineMode = true;
            debugPrint('✅ Login successful in offline mode (timeout)');
          }
        } else {
          debugPrint('❌ Company not registered online');
        }
      } else {
        // No device ID - use offline validation
        final isValid = (username == defaultUsername && password == defaultPassword);
        if (isValid) {
          _isAuthenticated = true;
          _isOfflineMode = true;
          debugPrint('✅ Login successful in offline mode (no device ID)');
        }
      }
    } catch (e) {
      debugPrint('❌ Error during online login validation: $e');
      // Fallback to offline validation
      final isValid = (username == defaultUsername && password == defaultPassword);
      if (isValid) {
        _isAuthenticated = true;
        _isOfflineMode = true;
        debugPrint('✅ Login successful in offline mode (error fallback)');
      }
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      debugPrint('🔵 Logging out...');
      
      _isAuthenticated = false;
      _username = '';
      _companyDetails = {};
      _isOfflineMode = false;
      
      // Clear login state from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('username');
      
      notifyListeners();
      debugPrint('✅ Logout successful');
    } catch (error) {
      debugPrint('❌ Logout error: $error');
    }
  }

  // Get company status for display
  String getCompanyStatus() {
    if (_isOfflineMode) {
      return 'Offline Mode';
    }
    
    if (_registrationMode == 'online' && _companyDetails.isNotEmpty) {
      if (_companyDetails['isActive'] == true) {
        return 'Active';
      } else {
        return 'Inactive';
      }
    }
    return 'Local Mode';
  }

  // Get company name
  String getCompanyName() {
    if (_registrationMode == 'online' && _companyDetails.isNotEmpty) {
      return _companyDetails['customerName'] ?? 'Unknown Company';
    }
    return 'Local Business';
  }
}