import 'order.dart';
import 'order_item.dart';
import 'package:flutter/foundation.dart';


/// OrderHistory model to represent orders in the history list
class OrderHistory {
  int id;
  final String serviceType;
  final double total;
  final String status;
  final DateTime createdAt;
  final List<OrderItem> items;

  OrderHistory({
    required this.id,
    required this.serviceType,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  // FIXED: Simplified factory method without timezone adjustments
  factory OrderHistory.fromOrder(Order order) {
    DateTime parsedDate;
    
    if (order.createdAt != null) {
      try {
        // Check if it's a local timestamp format
        if (order.createdAt!.contains('local_') || 
            order.createdAt!.contains('device_')) {
          // Extract timestamp from local format
          final parts = order.createdAt!.split('_');
          if (parts.length > 1) {
            try {
              final timestamp = int.parse(parts.last);
              parsedDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
              debugPrint('Parsed local timestamp: $parsedDate');
            } catch (e) {
              parsedDate = DateTime.parse(order.createdAt!);
              debugPrint('Falling back to DateTime.parse: $parsedDate');
            }
          } else {
            parsedDate = DateTime.parse(order.createdAt!);
          }
        } else {
          // For ISO format timestamps, parse directly without timezone adjustments
          // Since local orders are stored in local time, use them as-is
          parsedDate = DateTime.parse(order.createdAt!);
          debugPrint('Parsed timestamp as-is: $parsedDate');
        }
      } catch (e) {
        debugPrint('Error parsing date: $e');
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
      debugPrint('No createdAt timestamp, using current time');
    }
    
    return OrderHistory(
      id: order.id ?? 0,
      serviceType: order.serviceType,
      total: order.total,
      status: order.status,
      createdAt: parsedDate,
      items: order.items,
    );
  }

  // Method to format the order number
  String get orderNumber => id.toString().padLeft(4, '0');
  
  // Methods to get formatted date and time
  String get formattedDate {
    return '${createdAt.day.toString().padLeft(2, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.year}';
  }
  
  String get formattedTime {
    // Use 12-hour format with AM/PM
    final hour = createdAt.hour;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final amPm = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:${createdAt.minute.toString().padLeft(2, '0')} $amPm';
  }
}


/// Filter type for order history
enum OrderTimeFilter {
  today,
  weekly,
  monthly,
  yearly,
  all
}

/// Extension to add helper methods to OrderTimeFilter
extension OrderTimeFilterExtension on OrderTimeFilter {
  String get displayName {
    switch (this) {
      case OrderTimeFilter.today:
        return 'Today';
      case OrderTimeFilter.weekly:
        return 'This Week';
      case OrderTimeFilter.monthly:
        return 'This Month';
      case OrderTimeFilter.yearly:
        return 'This Year';
      case OrderTimeFilter.all:
        return 'All Orders';
    }
  }
  
  // Method to filter orders based on time period
  bool isInPeriod(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final orderDate = DateTime(date.year, date.month, date.day);
    
    switch (this) {
      case OrderTimeFilter.today:
        return orderDate.isAtSameMomentAs(today);
      
      case OrderTimeFilter.weekly:
        // Get the start of the current week (Monday)
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        // Check if date is within the last 7 days
        return orderDate.isAtSameMomentAs(startOfWeek) || orderDate.isAfter(startOfWeek);
      
      case OrderTimeFilter.monthly:
        // First day of current month
        final startOfMonth = DateTime(now.year, now.month, 1);
        return orderDate.isAtSameMomentAs(startOfMonth) || orderDate.isAfter(startOfMonth);
      
      case OrderTimeFilter.yearly:
        // First day of current year
        final startOfYear = DateTime(now.year, 1, 1);
        return orderDate.isAtSameMomentAs(startOfYear) || orderDate.isAfter(startOfYear);
      
      case OrderTimeFilter.all:
        return true;
    }
  }
}