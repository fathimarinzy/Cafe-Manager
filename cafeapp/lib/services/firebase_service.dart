// lib/services/firebase_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'dart:math';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _companiesCollection = 'registered_companies';

  // Initialize Firebase
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
      // Don't rethrow in production to allow offline mode
      if (kDebugMode) {
        rethrow;
      }
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

  // Register company with Firebase
  static Future<Map<String, dynamic>> registerCompany({
    required List<String> registrationKeys,
    required String customerName,
    required String customerAddress,
    required String customerPhone,
    required String deviceId,
  }) async {
    try {
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

      debugPrint('Company registered with ID: ${docRef.id}');

      return {
        'success': true,
        'companyId': docRef.id,
        'message': 'Company registered successfully',
      };
    } catch (e) {
      debugPrint('Error registering company: $e');
      return {
        'success': false,
        'message': 'Registration failed: $e',
      };
    }
  }

  // Check if company is registered and get details
  static Future<Map<String, dynamic>> getCompanyDetails(String deviceId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_companiesCollection)
          .where('deviceId', isEqualTo: deviceId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        
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
        return {
          'success': true,
          'isRegistered': false,
          'message': 'No company found for this device',
        };
      }
    } catch (e) {
      debugPrint('Error getting company details: $e');
      return {
        'success': false,
        'message': 'Error fetching company details: $e',
      };
    }
  }

  // Update last login time
  static Future<void> updateLastLogin(String companyId) async {
    try {
      await _firestore
          .collection(_companiesCollection)
          .doc(companyId)
          .update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating last login: $e');
    }
  }

  // Deactivate company (if needed)
  static Future<bool> deactivateCompany(String companyId) async {
    try {
      await _firestore
          .collection(_companiesCollection)
          .doc(companyId)
          .update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error deactivating company: $e');
      return false;
    }
  }

  // Get device ID (you can use device_info_plus package for more accurate device ID)
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