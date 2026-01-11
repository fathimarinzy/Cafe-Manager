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
  final double? depositAmount; // New field for deposit tracking
  final bool isSynced; // Whether order has been synced to Firestore
  final String? syncedAt; // When order was synced
  final bool mainNumberAssigned; // Whether main order number has been assigned
  final String? deliveryAddress;
  final String? deliveryBoy;
  final double? deliveryCharge;
  final String? eventDate;
  final String? eventTime;
  final int? eventGuestCount;
  final String? eventType;
  final String? tokenNumber; // Catering token number
  final String? customerName; // Snapshot of customer name

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
    this.depositAmount,
    this.isSynced = false,
    this.syncedAt,
    this.mainNumberAssigned = false,
    this.deliveryAddress,
    this.deliveryBoy,
    this.deliveryCharge,
    this.eventDate,
    this.eventTime,
    this.eventGuestCount,
    this.eventType,
    this.tokenNumber,
    this.customerName,
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
      depositAmount: json['depositAmount'] != null ? (json['depositAmount'] as num).toDouble() : null,
      isSynced: json['isSynced'] as bool? ?? false,
      syncedAt: json['syncedAt'] as String?,
      mainNumberAssigned: json['mainNumberAssigned'] as bool? ?? false,
      deliveryAddress: json['deliveryAddress'] as String?,
      deliveryBoy: json['deliveryBoy'] as String?,
      deliveryCharge: json['deliveryCharge'] != null ? (json['deliveryCharge'] as num).toDouble() : null,
      eventDate: json['eventDate'] as String?,
      eventTime: json['eventTime'] as String?,
      eventGuestCount: json['eventGuestCount'] as int?,
      eventType: json['eventType'] as String?,
      tokenNumber: json['tokenNumber'] as String?,
      customerName: json['customerName'] as String?,
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
      if (depositAmount != null) 'depositAmount': depositAmount,
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      if (deliveryBoy != null) 'deliveryBoy': deliveryBoy,
      if (deliveryCharge != null) 'deliveryCharge': deliveryCharge,
      if (eventDate != null) 'eventDate': eventDate,
      if (eventTime != null) 'eventTime': eventTime,
      if (eventGuestCount != null) 'eventGuestCount': eventGuestCount,
      if (eventType != null) 'eventType': eventType,
      if (tokenNumber != null) 'tokenNumber': tokenNumber,
      if (customerName != null) 'customerName': customerName,
    };
  }

  // Get display order number (Consistent with OrderHistory/OrderDetailsScreen)
  String getDisplayOrderNumber(bool isMainDevice) {
    // User requested to show the same number everywhere (which is the ID shown in details screen)
    // and explicitly ignores staff/main numbers.
    return id?.toString().padLeft(4, '0') ?? '0000';
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
    double? depositAmount,
    bool? isSynced,
    String? syncedAt,
    bool? mainNumberAssigned,
    String? deliveryAddress,
    String? deliveryBoy,
    double? deliveryCharge,
    String? eventDate,
    String? eventTime,
    int? eventGuestCount,
    String? eventType,
    String? tokenNumber,
    String? customerName,
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
      depositAmount: depositAmount ?? this.depositAmount,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      mainNumberAssigned: mainNumberAssigned ?? this.mainNumberAssigned,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryBoy: deliveryBoy ?? this.deliveryBoy,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      eventDate: eventDate ?? this.eventDate,
      eventTime: eventTime ?? this.eventTime,
      eventGuestCount: eventGuestCount ?? this.eventGuestCount,
      eventType: eventType ?? this.eventType,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      customerName: customerName ?? this.customerName,
    );
  }
}