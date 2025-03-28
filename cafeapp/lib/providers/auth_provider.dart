import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  final ApiService _apiService = ApiService();

  User? get user => _user;

  bool get isAuth => _user != null;

  Future<bool> login(String username, String password) async {
    try {
    
      final user = await _apiService.login(username, password);
      if (user != null) {
        _user = user;
        notifyListeners();
        return true;
      }
      return false;
    } catch (error) {
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