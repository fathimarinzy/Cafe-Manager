import 'order_item.dart'; // Ensure this import exists or define OrderItem in this file.
import '../services/api_service.dart';
import 'package:flutter/foundation.dart';


class Order {
  final int? id;
  final String serviceType;
  final List<OrderItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final String status;
  final String? createdAt;

  Order({
    this.id,
    required this.serviceType,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    this.status = 'pending',
    this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int?, // Avoids unnecessary parsing
      serviceType: json['serviceType'] as String,
      items: (json['items'] as List<dynamic>)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      tax: (json['tax'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serviceType': serviceType,
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': total,
      'status': status,
      'createdAt': createdAt,
    };
  }
  
Future<bool> updateOrderPaymentMethod(String paymentMethod) async {
  // Instead of calling getToken() directly, we should use ApiService
  final apiService = ApiService();
  
  if (id == null) {
    debugPrint('Cannot update payment method: Order ID is null');
    return false;
  }
  
  try {
    return await apiService.updateOrderPaymentMethod(id!, paymentMethod);
  } catch (e) {
    debugPrint('Error updating payment method: $e');
    return false;
  }
}
}
