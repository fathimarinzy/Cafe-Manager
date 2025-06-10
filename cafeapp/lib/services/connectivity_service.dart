// lib/services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  
  // Server connection check timeout
  final Duration _connectionTimeout = const Duration(seconds: 5);
  
  // Server test URL (change to your backend URL)
  final String _serverTestUrl = 'https://ftrinzy.pythonanywhere.com/api/test';
  
  // Connection check timestamp
  DateTime? _lastConnectionCheck;
  static const Duration _connectionCheckCooldown = Duration(seconds: 10);
  
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
    // Create a debounce timer for connectivity changes
  Timer? syncDebounce;
  bool hasSyncBeenTriggered = false;
  
    
    // Listen for connectivity changes with debounce
    _connectivity.onConnectivityChanged.listen((result) {
      debugPrint('Connectivity changed: $result');
      
      // Cancel any existing debounce timer
      _debounceTimer?.cancel();
      
      // Set a debounce to wait for the connection to stabilize
      _debounceTimer = Timer(const Duration(seconds: 2), () {
        if (result == ConnectivityResult.none) {
          _updateConnectionStatus(false);
           // Reset the sync trigger flag when disconnected
        hasSyncBeenTriggered = false;
        } else {
          checkConnection().then((isConnected) {
          // If we just came back online and sync hasn't been triggered yet
          if (isConnected && !_isConnected && !hasSyncBeenTriggered) {
            // Set the flag to prevent multiple sync triggers
            hasSyncBeenTriggered = true;
            
            // Cancel any existing sync debounce timer
            syncDebounce?.cancel();
            
            // Create a longer debounce for sync to ensure connection is stable
            syncDebounce = Timer(const Duration(seconds: 5), () {
              debugPrint('Connection restored, triggering sync (debounced)');
              
              // Publish the event only once with a delay
              _connectivityController.add(true);
              
              // Reset the flag after a delay to allow future sync events
              Timer(const Duration(seconds: 30), () {
                hasSyncBeenTriggered = false;
                debugPrint('Sync trigger flag reset, allowing future syncs');
              });
            });
          }
        });
        }
      });
    });
  }
  
  // Check current connection status with more detailed verification
  Future<bool> checkConnection() async {
    try {
      // Check if we've checked recently to avoid excessive checks
      if (_lastConnectionCheck != null) {
        final timeSinceLastCheck = DateTime.now().difference(_lastConnectionCheck!);
        if (timeSinceLastCheck < _connectionCheckCooldown) {
          debugPrint('Connection check too frequent, returning cached result: $_isConnected');
          return _isConnected;
        }
      }
      
      _lastConnectionCheck = DateTime.now();
      final result = await _connectivity.checkConnectivity();
      
      if (result == ConnectivityResult.none) {
        // We're definitely offline
        _updateConnectionStatus(false);
        _saveConnectionStatus(false);
        return false;
      } else {
        // We might be online, verify we can reach the server
        try {
          // Use a short timeout to avoid blocking the UI
          final response = await http.get(
            Uri.parse(_serverTestUrl),
            headers: {'Connection': 'keep-alive'},
          ).timeout(_connectionTimeout);
          
          final isConnected = response.statusCode == 200;
          _updateConnectionStatus(isConnected);
          _saveConnectionStatus(isConnected);
          return isConnected;
        } catch (e) {
          debugPrint('Server connection check failed: $e');
          _updateConnectionStatus(false);
          _saveConnectionStatus(false);
          return false;
        }
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      _updateConnectionStatus(false);
      _saveConnectionStatus(false);
      return false;
    }
  }
  
  // Save connection status to shared preferences
  Future<void> _saveConnectionStatus(bool isConnected) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_connected', isConnected);
      await prefs.setString('last_connection_check', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error saving connection status: $e');
    }
  }
  
  // Load connection status from shared preferences
  Future<void> loadSavedConnectionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStatus = prefs.getBool('is_connected');
      final lastCheckStr = prefs.getString('last_connection_check');
      
      if (savedStatus != null && lastCheckStr != null) {
        final lastCheck = DateTime.parse(lastCheckStr);
        final timeSince = DateTime.now().difference(lastCheck);
        
        // Only use cached value if it's recent (within 1 minute)
        if (timeSince < const Duration(minutes: 1)) {
          _updateConnectionStatus(savedStatus);
          debugPrint('Loaded saved connection status: $savedStatus');
          return;
        }
      }
      
      // If no recent saved status, check connection
      checkConnection();
    } catch (e) {
      debugPrint('Error loading saved connection status: $e');
      checkConnection();
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
  
  // Check for online status with custom server endpoint
  Future<bool> checkServerConnection(String url) async {
    try {
      // Use a short timeout to avoid blocking the UI
      final response = await http.get(
        Uri.parse(url),
        headers: {'Connection': 'keep-alive'},
      ).timeout(_connectionTimeout);
      
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Custom server connection check failed: $e');
      return false;
    }
  }
  
  // Dispose of resources
  void dispose() {
    _debounceTimer?.cancel();
    _connectivityController.close();
  }
}