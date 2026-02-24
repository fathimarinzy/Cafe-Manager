import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as native; // Alias native
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'dart:math';
import 'dart:async';
import '../screens/renewal_screen.dart';

// NEW: Adapter imports
import 'firestore_adapter.dart';
import 'package:firedart/firedart.dart' as fd; // Pure Dart Firestore

// NEW: Global flag to check if we are in Legacy Mode
bool get isLegacyMode => _isLegacyMode;
bool _isLegacyMode = false;

/// In-memory token store for Firedart's FirebaseAuth
/// Tokens are lost on app restart (re-authenticates on startup)
class VolatileStore extends fd.TokenStore {
  fd.Token? _token;
  
  @override
  fd.Token? read() => _token;
  
  @override
  void write(fd.Token? token) => _token = token;
  
  @override
  void delete() => _token = null;
}

class FirebaseService {
  // CHANGED: Use the adapter interface instead of direct Firestore instance
  static FirestoreInterface get _firestore => FirestoreAdapter.instance;
  
  static const String _companiesCollection = 'online_registrations';
  static const String _pendingRegistrationsCollection = 'pending_registrations';
  static const String _demoRegistrationsCollection = 'demo_registrations';
  static const String _offlineRegistrationsCollection = 'offline_registrations'; // NEW: Offline collection
  // NEW: Helper for Server Timestamp (Firedart uses DateTime.now(), Native uses FieldValue)
  static dynamic getServerTimestamp() {
    if (_isLegacyMode) {
      return DateTime.now().toUtc();
    } else {
      return native.FieldValue.serverTimestamp(); // Use native alias
    }
  }

  // NEW: Helper to convert dynamic timestamp to DateTime
  static DateTime? toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is native.Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;
  static bool _isOfflineMode = false;
  static Completer<void>? _initCompleter;
  static const String _pendingRenewalsCollection = 'pending_renewals';
  static const String _renewalHistoryCollection = 'renewal_history';

