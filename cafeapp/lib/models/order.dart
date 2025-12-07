// lib/models/order.dart
import 'order_item.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart';

class Order {
  final int? id; // Local database ID
  final int? staffOrderNumber; // Staff device's local order number
  final int? mainOrderNumber; // Main device's global order number (assigned after sync)
  final String staffDeviceId; // ID of the staff device that created this order
  final String serviceType;
  final List<OrderItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final String status;
  final String? createdAt;
  final String? customerId;
  final String? paymentMethod;
  final double? cashAmount;
  final double? bankAmount;
  final bool isSynced; // Whether order has been synced to Firestore
  final String? syncedAt; // When order was synced
  final bool mainNumberAssigned; // Whether main order number has been assigned

  Order({
    this.id,
    this.staffOrderNumber,
    this.mainOrderNumber,
    required this.staffDeviceId,
    required this.serviceType,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    this.status = 'pending',
    this.createdAt,
    this.customerId,
    this.paymentMethod = 'cash',
    this.cashAmount,
    this.bankAmount,
    this.isSynced = false,
    this.syncedAt,
    this.mainNumberAssigned = false,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int?,
      staffOrderNumber: json['staffOrderNumber'] as int?,
      mainOrderNumber: json['mainOrderNumber'] as int?,
      staffDeviceId: json['staffDeviceId'] as String? ?? '',
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
      customerId: json['customerId'] as String?,
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
      cashAmount: json['cashAmount'] != null ? (json['cashAmount'] as num).toDouble() : null,
      bankAmount: json['bankAmount'] != null ? (json['bankAmount'] as num).toDouble() : null,
      isSynced: json['isSynced'] as bool? ?? false,
      syncedAt: json['syncedAt'] as String?,
      mainNumberAssigned: json['mainNumberAssigned'] as bool? ?? false,
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
      'customerId': customerId,
      'paymentMethod': paymentMethod,
      'staffOrderNumber': staffOrderNumber,
      'mainOrderNumber': mainOrderNumber,
      'staffDeviceId': staffDeviceId,
      'isSynced': isSynced,
      'syncedAt': syncedAt,
      'mainNumberAssigned': mainNumberAssigned,
      if (cashAmount != null) 'cashAmount': cashAmount,
      if (bankAmount != null) 'bankAmount': bankAmount,
    };
  }

  // Get display order number (staff number for staff devices, main number for main device)
  String getDisplayOrderNumber(bool isMainDevice) {
    if (isMainDevice && mainOrderNumber != null) {
      return mainOrderNumber.toString().padLeft(4, '0');
    }
    return staffOrderNumber?.toString().padLeft(4, '0') ?? '0000';
  }

  Future<bool> updateOrderPaymentMethod(String paymentMethod) async {
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

  Order copyWith({
    int? id,
    int? staffOrderNumber,
    int? mainOrderNumber,
    String? staffDeviceId,
    String? serviceType,
    List<OrderItem>? items,
    double? subtotal,
    double? tax,
    double? discount,
    double? total,
    String? status,
    String? createdAt,
    String? customerId,
    String? paymentMethod,
    double? cashAmount,
    double? bankAmount,
    bool? isSynced,
    String? syncedAt,
    bool? mainNumberAssigned,
  }) {
    return Order(
      id: id ?? this.id,
      staffOrderNumber: staffOrderNumber ?? this.staffOrderNumber,
      mainOrderNumber: mainOrderNumber ?? this.mainOrderNumber,
      staffDeviceId: staffDeviceId ?? this.staffDeviceId,
      serviceType: serviceType ?? this.serviceType,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      customerId: customerId ?? this.customerId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashAmount: cashAmount ?? this.cashAmount,
      bankAmount: bankAmount ?? this.bankAmount,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      mainNumberAssigned: mainNumberAssigned ?? this.mainNumberAssigned,
    );
  }
}