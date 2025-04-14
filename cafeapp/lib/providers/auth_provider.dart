import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  final ApiService _apiService = ApiService();
  bool _isInitialized = false;
  bool _isLoading = false;

  User? get user => _user;
  bool get isAuth => _user != null;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  // Check for existing token and auto-login on app start
  Future<bool> tryAutoLogin() async {
    if (_isInitialized) return isAuth;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final token = await _apiService.getToken();
      
      if (token != null && token.isNotEmpty) {
        // Validate token by getting user information
        final user = await _apiService.getUserInfo();
        if (user != null) {
          _user = user;
          _isInitialized = true;
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          // Token exists but is invalid - clean up
          await _apiService.deleteToken();
        }
      }
    } catch (error) {
      debugPrint('Auto-login error: $error');
      // In case of error, delete potentially corrupted token
      await _apiService.deleteToken();
    }
    
    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String username, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final user = await _apiService.login(username, password);
      if (user != null) {
        _user = user;
        _isInitialized = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _user = null;
    _apiService.deleteToken();
    notifyListeners();
  }

  String? get token {
    if (_user == null) {
      return null;
    }
    return _user!.token;
  }
}