  // Quick initialization that doesn't block app startup
  static void initializeQuickly({bool useLegacyMode = false}) {
    if (_isInitialized || _initCompleter != null) return;
    
    _isLegacyMode = useLegacyMode; // Set the mode
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
      debugPrint('🔵 Background Firebase initialization... (Legacy Mode: $_isLegacyMode)');
      
      if (_isLegacyMode) {
        // Initialize Pure Dart Firestore (Firedart)
        debugPrint('🔥 Initializing Firedart...');
        
        const projectId = 'simscafe-c743e'; 
        
        // Firedart requires Firebase Auth for authenticated Firestore writes.
        const apiKey = 'AIzaSyB1ggenNDwBP6NZ3_pYH3htNCHBTS395O0';
        fd.FirebaseAuth.initialize(apiKey, VolatileStore());
        try {
          await fd.FirebaseAuth.instance.signInAnonymously();
          debugPrint('✅ Firedart anonymous auth successful');
        } catch (authError) {
          debugPrint('⚠️ Firedart anonymous auth failed: $authError');
        }
        
        fd.Firestore.initialize(projectId);
        
        // Initialize the adapter
        FirestoreAdapter.initialize(usePureDart: true);
        
        _isInitialized = true;
        _isOfflineMode = false;
        debugPrint('✅ Firedart initialized successfully');

      } else {
        // Standard Native Initialization
        await Future.any([
          Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ),
          Future.delayed(const Duration(seconds: 30), () {
            throw TimeoutException('Firebase initialization timed out', const Duration(seconds: 30));
          }),
        ]);
        
        // Initialize the adapter
        FirestoreAdapter.initialize(usePureDart: false);
        
        _isInitialized = true;
        _isOfflineMode = false;
        debugPrint('✅ Background Native Firebase initialized successfully');
        
        _setupOfflinePersistence();
      }
      
    } catch (e) {
      debugPrint('⚠️ Background Firebase initialization failed: $e');
      _isOfflineMode = true;
      _isInitialized = true;
    }
  }

  // Setup offline persistence without blocking (Native Only)
  static void _setupOfflinePersistence() {
    if (_isLegacyMode) return; // Firedart doesn't support this settings API
    
    try {
      native.FirebaseFirestore.instance.settings = const native.Settings(
        persistenceEnabled: true,
        cacheSizeBytes: native.Settings.CACHE_SIZE_UNLIMITED,
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
      if (_isLegacyMode) {
         // If firedart failed to init for some reason, try one last time synchronously?
         // No, just mark offline.
      }
      _isOfflineMode = true;
      _isInitialized = true;
    }
  }

  // Check if Firebase is available
  static bool get isFirebaseAvailable => _isInitialized && !_isOfflineMode;
  
  // NEW: Store offline registration in Firebase
  static Future<Map<String, dynamic>> storeOfflineRegistration({
  required String businessName,
  String? secondBusinessName,
  required String businessAddress,
  required String businessPhone,
  String? businessEmail,
  required String deviceId,
  required List<String> registrationKeys,
}) async {
  debugPrint('=== STORE OFFLINE REGISTRATION START ===');
  debugPrint('Parameters received:');
  debugPrint('  businessName: "$businessName"');
  debugPrint('  secondBusinessName: "$secondBusinessName"');
  debugPrint('  businessAddress: "$businessAddress"');
  debugPrint('  businessPhone: "$businessPhone"');
  debugPrint('  businessEmail: "$businessEmail"');
  debugPrint('  deviceId: "$deviceId"');
  debugPrint('  registrationKeys: $registrationKeys');
  
  await ensureInitialized();
  debugPrint('Firebase initialized: $_isInitialized');
  debugPrint('Firebase available: $isFirebaseAvailable');
  debugPrint('Offline mode: $_isOfflineMode');
  
  if (!isFirebaseAvailable) {
    debugPrint('❌ Firebase not available - returning offline status');
    return {
      'success': false,
      'message': 'No internet connection. Data stored locally only.',
      'isOffline': true,
    };
  }

  try {
    debugPrint('🔵 Attempting to store offline registration in Firebase...');
    
    // Check if device already has an offline registration
    debugPrint('🔍 Checking for existing offline registration...');
    final existingQuery = await _firestore
        .collection(_offlineRegistrationsCollection)
        .where('deviceId', isEqualTo: deviceId)
        .limit(1)
        .get()
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⚠️ Firestore query timed out');
            throw TimeoutException('Query timed out');
          },
        );

    debugPrint('📊 Existing query results: ${existingQuery.docs.length} documents found');

    final offlineData = {
      'businessName': businessName,
      'secondBusinessName': secondBusinessName ?? '',
      'businessAddress': businessAddress,
      'businessPhone': businessPhone,
      'businessEmail': businessEmail ?? '',
      'deviceId': deviceId,
      'registrationKeys': registrationKeys,
      'registrationType': 'offline',
      'isActive': true,
      'syncedAt': getServerTimestamp(),
    };
    
    debugPrint('📦 Data to be stored: $offlineData');

    if (existingQuery.docs.isNotEmpty) {
      // Update existing offline registration
      final docId = existingQuery.docs.first.id;
      debugPrint('🔄 Updating existing document with ID: $docId');
      
      await _firestore
          .collection(_offlineRegistrationsCollection)
          .doc(docId)
          .update({
        ...offlineData,
        'updatedAt': getServerTimestamp(),
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Firestore update timed out');
          throw TimeoutException('Update timed out');
        },
      );

      debugPrint('✅ Offline registration updated with ID: $docId');
      return {
        'success': true,
        'companyId': docId,
        'message': 'Offline registration synced successfully',
      };
    } else {
      // Create new offline registration
      debugPrint('➕ Creating new offline registration document');
      offlineData['createdAt'] = getServerTimestamp();
      
      final docRef = await _firestore
          .collection(_offlineRegistrationsCollection)
          .add(offlineData)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('⚠️ Firestore add timed out');
              throw TimeoutException('Add timed out');
            },
          );

      debugPrint('✅ Offline registration stored with ID: ${docRef.id}');
      return {
        'success': true,
        'companyId': docRef.id,
        'message': 'Offline registration synced successfully',
      };
    }
  } on TimeoutException catch (e) {
    debugPrint('⏱️ Timeout storing offline registration: $e');
    return {
      'success': false,
      'message': 'Request timed out. Please check your internet connection.',
      'timeout': true,
    };
  } on FirebaseException catch (e) {
    debugPrint('🔥 Firebase exception storing offline registration:');
    debugPrint('   Code: ${e.code}');
    debugPrint('   Message: ${e.message}');
    debugPrint('   Plugin: ${e.plugin}');
    return {
      'success': false,
      'message': 'Firebase error: ${e.message}',
      'firebaseError': true,
    };
  } catch (e) {
    debugPrint('❌ Error storing offline registration: $e');
    debugPrint('   Error type: ${e.runtimeType}');
    debugPrint('   Stack trace: ${StackTrace.current}');
    return {
      'success': false,
      'message': 'Failed to sync offline registration: ${e.toString()}',
    };
  } finally {
    debugPrint('=== STORE OFFLINE REGISTRATION END ===');
  }
}

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
          'updatedAt': getServerTimestamp(),
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
          'createdAt': getServerTimestamp(),
          'expiresAt': DateTime.now().add(const Duration(days: 30)),
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
    String? businessName, // NEW: Add business name parameter
    String? businessEmail,

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
        'businessName': businessName ?? '',
        'businessEmail': businessEmail ?? '',
        'status': 'pending',
        'createdAt': getServerTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(days: 7)),
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
        
        final expiresAt = toDateTime(data['expiresAt']);
        if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
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
          'businessEmail': data['businessEmail'] ?? '',
          'businessName': data['businessName'] ?? '',
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
    required String businessName,
    String? secondBusinessName,
    required String businessAddress,
    required String businessPhone,
    required String businessEmail, // NEW: Email field
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
          businessName: businessName,
          secondBusinessName: secondBusinessName,
          businessAddress: businessAddress,
          businessPhone: businessPhone,
          businessEmail: businessEmail, // Pass email
          deviceId: deviceId,
          pendingId: pendingResult['pendingId'],
        ),
        // Future.delayed(const Duration(seconds: 8), () {
        //   throw TimeoutException('Registration timed out', const Duration(seconds: 8));
        // }),
      ]);

      return result;
    } catch (e) {
      debugPrint('❌ Error registering company: $e');
      
      // if (e is TimeoutException) {
      //   return {
      //     'success': false,
      //     'message': 'Registration timed out. Please check your internet connection and try again.',
      //     'isTimeout': true,
      //   };
      // }
      
      return {
        'success': false,
        'message': 'Registration failed: ${e.toString()}',
      };
    }
  }

  // UPDATED: Add email to registration
  static Future<Map<String, dynamic>> _performRegistration({
    required List<String> registrationKeys,
    required String businessName,
    String? secondBusinessName,
    required String businessAddress,
    required String businessPhone,
    required String businessEmail, // NEW: Email field
    required String deviceId,
    required String pendingId,
  }) async {
    final companyData = {
      'registrationKeys': registrationKeys,
      'businessName': businessName,
      'secondBusinessName': secondBusinessName ?? '',
      'businessAddress': businessAddress,
      'businessPhone': businessPhone,
      'businessEmail': businessEmail, // NEW: Store email
      'deviceId': deviceId,
      'registrationType': 'online', // Distinguish from demo
      'isActive': true,
      'registeredAt': getServerTimestamp(),
      'lastLoginAt': getServerTimestamp(),
    };

    final docRef = await _firestore
        .collection(_companiesCollection)
        .add(companyData);

    await _firestore
        .collection(_pendingRegistrationsCollection)
        .doc(pendingId)
        .update({
      'status': 'used',
      'usedAt': getServerTimestamp(),
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
   // NEW: Get offline registration details
  static Future<Map<String, dynamic>> getOfflineRegistration(String deviceId) async {
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
      debugPrint('🔵 Getting offline registration for device: $deviceId');
      
      final querySnapshot = await _firestore
          .collection(_offlineRegistrationsCollection)
          .where('deviceId', isEqualTo: deviceId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        
        debugPrint('✅ Found offline registration for device: $deviceId');
        
        return {
          'success': true,
          'isRegistered': true,
          'companyId': doc.id,
          'businessName': data['businessName'] ?? '',
          'secondBusinessName': data['secondBusinessName'] ?? '',
          'businessAddress': data['businessAddress'] ?? '',
          'businessPhone': data['businessPhone'] ?? '',
          'businessEmail': data['businessEmail'] ?? '', 
          'registrationKeys': List<String>.from(data['registrationKeys'] ?? []),
          'registrationType': 'offline',
          'isActive': data['isActive'] ?? false,
          'createdAt': data['createdAt'],
          'syncedAt': data['syncedAt'],
        };
      } else {
        debugPrint('⚠️ No offline registration found for device: $deviceId');
        return {
          'success': true,
          'isRegistered': false,
          'message': 'No offline registration found for this device',
        };
      }
    } catch (e) {
      debugPrint('❌ Error getting offline registration: $e');
      return {
        'success': false,
        'message': 'Error retrieving offline registration: ${e.toString()}',
      };
    }
  }

  // NEW: Check if offline data needs to be synced
  static Future<bool> hasUnsyncedOfflineData(String deviceId) async {
    await ensureInitialized();
    
    if (!isFirebaseAvailable) {
      return false; // Can't sync without Firebase
    }

    try {
      final offlineReg = await getOfflineRegistration(deviceId);
      // If no offline registration exists in Firebase, then local data needs sync
      return !offlineReg['isRegistered'];
    } catch (e) {
      debugPrint('Error checking unsynced data: $e');
      return false;
    }
  }

  // Check full, demo, and offline registrations
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
        'businessName': data['businessName'] ?? '',
        'secondBusinessName': data['secondBusinessName'] ?? '',
        'businessAddress': data['businessAddress'] ?? '',
        'businessPhone': data['businessPhone'] ?? '',
        'businessEmail': data['businessEmail'] ?? '',
        'registrationKeys': List<String>.from(data['registrationKeys'] ?? []),
        'registrationType': data['registrationType'] ?? 'online',
        'isActive': data['isActive'] ?? false,
        'registeredAt': data['registeredAt'],
        'lastLoginAt': data['lastLoginAt'],
      };
    }

    // Check for demo registration
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
        'businessName': data['businessName'] ?? '',
        'secondBusinessName': data['secondBusinessName'] ?? '',
        'businessAddress': data['businessAddress'] ?? '',
        'businessPhone': data['businessPhone'] ?? '',
        'businessEmail': data['businessEmail'] ?? '',
        'registrationType': 'demo',
        'isActive': data['isActive'] ?? false,
        'registeredAt': data['createdAt'],
        'expiresAt': data['expiresAt'],
      };
    }

    // Check for offline registration
    final offlineQuery = await _firestore
        .collection(_offlineRegistrationsCollection)
        .where('deviceId', isEqualTo: deviceId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (offlineQuery.docs.isNotEmpty) {
      final doc = offlineQuery.docs.first;
      final data = doc.data();
      
      debugPrint('✅ Found offline registration for device: $deviceId');
      
      return {
        'success': true,
        'isRegistered': true,
        'companyId': doc.id,
        'businessName': data['businessName'] ?? '',
        'secondBusinessName': data['secondBusinessName'] ?? '',
        'businessAddress': data['businessAddress'] ?? '',
        'businessEmail': data['businessEmail'] ?? '',
        'businessPhone': data['businessPhone'] ?? '',
        'registrationKeys': List<String>.from(data['registrationKeys'] ?? []),
        'registrationType': 'offline',
        'isActive': data['isActive'] ?? false,
        'registeredAt': data['createdAt'],
        'syncedAt': data['syncedAt'],
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
          'lastLoginAt': getServerTimestamp(),
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
  
  // Store pending renewal keys in Firebase
  static Future<Map<String, dynamic>> storePendingRenewal({
    required List<String> renewalKeys,
    required String deviceId,
    required RenewalType renewalType,
    String? businessName, // NEW: Add business name parameter
    String? businessEmail,

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
      debugPrint('🔵 Storing pending renewal keys in Firebase...');
      
      // Check if device already has pending renewal keys
      final existingQuery = await _firestore
          .collection(_pendingRenewalsCollection)
          .where('deviceId', isEqualTo: deviceId)
          .where('renewalType', isEqualTo: renewalType.toString())
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'This device already has pending renewal keys. Please use those keys or contact support.',
          'hasPendingKeys': true,
        };
      }
      
      final renewalData = {
        'renewalKeys': renewalKeys,
        'deviceId': deviceId,
        'businessName': businessName ?? '',
        'businessEmail': businessEmail ?? '',
        'renewalType': renewalType.toString(),
        'status': 'pending',
        'createdAt': getServerTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(days: 7)),
      };

      final docRef = await _firestore
          .collection(_pendingRenewalsCollection)
          .add(renewalData);

      debugPrint('✅ Pending renewal stored with ID: ${docRef.id}');

      return {
        'success': true,
        'renewalId': docRef.id,
        'message': 'Renewal keys generated successfully',
      };
    } catch (e) {
      debugPrint('❌ Error storing pending renewal: $e');
      return {
        'success': false,
        'message': 'Failed to generate renewal keys: ${e.toString()}',
      };
    }
  }
  // Get pending renewal keys by device ID and renewal type
  static Future<Map<String, dynamic>> getPendingRenewal(String deviceId, RenewalType renewalType) async {
    await ensureInitialized();
    
    if (!isFirebaseAvailable) {
      return {
        'success': false,
        'message': 'No internet connection. Please connect to the internet and try again.',
        'isOffline': true,
      };
    }

    try {
      debugPrint('🔵 Getting pending renewal for device: $deviceId, type: $renewalType');
      
      final querySnapshot = await _firestore
          .collection(_pendingRenewalsCollection)
          .where('deviceId', isEqualTo: deviceId)
          .where('renewalType', isEqualTo: renewalType.toString())
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        
        final expiresAt = toDateTime(data['expiresAt']);
        if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
          debugPrint('⚠️ Pending renewal keys have expired');
          return {
            'success': false,
            'message': 'Renewal keys have expired. Please generate new ones.',
            'isExpired': true,
          };
        }
        
        debugPrint('✅ Found pending renewal for device: $deviceId');
        
        return {
          'success': true,
          'renewalId': doc.id,
          'renewalKeys': List<String>.from(data['renewalKeys'] ?? []),
          'createdAt': data['createdAt'],
          'expiresAt': data['expiresAt'],
        };
      } else {
        debugPrint('⚠️ No pending renewal found for device: $deviceId');
        return {
          'success': false,
          'message': 'No pending renewal found. Please generate keys first.',
          'notFound': true,
        };
      }
    } catch (e) {
      debugPrint('❌ Error getting pending renewal: $e');
      return {
        'success': false,
        'message': 'Error retrieving renewal keys: ${e.toString()}',
      };
    }
  }

 // Process renewal with entered keys
  static Future<Map<String, dynamic>> processRenewal({
    required String deviceId,
    required List<String> userEnteredKeys,
    required RenewalType renewalType,
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
      debugPrint('🔵 Processing renewal with Firebase...');
      
      final pendingResult = await getPendingRenewal(deviceId, renewalType);
      if (!pendingResult['success']) {
        return pendingResult;
      }

      final storedKeys = List<String>.from(pendingResult['renewalKeys'] ?? []);
      if (!validateRegistrationKeys(storedKeys, userEnteredKeys)) {
        return {
          'success': false,
          'message': 'Invalid renewal keys. Please check and try again.',
          'isInvalidKeys': true,
        };
      }
      
      final result = await Future.any([
        _performRenewal(
          renewalKeys: storedKeys,
          deviceId: deviceId,
          renewalType: renewalType,
          renewalId: pendingResult['renewalId'],
        ),
        // Future.delayed(const Duration(seconds: 8), () {
        //   throw TimeoutException('Renewal timed out', const Duration(seconds: 8));
        // }),
      ]);

      return result;
    } catch (e) {
      debugPrint('❌ Error processing renewal: $e');
      
      // if (e is TimeoutException) {
      //   return {
      //     'success': false,
      //     'message': 'Renewal timed out. Please check your internet connection and try again.',
      //     'isTimeout': true,
      //   };
      // }
      
      return {
        'success': false,
        'message': 'Renewal failed: ${e.toString()}',
      };
    }
  }


  // Perform the actual renewal process
 static Future<Map<String, dynamic>> _performRenewal({
  required List<String> renewalKeys,
  required String deviceId,
  required RenewalType renewalType,
  required String renewalId,
  }) async {
    // Determine renewal period based on type
    // Demo renewal upgrades to full license (365 days)
    final renewalPeriod = renewalType == RenewalType.demo ? 365 : 365; // Both are now 365 days
    
    final renewalData = {
      'renewalKeys': renewalKeys,
      'deviceId': deviceId,
      'renewalType': renewalType.toString(),
      'renewedAt': getServerTimestamp(),
      'renewalPeriod': renewalPeriod,
      'status': 'completed',
      'upgradedFromDemo': renewalType == RenewalType.demo, // Flag to track demo upgrades
    };

    // Store renewal history
    final docRef = await _firestore
        .collection(_renewalHistoryCollection)
        .add(renewalData);

    // Mark pending renewal as used
    await _firestore
        .collection(_pendingRenewalsCollection)
        .doc(renewalId)
        .update({
      'status': 'used',
      'usedAt': getServerTimestamp(),
      'renewalHistoryId': docRef.id,
    });

    // If this was a demo upgrade, update the demo registration status
    if (renewalType == RenewalType.demo) {
      try {
        final demoQuery = await _firestore
            .collection(_demoRegistrationsCollection)
            .where('deviceId', isEqualTo: deviceId)
            .limit(1)
            .get();
        
        if (demoQuery.docs.isNotEmpty) {
          await _firestore
              .collection(_demoRegistrationsCollection)
              .doc(demoQuery.docs.first.id)
              .update({
            'upgradedToLicense': true,
            'upgradeDate': getServerTimestamp(),
            'isActive': false, // Deactivate demo
          });
        }
      } catch (e) {
        debugPrint('⚠️ Could not update demo registration: $e');
        // Don't fail the renewal if this update fails
      }
    }

    debugPrint('✅ Renewal processed with ID: ${docRef.id}');
    debugPrint('Renewal period: $renewalPeriod days');

    return {
      'success': true,
      'renewalId': docRef.id,
      'message': 'Renewal completed successfully',
      'renewalPeriod': renewalPeriod,
    };
  }

  // Get renewal history for a device
  static Future<Map<String, dynamic>> getRenewalHistory(String deviceId) async {
    await ensureInitialized();
    
    if (!isFirebaseAvailable) {
      return {
        'success': true,
        'renewals': [],
        'isOffline': true,
      };
    }

    try {
      debugPrint('🔵 Getting renewal history for device: $deviceId');
      
      final querySnapshot = await _firestore
          .collection(_renewalHistoryCollection)
          .where('deviceId', isEqualTo: deviceId)
          .where('status', isEqualTo: 'completed')
          .orderBy('renewedAt', descending: true)
          .get();

      final renewals = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'businessName': data['businessName'] ?? '',
          'businessEmail': data['businessEmail'] ?? '',
          'renewalType': data['renewalType'],
          'renewedAt': data['renewedAt'],
          'renewalPeriod': data['renewalPeriod'],
        };
      }).toList();

      debugPrint('✅ Found ${renewals.length} renewals for device: $deviceId');
      
      return {
        'success': true,
        'renewals': renewals,
      };
    } catch (e) {
      debugPrint('❌ Error getting renewal history: $e');
      return {
        'success': false,
        'message': 'Error retrieving renewal history: ${e.toString()}',
        'renewals': [],
      };
    }
  }

