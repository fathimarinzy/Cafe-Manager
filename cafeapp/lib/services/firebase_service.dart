import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'dart:math';
import 'dart:async';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _companiesCollection = 'registered_companies';
  static const String _pendingRegistrationsCollection = 'pending_registrations';
  static const String _demoRegistrationsCollection = 'demo_registrations'; // NEW: Demo collection
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

  // NEW: Store demo registration in Firebase
  static Future<Map<String, dynamic>> storeDemoRegistration({
    required String businessName,
    String? secondBusinessName,
    required String businessAddress,
    required String businessPhone,
    required String businessEmail,
    required String deviceId,
  }) async {
    await ensureInitialized();
    
    if (!isFirebaseAvailable) {
      return {
        'success': false,
        'message': 'No internet connection. Demo will work in offline mode.',
        'isOffline': true,
      };
    }

    try {
      debugPrint('🔵 Storing demo registration in Firebase...');
      
      // Check if device already has a demo registration
      final existingDemo = await _firestore
          .collection(_demoRegistrationsCollection)
          .where('deviceId', isEqualTo: deviceId)
          .limit(1)
          .get();

      if (existingDemo.docs.isNotEmpty) {
        // Update existing demo registration
        final docId = existingDemo.docs.first.id;
        await _firestore
            .collection(_demoRegistrationsCollection)
            .doc(docId)
            .update({
          'businessName': businessName,
          'secondBusinessName': secondBusinessName ?? '',
          'businessAddress': businessAddress,
          'businessPhone': businessPhone,
          'businessEmail': businessEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('✅ Demo registration updated with ID: $docId');
        return {
          'success': true,
          'companyId': docId,
          'message': 'Demo registration updated successfully',
        };
      } else {
        // Create new demo registration
        final demoData = {
          'businessName': businessName,
          'secondBusinessName': secondBusinessName ?? '',
          'businessAddress': businessAddress,
          'businessPhone': businessPhone,
          'businessEmail': businessEmail,
          'deviceId': deviceId,
          'registrationType': 'demo',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
        };

        final docRef = await _firestore
            .collection(_demoRegistrationsCollection)
            .add(demoData);

        debugPrint('✅ Demo registration stored with ID: ${docRef.id}');
        return {
          'success': true,
          'companyId': docRef.id,
          'message': 'Demo registration successful',
        };
      }
    } catch (e) {
      debugPrint('❌ Error storing demo registration: $e');
      return {
        'success': false,
        'message': 'Failed to store demo registration: ${e.toString()}',
      };
    }
  }

  // NEW: Get demo registration details
  static Future<Map<String, dynamic>> getDemoDetails(String deviceId) async {
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
      debugPrint('🔵 Getting demo registration for device: $deviceId');
      
      final querySnapshot = await _firestore
          .collection(_demoRegistrationsCollection)
          .where('deviceId', isEqualTo: deviceId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        
        debugPrint('✅ Found demo registration for device: $deviceId');
        
        return {
          'success': true,
          'isRegistered': true,
          'companyId': doc.id,
          'businessName': data['businessName'] ?? '',
          'secondBusinessName': data['secondBusinessName'] ?? '',
          'businessAddress': data['businessAddress'] ?? '',
          'businessPhone': data['businessPhone'] ?? '',
          'businessEmail': data['businessEmail'] ?? '',
          'registrationType': 'demo',
          'isActive': data['isActive'] ?? false,
          'createdAt': data['createdAt'],
          'expiresAt': data['expiresAt'],
        };
      } else {
        debugPrint('⚠️ No demo registration found for device: $deviceId');
        return {
          'success': true,
          'isRegistered': false,
          'message': 'No demo registration found for this device',
        };
      }
    } catch (e) {
      debugPrint('❌ Error getting demo details: $e');
      return {
        'success': false,
        'message': 'Error retrieving demo details: ${e.toString()}',
      };
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

  // Store pending registration keys in Firebase
  static Future<Map<String, dynamic>> storePendingRegistration({
    required List<String> registrationKeys,
    required String deviceId,
  }) async {
    await ensureInitialized();
    
    if (!isFirebaseAvailable) {
      return {
        'success': false,
        'message': 'No internet connection. Please connect to the internet and try again.',
        'isOffline': true,
      };
    }

    try {
      debugPrint('🔵 Storing pending registration keys in Firebase...');
      
      final pendingData = {
        'registrationKeys': registrationKeys,
        'deviceId': deviceId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
      };

      final docRef = await _firestore
          .collection(_pendingRegistrationsCollection)
          .add(pendingData);

      debugPrint('✅ Pending registration stored with ID: ${docRef.id}');

      return {
        'success': true,
        'pendingId': docRef.id,
        'message': 'Registration keys generated successfully',
      };
    } catch (e) {
      debugPrint('❌ Error storing pending registration: $e');
      return {
        'success': false,
        'message': 'Failed to generate registration keys: ${e.toString()}',
      };
    }
  }

  // Get pending registration keys by device ID
  static Future<Map<String, dynamic>> getPendingRegistration(String deviceId) async {
    await ensureInitialized();
    
    if (!isFirebaseAvailable) {
      return {
        'success': false,
        'message': 'No internet connection. Please connect to the internet and try again.',
        'isOffline': true,
      };
    }

    try {
      debugPrint('🔵 Getting pending registration for device: $deviceId');
      
      final querySnapshot = await _firestore
          .collection(_pendingRegistrationsCollection)
          .where('deviceId', isEqualTo: deviceId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        
        final expiresAt = data['expiresAt'] as Timestamp?;
        if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
          debugPrint('⚠️ Pending registration keys have expired');
          return {
            'success': false,
            'message': 'Registration keys have expired. Please generate new ones.',
            'isExpired': true,
          };
        }
        
        debugPrint('✅ Found pending registration for device: $deviceId');
        
        return {
          'success': true,
          'pendingId': doc.id,
          'registrationKeys': List<String>.from(data['registrationKeys'] ?? []),
          'createdAt': data['createdAt'],
          'expiresAt': data['expiresAt'],
        };
      } else {
        debugPrint('⚠️ No pending registration found for device: $deviceId');
        return {
          'success': false,
          'message': 'No pending registration found. Please generate keys first.',
          'notFound': true,
        };
      }
    } catch (e) {
      debugPrint('❌ Error getting pending registration: $e');
      return {
        'success': false,
        'message': 'Error retrieving registration keys: ${e.toString()}',
      };
    }
  }

  // UPDATED: Register company with email field
  static Future<Map<String, dynamic>> registerCompany({
    required String customerName,
    String? secondCustomerName,
    required String customerAddress,
    required String customerPhone,
    required String customerEmail, // NEW: Email field
    required String deviceId,
    required List<String> userEnteredKeys,
  }) async {
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
      
      final pendingResult = await getPendingRegistration(deviceId);
      if (!pendingResult['success']) {
        return pendingResult;
      }

      final storedKeys = List<String>.from(pendingResult['registrationKeys'] ?? []);
      if (!validateRegistrationKeys(storedKeys, userEnteredKeys)) {
        return {
          'success': false,
          'message': 'Invalid registration keys. Please check and try again.',
          'isInvalidKeys': true,
        };
      }
      
      final result = await Future.any([
        _performRegistration(
          registrationKeys: storedKeys,
          customerName: customerName,
          secondCustomerName: secondCustomerName,
          customerAddress: customerAddress,
          customerPhone: customerPhone,
          customerEmail: customerEmail, // Pass email
          deviceId: deviceId,
          pendingId: pendingResult['pendingId'],
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

  // UPDATED: Add email to registration
  static Future<Map<String, dynamic>> _performRegistration({
    required List<String> registrationKeys,
    required String customerName,
    String? secondCustomerName,
    required String customerAddress,
    required String customerPhone,
    required String customerEmail, // NEW: Email field
    required String deviceId,
    required String pendingId,
  }) async {
    final companyData = {
      'registrationKeys': registrationKeys,
      'customerName': customerName,
      'secondCustomerName': secondCustomerName ?? '',
      'customerAddress': customerAddress,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail, // NEW: Store email
      'deviceId': deviceId,
      'registrationType': 'full', // Distinguish from demo
      'isActive': true,
      'registeredAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore
        .collection(_companiesCollection)
        .add(companyData);

    await _firestore
        .collection(_pendingRegistrationsCollection)
        .doc(pendingId)
        .update({
      'status': 'used',
      'usedAt': FieldValue.serverTimestamp(),
      'companyId': docRef.id,
    });

    debugPrint('✅ Company registered with ID: ${docRef.id}');

    return {
      'success': true,
      'companyId': docRef.id,
      'message': 'Company registered successfully',
    };
  }

  // UPDATED: Check company registration (supports demo and full)
  static Future<Map<String, dynamic>> getCompanyDetails(String deviceId) async {
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

  // UPDATED: Check both full registration and demo registration
  static Future<Map<String, dynamic>> _getCompanyDetailsFromFirestore(String deviceId) async {
    // First check for full registration
    final fullRegQuery = await _firestore
        .collection(_companiesCollection)
        .where('deviceId', isEqualTo: deviceId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (fullRegQuery.docs.isNotEmpty) {
      final doc = fullRegQuery.docs.first;
      final data = doc.data();
      
      debugPrint('✅ Found full company registration for device: $deviceId');
      
      return {
        'success': true,
        'isRegistered': true,
        'companyId': doc.id,
        'customerName': data['customerName'] ?? '',
        'secondCustomerName': data['secondCustomerName'] ?? '',
        'customerAddress': data['customerAddress'] ?? '',
        'customerPhone': data['customerPhone'] ?? '',
        'customerEmail': data['customerEmail'] ?? '',
        'registrationKeys': List<String>.from(data['registrationKeys'] ?? []),
        'registrationType': data['registrationType'] ?? 'full',
        'isActive': data['isActive'] ?? false,
        'registeredAt': data['registeredAt'],
        'lastLoginAt': data['lastLoginAt'],
      };
    }

    // If no full registration found, check for demo registration
    final demoQuery = await _firestore
        .collection(_demoRegistrationsCollection)
        .where('deviceId', isEqualTo: deviceId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (demoQuery.docs.isNotEmpty) {
      final doc = demoQuery.docs.first;
      final data = doc.data();
      
      debugPrint('✅ Found demo registration for device: $deviceId');
      
      return {
        'success': true,
        'isRegistered': true,
        'companyId': doc.id,
        'customerName': data['businessName'] ?? '',
        'secondCustomerName': data['secondBusinessName'] ?? '',
        'customerAddress': data['businessAddress'] ?? '',
        'customerPhone': data['businessPhone'] ?? '',
        'customerEmail': data['businessEmail'] ?? '',
        'registrationType': 'demo',
        'isActive': data['isActive'] ?? false,
        'registeredAt': data['createdAt'],
        'expiresAt': data['expiresAt'],
      };
    }

    debugPrint('⚠️ No company found for device: $deviceId');
    return {
      'success': true,
      'isRegistered': false,
      'message': 'No company found for this device',
    };
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