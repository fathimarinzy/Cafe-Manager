// Create: lib/utils/service_type_utils.dart

import 'package:flutter/material.dart';
import '../utils/app_localization.dart';

class ServiceTypeUtils {
  // Normalize service types for consistent grouping/comparison
  static String normalize(String serviceType) {
    // Handle English service types
    if (serviceType.contains('Dining') || serviceType.contains('Table')) {
      return 'Dining';
    } else if (serviceType.contains('Takeout')) {
      return 'Takeout';
    } else if (serviceType.contains('Delivery')) {
      return 'Delivery';
    } else if (serviceType.contains('Drive')) {
      return 'Drive Through';
    } else if (serviceType.contains('Catering')) {
      return 'Catering';
    }
    
    // Handle Arabic service types
    else if (serviceType.contains('تناول الطعام') || serviceType.contains('الطاولة')) {
      return 'Dining';
    } else if (serviceType.contains('طلب خارجي')) {
      return 'Takeout';
    } else if (serviceType.contains('توصيل')) {
      return 'Delivery';
    } else if (serviceType.contains('السيارة')) {
      return 'Drive Through';
    } else if (serviceType.contains('تموين')) {
      return 'Catering';
    } else {
      return serviceType; // Keep original if no match
    }
  }

  // Get translated service type for display
  static String getTranslated(String serviceType) {
    String normalized = normalize(serviceType);
    
    switch (normalized) {
      case 'Dining':
        // Extract table number if it exists
        final tableMatch = RegExp(r'(Table|الطاولة) (\d+)').firstMatch(serviceType);
        if (tableMatch != null) {
          final tableNumber = tableMatch.group(2);
          return '${'Dining'.tr()} - ${'Table'.tr()} $tableNumber';
        }
        return 'Dining'.tr();
      case 'Takeout':
        return 'Takeout'.tr();
      case 'Delivery':
        return 'Delivery'.tr();
      case 'Drive Through':
        return 'Drive Through'.tr();
      case 'Catering':
        return 'Catering'.tr();
      default:
        return serviceType;
    }
  }

  // Get service type color
  static Color getColor(String serviceType) {
    String normalized = normalize(serviceType);
    
    switch (normalized) {
      case 'Dining':
        return const Color.fromARGB(255, 83, 153, 232);
      case 'Takeout':
        return const Color.fromARGB(255, 121, 221, 124);
      case 'Delivery':
        return const Color.fromARGB(255, 255, 152, 0);
      case 'Drive Through':
        return const Color.fromARGB(255, 219, 128, 128);
      case 'Catering':
        return const Color.fromARGB(255, 232, 216, 65);
      default:
        return const Color(0xFF607D8B);
    }
  }

  // Get service type icon
  static IconData getIcon(String serviceType) {
    String normalized = normalize(serviceType);
    
    switch (normalized) {
      case 'Dining':
        return Icons.restaurant;
      case 'Takeout':
        return Icons.takeout_dining;
      case 'Delivery':
        return Icons.delivery_dining;
      case 'Drive Through':
        return Icons.drive_eta;
      case 'Catering':
        return Icons.cake;
      default:
        return Icons.receipt;
    }
  }

  // Check if two service types are the same (normalized)
  static bool isSameType(String serviceType1, String serviceType2) {
    return normalize(serviceType1) == normalize(serviceType2);
  }
}