/// Upgrade demo registration to online registration (creates entry in online_registrations)
static Future<Map<String, dynamic>> upgradeDemoToOnlineRegistration({
  required String deviceId,
  required String demoCompanyId,
  required String businessName,
  String? secondBusinessName,
  required String businessAddress,
  required String businessPhone,
  required String businessEmail,
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
    debugPrint('🔵 Upgrading demo to online registration in Firebase...');
    debugPrint('Device ID: $deviceId');
    debugPrint('Demo Company ID: $demoCompanyId');
    debugPrint('Business Name: $businessName');
    
    // First, get the demo registration details
    Map<String, dynamic>? demoDetails;
    String actualDemoCompanyId = demoCompanyId;
    
    if (demoCompanyId.isNotEmpty) {
      try {
        final demoDoc = await _firestore
            .collection(_demoRegistrationsCollection)
            .doc(demoCompanyId)
            .get();
        
        if (demoDoc.exists) {
          demoDetails = demoDoc.data();
          debugPrint('✅ Found demo registration by company ID: ${demoDoc.id}');
        }
      } catch (e) {
        debugPrint('⚠️ Could not find demo by company ID: $e');
      }
    }

    // If we didn't find by company ID, try by device ID
    if (demoDetails == null) {
      debugPrint('🔍 Searching for demo registration by device ID...');
      try {
        final demoQuery = await _firestore
            .collection(_demoRegistrationsCollection)
            .where('deviceId', isEqualTo: deviceId)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();
        
        if (demoQuery.docs.isNotEmpty) {
          demoDetails = demoQuery.docs.first.data();
          actualDemoCompanyId = demoQuery.docs.first.id;
          debugPrint('✅ Found demo registration by device ID: $actualDemoCompanyId');
        }
      } catch (e) {
        debugPrint('⚠️ Could not find demo by device ID: $e');
      }
    }

    // Use business info from parameters, falling back to demo details if needed
    final finalBusinessName = businessName.isNotEmpty 
        ? businessName 
        : (demoDetails?['businessName'] ?? 'Upgraded Business');
    final finalSecondBusinessName = secondBusinessName ?? demoDetails?['secondBusinessName'] ?? '';
    final finalBusinessAddress = businessAddress.isNotEmpty
        ? businessAddress
        : (demoDetails?['businessAddress'] ?? '');
    final finalBusinessPhone = businessPhone.isNotEmpty
        ? businessPhone
        : (demoDetails?['businessPhone'] ?? '');
    final finalBusinessEmail = businessEmail.isNotEmpty
        ? businessEmail
        : (demoDetails?['businessEmail'] ?? '');

    debugPrint('📋 Final business details:');
    debugPrint('  Name: $finalBusinessName');
    debugPrint('  Address: $finalBusinessAddress');
    debugPrint('  Phone: $finalBusinessPhone');
    debugPrint('  Email: $finalBusinessEmail');

    // Generate registration keys for the online registration
    final registrationKeys = generateRegistrationKeys();
    debugPrint('🔑 Generated registration keys: ${registrationKeys.join(', ')}');

    // Create the online registration entry
    final onlineRegistrationData = {
      'registrationKeys': registrationKeys,
      'businessName': finalBusinessName,
      'secondBusinessName': finalSecondBusinessName,
      'businessAddress': finalBusinessAddress,
      'businessPhone': finalBusinessPhone,
      'businessEmail': finalBusinessEmail,
      'deviceId': deviceId,
      'registrationType': 'online',
      'isActive': true,
      'registeredAt': getServerTimestamp(),
      'lastLoginAt': getServerTimestamp(),
      'upgradedFromDemo': true, // Flag to indicate this was upgraded from demo
      'originalDemoId': actualDemoCompanyId, // Reference to original demo registration
    };

    debugPrint('📤 Creating online registration document...');
    final docRef = await _firestore
        .collection(_companiesCollection)
        .add(onlineRegistrationData);

    debugPrint('✅ Online registration created with ID: ${docRef.id}');

    // Mark the demo registration as upgraded and inactive
    if (actualDemoCompanyId.isNotEmpty) {
      try {
        debugPrint('📝 Updating demo registration to mark as upgraded...');
        await _firestore
            .collection(_demoRegistrationsCollection)
            .doc(actualDemoCompanyId)
            .update({
          'upgradedToLicense': true,
          'upgradeDate': getServerTimestamp(),
          'isActive': false,
          'upgradedToCompanyId': docRef.id, // Link to new online registration
        });
        debugPrint('✅ Demo registration marked as upgraded');
      } catch (e) {
        debugPrint('⚠️ Could not update demo registration: $e');
        // Don't fail the upgrade if this fails
      }
    } else {
      debugPrint('⚠️ No demo company ID to update');
    }

    return {
      'success': true,
      'companyId': docRef.id,
      'message': 'Successfully upgraded demo to online registration',
      'registrationKeys': registrationKeys,
    };
  } catch (e) {
    debugPrint('❌ Error upgrading demo to online registration: $e');
    debugPrint('Stack trace: ${StackTrace.current}');
    return {
      'success': false,
      'message': 'Failed to upgrade demo registration: ${e.toString()}',
    };
  }
}
  // NEW: Update online registration business information
  static Future<Map<String, dynamic>> updateOnlineRegistrationInfo({
    required String companyId,
    required String businessName,
    String? secondBusinessName,
    required String businessAddress,
    required String businessPhone,
    required String businessEmail,
  }) async {
    await ensureInitialized();
    
    if (!isFirebaseAvailable) {
      return {
        'success': false,
        'message': 'No internet connection. Changes saved locally only.',
        'isOffline': true,
      };
    }

    try {
      debugPrint('🔵 Updating online registration business info in Firebase...');
      
      await _firestore
          .collection(_companiesCollection)
          .doc(companyId)
          .update({
        'businessName': businessName,
        'secondBusinessName': secondBusinessName ?? '',
        'businessAddress': businessAddress,
        'businessPhone': businessPhone,
        'businessEmail': businessEmail,
        'updatedAt': getServerTimestamp(),
      });

      debugPrint('✅ Online registration business info updated successfully');
      return {
        'success': true,
        'message': 'Business information updated successfully',
      };
    } catch (e) {
      debugPrint('❌ Error updating online registration business info: $e');
      return {
        'success': false,
        'message': 'Failed to update business information: ${e.toString()}',
      };
    }
  }

  // NEW: Update demo registration business information
  static Future<Map<String, dynamic>> updateDemoRegistrationInfo({
    required String companyId,
    required String businessName,
    String? secondBusinessName,
    required String businessAddress,
    required String businessPhone,
    required String businessEmail,
  }) async {
    await ensureInitialized();
    
    if (!isFirebaseAvailable) {
      return {
        'success': false,
        'message': 'No internet connection. Changes saved locally only.',
        'isOffline': true,
      };
    }

    try {
      debugPrint('🔵 Updating demo registration business info in Firebase...');
      
      await _firestore
          .collection(_demoRegistrationsCollection)
          .doc(companyId)
          .update({
        'businessName': businessName,
        'secondBusinessName': secondBusinessName ?? '',
        'businessAddress': businessAddress,
        'businessPhone': businessPhone,
        'businessEmail': businessEmail,
        'updatedAt': getServerTimestamp(),
      });

      debugPrint('✅ Demo registration business info updated successfully');
      return {
        'success': true,
        'message': 'Demo business information updated successfully',
      };
    } catch (e) {
      debugPrint('❌ Error updating demo registration business info: $e');
      return {
        'success': false,
        'message': 'Failed to update demo business information: ${e.toString()}',
      };
    }
  }
}