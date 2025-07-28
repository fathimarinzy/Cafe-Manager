import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_password.dart';
import 'api_service.dart';

class SettingsPasswordService {
  static const String _passwordsKey = 'settings_passwords';
  static const String _apiBaseEndpoint = '/settings-passwords';
  static const String _verifyEndpoint = '/verify-settings-password';
  static const String _initEndpoint = '/init-settings-passwords';
  
  final ApiService _apiService = ApiService();

  // Initialize default passwords if none exist
  Future<void> initializeDefaultPasswords() async {
    try {
      // Try to initialize passwords in the backend first
      final token = await _apiService.getToken();
      if (token != null) {
        try {
          final response = await http.get(
            Uri.parse(ApiService.baseUrl + _initEndpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          
          if (response.statusCode == 200) {
            // Successfully initialized in backend, now fetch them
            final backendPasswords = await getPasswordsFromBackend();
            if (backendPasswords.isNotEmpty) {
              // Save to local storage
              await savePasswordsToPrefs(backendPasswords);
              return;
            }
          }
        } catch (e) {
          debugPrint('Error initializing passwords in backend: $e');
          // Continue with local initialization
        }
      }
      
      // If backend initialization fails or not available, use local storage
      final prefs = await SharedPreferences.getInstance();
      final passwordsJson = prefs.getString(_passwordsKey);
      
      if (passwordsJson == null) {
        // Set default passwords
        final defaultPasswords = [
          SettingsPassword(
            id: 1,
            password: "1234", // Default password for staff
            userType: "staff",
            isActive: true,
          ),
          SettingsPassword(
            id: 2,
            password: "admin@cafeplus25!", // Default password for owner
            userType: "owner",
            isActive: true,
          ),
        ];
        
        // Save default passwords
        await savePasswordsToPrefs(defaultPasswords);
        
        // Try to sync with backend
        await syncPasswords();
      }
    } catch (e) {
      debugPrint('Error initializing default passwords: $e');
    }
  }

  // Save passwords to shared preferences
  Future<void> savePasswordsToPrefs(List<SettingsPassword> passwords) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final passwordsList = passwords.map((p) => p.toJson()).toList();
      await prefs.setString(_passwordsKey, jsonEncode(passwordsList));
    } catch (e) {
      debugPrint('Error saving passwords: $e');
    }
  }

  // Get passwords from shared preferences
  Future<List<SettingsPassword>> getPasswordsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final passwordsJson = prefs.getString(_passwordsKey);
      
      if (passwordsJson != null) {
        final List<dynamic> decodedList = jsonDecode(passwordsJson);
        return decodedList.map((json) => SettingsPassword.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error getting passwords from prefs: $e');
    }
    
    // Return empty list if none exist or there was an error
    return [];
  }
  
  // Get passwords from backend
  Future<List<SettingsPassword>> getPasswordsFromBackend() async {
    try {
      final token = await _apiService.getToken();
      if (token == null) return [];
      
      final response = await http.get(
        Uri.parse(ApiService.baseUrl + _apiBaseEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => SettingsPassword.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error getting passwords from backend: $e');
    }
    
    return [];
  }

  // Verify password and return userType if valid
  Future<String?> verifyPassword(String password) async {
    try {
      // Try to verify with backend first
      final token = await _apiService.getToken();
      if (token != null) {
        try {
          final response = await http.post(
            Uri.parse(ApiService.baseUrl + _verifyEndpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'password': password}),
          );
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['valid'] == true) {
              return data['userType'];
            }
          }
        } catch (e) {
          debugPrint('Error verifying password with backend: $e');
          // Continue with local verification
        }
      }
      
      // If backend verification fails or not available, use local storage
      final passwords = await getPasswordsFromPrefs();
      
      for (var pwd in passwords) {
        if (pwd.isActive && pwd.password == password) {
          return pwd.userType;
        }
      }
      
      return null; // Password not found or not active
    } catch (e) {
      debugPrint('Error verifying password: $e');
      return null;
    }
  }

  // Update password
  Future<bool> updatePassword(int id, String newPassword) async {
    try {
      // Get current passwords
      final passwords = await getPasswordsFromPrefs();
      final index = passwords.indexWhere((p) => p.id == id);
      
      if (index >= 0) {
        passwords[index] = SettingsPassword(
          id: passwords[index].id,
          password: newPassword,
          userType: passwords[index].userType,
          isActive: passwords[index].isActive,
        );
        
        // Save to local storage
        await savePasswordsToPrefs(passwords);
        
        // Try to update in backend
        final token = await _apiService.getToken();
        if (token != null) {
          try {
            final response = await http.put(
              Uri.parse(ApiService.baseUrl + _apiBaseEndpoint),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(passwords.map((p) => p.toJson()).toList()),
            );
            
            if (response.statusCode != 200) {
              debugPrint('Backend password update failed: ${response.body}');
            }
          } catch (e) {
            debugPrint('Error updating password in backend: $e');
            // Continue as we've already updated local storage
          }
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error updating password: $e');
      return false;
    }
  }

  // Sync passwords with backend if available
  Future<bool> syncPasswords() async {
    try {
      final token = await _apiService.getToken();
      if (token == null) return false;
      
      // Get local passwords
      final localPasswords = await getPasswordsFromPrefs();
      if (localPasswords.isEmpty) return false;
      
      // Try to update backend
      try {
        final response = await http.put(
          Uri.parse(ApiService.baseUrl + _apiBaseEndpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(localPasswords.map((p) => p.toJson()).toList()),
        );
        
        return response.statusCode == 200;
      } catch (e) {
        debugPrint('Error syncing passwords with backend: $e');
        return false;
      }
    } catch (e) {
      debugPrint('Error in syncPasswords: $e');
      return false;
    }
  }
}