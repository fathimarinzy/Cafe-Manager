// models/order_history.dart
// import 'package:flutter/material.dart';
import 'order.dart';
import 'order_item.dart';

/// OrderHistory model to represent orders in the history list
class OrderHistory {
  final int id;
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

  factory OrderHistory.fromOrder(Order order) {
    return OrderHistory(
      id: order.id ?? 0,
      serviceType: order.serviceType,
      total: order.total,
      status: order.status,
      createdAt: order.createdAt != null ? DateTime.parse(order.createdAt!) : DateTime.now(),
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
    return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
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
  
  switch (this) {
    case OrderTimeFilter.today:
      return date.year == now.year && 
             date.month == now.month && 
             date.day == now.day;
    
    case OrderTimeFilter.weekly:
      // Calculate days since start of week (assuming Sunday is first day of week)
      final daysSinceStartOfWeek = now.weekday; // 1=Monday, 7=Sunday
      final startOfWeek = now.subtract(Duration(days: daysSinceStartOfWeek - 1));
      final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      
      return date.isAfter(startOfWeekDate.subtract(const Duration(seconds: 1)));
    
    case OrderTimeFilter.monthly:
      // First day of current month
      final startOfMonth = DateTime(now.year, now.month, 1);
      return date.isAfter(startOfMonth.subtract(const Duration(seconds: 1)));
    
    case OrderTimeFilter.yearly:
      // First day of current year
      final startOfYear = DateTime(now.year, 1, 1);
      return date.isAfter(startOfYear.subtract(const Duration(seconds: 1)));
    
    case OrderTimeFilter.all:
      return true;
  }
}
  
}