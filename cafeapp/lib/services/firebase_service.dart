import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'dart:math';
import 'dart:async';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _companiesCollection = 'registered_companies';
  static bool _isInitialized = false;
  static bool _isOfflineMode = false;
  static Completer<void>? _initCompleter;

  
  // Quick initialization that doesn't block app startup
  static void initializeQuickly() {
    if (_isInitialized || _initCompleter != null) return;
    
    _initCompleter = Completer<void>();
    
    // Initialize in background without blocking
    _backgroundInitialization().then((_) {
      if (!_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
    }).catchError((e) {
      debugPrint('⚠️ Background Firebase initialization failed: $e');
      _isOfflineMode = true;
      _isInitialized = true;
      if (!_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
    });
  }

  // Background initialization with shorter timeout
  static Future<void> _backgroundInitialization() async {
    try {
      debugPrint('🔵 Background Firebase initialization...');
      
      // Reduce Firebase init timeout from 10s to 5s
      await Future.any([
        Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
        Future.delayed(const Duration(seconds: 5), () {
          throw TimeoutException('Firebase initialization timed out', const Duration(seconds: 5));
        }),
      ]);
      
      _isInitialized = true;
      _isOfflineMode = false;
      debugPrint('✅ Background Firebase initialized successfully');
      
      // Enable offline persistence (non-blocking)
      _setupOfflinePersistence();
      
    } catch (e) {
      debugPrint('⚠️ Background Firebase initialization failed: $e');
      _isOfflineMode = true;
      _isInitialized = true;
    }
  }

  // Setup offline persistence without blocking
  static void _setupOfflinePersistence() {
    try {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('✅ Firestore offline persistence enabled');
    } catch (e) {
      debugPrint('⚠️ Could not enable Firestore offline persistence: $e');
    }
  }

  // Wait for initialization if needed (with timeout)
  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    
    if (_initCompleter != null) {
      try {
        // Wait max 2 seconds for background init to complete
        await Future.any([
          _initCompleter!.future,
          Future.delayed(const Duration(seconds: 2), () {
            debugPrint('⚠️ Firebase initialization still pending, continuing anyway');
          }),
        ]);
      } catch (e) {
        debugPrint('⚠️ Error waiting for Firebase initialization: $e');
      }
    }
    
    if (!_isInitialized) {
      _isOfflineMode = true;
      _isInitialized = true;
    }
  }

  // Check if Firebase is available
  static bool get isFirebaseAvailable => _isInitialized && !_isOfflineMode;



  // Initialize Firebase with timeout and offline handling
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔵 Initializing Firebase...');
      
      // Add timeout to Firebase initialization
      await Future.any([
        Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
        Future.delayed(const Duration(seconds: 10), () {
          throw TimeoutException('Firebase initialization timed out', const Duration(seconds: 10));
        }),
      ]);
      
      _isInitialized = true;
      _isOfflineMode = false;
      debugPrint('✅ Firebase initialized successfully');
      
      // Enable offline persistence for Firestore
      try {
        _firestore.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        debugPrint('✅ Firestore offline persistence enabled');
      } catch (e) {
        debugPrint('⚠️ Could not enable Firestore offline persistence: $e');
      }
      
    } catch (e) {
      debugPrint('⚠️ Firebase initialization failed (likely offline): $e');
      _isOfflineMode = true;
      _isInitialized = true; // Mark as initialized to prevent blocking
      
      // Don't rethrow - allow app to continue in offline mode
    }
  }
  // Generate 5 random registration keys
  static List<String> generateRegistrationKeys() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    List<String> keys = [];
    
    for (int i = 0; i < 5; i++) {
      String key = '';
      for (int j = 0; j < 6; j++) {
        key += chars[random.nextInt(chars.length)];
      }
      keys.add(key);
    }
    
    return keys;
  }

  // Register company with Firebase (with offline handling)
   static Future<Map<String, dynamic>> registerCompany({
    required List<String> registrationKeys,
    required String customerName,
    required String customerAddress,
    required String customerPhone,
    required String deviceId,
  }) async {
    // Ensure Firebase is initialized first
    await ensureInitialized();
    
    if (!isFirebaseAvailable) {
      return {
        'success': false,
        'message': 'No internet connection. Please connect to the internet and try again.',
        'isOffline': true,
      };
    }

    try {
      debugPrint('🔵 Registering company with Firebase...');
      
      // Reduce registration timeout from 15s to 8s
      final result = await Future.any([
        _performRegistration(
          registrationKeys: registrationKeys,
          customerName: customerName,
          customerAddress: customerAddress,
          customerPhone: customerPhone,
          deviceId: deviceId,
        ),
        Future.delayed(const Duration(seconds: 8), () {
          throw TimeoutException('Registration timed out', const Duration(seconds: 8));
        }),
      ]);

      return result;
    } catch (e) {
      debugPrint('❌ Error registering company: $e');
      
      if (e is TimeoutException) {
        return {
          'success': false,
          'message': 'Registration timed out. Please check your internet connection and try again.',
          'isTimeout': true,
        };
      }
      
      return {
        'success': false,
        'message': 'Registration failed: ${e.toString()}',
      };
    }
  }

  // Actual registration logic (separated for timeout handling)
  static Future<Map<String, dynamic>> _performRegistration({
    required List<String> registrationKeys,
    required String customerName,
    required String customerAddress,
    required String customerPhone,
    required String deviceId,
  }) async {
    // Create company data
    final companyData = {
      'registrationKeys': registrationKeys,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'customerPhone': customerPhone,
      'deviceId': deviceId,
      'isActive': true,
      'registeredAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    // Add to Firestore
    final docRef = await _firestore
        .collection(_companiesCollection)
        .add(companyData);

    debugPrint('✅ Company registered with ID: ${docRef.id}');

    return {
      'success': true,
      'companyId': docRef.id,
      'message': 'Company registered successfully',
    };
  }

  // Check if company is registered (with offline handling)
 static Future<Map<String, dynamic>> getCompanyDetails(String deviceId) async {
    // Ensure Firebase is initialized first
    await ensureInitialized();
    
    if (!isFirebaseAvailable) {
      return {
        'success': true,
        'isRegistered': false,
        'isOffline': true,
        'message': 'Offline mode - Firebase not available',
      };
    }

    try {
      debugPrint('🔵 Checking company registration for device: $deviceId');
      
      // Reduce company details timeout from 10s to 5s
      final result = await Future.any([
        _getCompanyDetailsFromFirestore(deviceId),
        Future.delayed(const Duration(seconds: 5), () {
          throw TimeoutException('Company details check timed out', const Duration(seconds: 5));
        }),
      ]);

      return result;
    } catch (e) {
      debugPrint('⚠️ Error getting company details: $e');
      
      if (e is TimeoutException) {
        return {
          'success': true,
          'isRegistered': false,
          'isTimeout': true,
          'message': 'Connection timeout - using offline mode',
        };
      }
      
      return {
        'success': false,
        'message': 'Error fetching company details: $e',
      };
    }
  }

  // Actual company details fetch (separated for timeout handling)
  static Future<Map<String, dynamic>> _getCompanyDetailsFromFirestore(String deviceId) async {
    final querySnapshot = await _firestore
        .collection(_companiesCollection)
        .where('deviceId', isEqualTo: deviceId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final data = doc.data();
      
      debugPrint('✅ Found company registration for device: $deviceId');
      
      return {
        'success': true,
        'isRegistered': true,
        'companyId': doc.id,
        'customerName': data['customerName'] ?? '',
        'customerAddress': data['customerAddress'] ?? '',
        'customerPhone': data['customerPhone'] ?? '',
        'registrationKeys': List<String>.from(data['registrationKeys'] ?? []),
        'isActive': data['isActive'] ?? false,
        'registeredAt': data['registeredAt'],
        'lastLoginAt': data['lastLoginAt'],
      };
    } else {
      debugPrint('⚠️ No company found for device: $deviceId');
      return {
        'success': true,
        'isRegistered': false,
        'message': 'No company found for this device',
      };
    }
  }

  // Update last login time (with offline handling)
  static Future<void> updateLastLogin(String companyId) async {
    if (!isFirebaseAvailable) {
      debugPrint('⚠️ Skipping last login update - offline mode');
      return;
    }

    try {
      await Future.any([
        _firestore
            .collection(_companiesCollection)
            .doc(companyId)
            .update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        }),
        Future.delayed(const Duration(seconds: 5), () {
          throw TimeoutException('Update last login timed out');
        }),
      ]);
      debugPrint('✅ Last login updated for company: $companyId');
    } catch (e) {
      debugPrint('⚠️ Error updating last login (non-critical): $e');
      // Don't throw error for this non-critical operation
    }
  }

  // Get device ID
  static String generateDeviceId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    String deviceId = 'device_';
    
    for (int i = 0; i < 16; i++) {
      deviceId += chars[random.nextInt(chars.length)];
    }
    
    return deviceId;
  }

  // Validate registration keys
  static bool validateRegistrationKeys(
    List<String> generatedKeys,
    List<String> userEnteredKeys,
  ) {
    if (generatedKeys.length != userEnteredKeys.length) {
      return false;
    }

    for (int i = 0; i < generatedKeys.length; i++) {
      if (generatedKeys[i].toUpperCase() != userEnteredKeys[i].toUpperCase()) {
        return false;
      }
    }

    return true;
  }
}