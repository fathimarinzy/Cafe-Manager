// lib/services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  // Singleton pattern with private constructor
  static final ConnectivityService _instance = ConnectivityService._internal();
  
  // Factory constructor that returns the singleton instance
  factory ConnectivityService() => _instance;
  
  // Private constructor
  ConnectivityService._internal();
  
  final Connectivity _connectivity = Connectivity();
  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  // Debounce to prevent rapid state changes
  Timer? _debounceTimer;
  
  // Flag to prevent multiple initializations
  bool _isInitialized = false;
  
  // Initialize the service
  void initialize() {
    // Only initialize once
    if (_isInitialized) {
      debugPrint('ConnectivityService already initialized, skipping');
      return;
    }
    
    _isInitialized = true;
    debugPrint('Initializing ConnectivityService');
    
    // Check initial connection status
    checkConnection();
    
    // Listen for connectivity changes with debounce
    _connectivity.onConnectivityChanged.listen((result) {
      debugPrint('Connectivity changed: $result');
      
      // Cancel any existing debounce timer
      _debounceTimer?.cancel();
      
      // Set a debounce to wait for the connection to stabilize
      _debounceTimer = Timer(const Duration(seconds: 2), () {
        if (result == ConnectivityResult.none) {
          _updateConnectionStatus(false);
        } else {
          checkConnection();
        }
      });
    });
  }
  
  // Check current connection status
  Future<bool> checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      
      if (result == ConnectivityResult.none) {
        // We're definitely offline
        _updateConnectionStatus(false);
        return false;
      } else {
        // We might be online, verify we can reach the server
        try {
          // Use a short timeout to avoid blocking the UI
          final response = await http.get(
            Uri.parse('https://ftrinzy.pythonanywhere.com/api/test'),
            headers: {'Connection': 'keep-alive'},
          ).timeout(const Duration(seconds: 5));
          
          final isConnected = response.statusCode == 200;
          _updateConnectionStatus(isConnected);
          return isConnected;
        } catch (e) {
          debugPrint('Server connection check failed: $e');
          _updateConnectionStatus(false);
          return false;
        }
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      _updateConnectionStatus(false);
      return false;
    }
  }
  
  // Update connection status based on connectivity result
  void _updateConnectionStatus(bool isConnected) {
    // Only notify if status has changed
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      _connectivityController.add(_isConnected);
      debugPrint('Connectivity status updated: ${_isConnected ? 'Online' : 'Offline'}');
    }
  }
  
  // Manually set connection status (for testing)
  void setConnectionStatus(bool isConnected) {
    _updateConnectionStatus(isConnected);
  }
  
  // Dispose of resources
  void dispose() {
    _debounceTimer?.cancel();
    _connectivityController.close();
  }
}