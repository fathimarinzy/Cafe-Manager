// lib/models/device_model.dart
import 'package:cafeapp/models/order.dart';
import 'package:cafeapp/models/order_item.dart';

class DeviceModel {
  final String id;
  final String deviceName;
  final String deviceType; // 'android', 'windows', 'macos', 'linux'
  final String companyId;
  final bool isMainDevice;
  final DateTime registeredAt;
  final DateTime? lastSyncedAt;
  final bool isActive;

  DeviceModel({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.companyId,
    this.isMainDevice = false,
    required this.registeredAt,
    this.lastSyncedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'companyId': companyId,
      'isMainDevice': isMainDevice,
      'registeredAt': registeredAt.toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      deviceName: json['deviceName'] as String,
      deviceType: json['deviceType'] as String,
      companyId: json['companyId'] as String,
      isMainDevice: json['isMainDevice'] as bool? ?? false,
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      lastSyncedAt: json['lastSyncedAt'] != null 
          ? DateTime.parse(json['lastSyncedAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  DeviceModel copyWith({
    String? id,
    String? deviceName,
    String? deviceType,
    String? companyId,
    bool? isMainDevice,
    DateTime? registeredAt,
    DateTime? lastSyncedAt,
    bool? isActive,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      companyId: companyId ?? this.companyId,
      isMainDevice: isMainDevice ?? this.isMainDevice,
      registeredAt: registeredAt ?? this.registeredAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

// lib/models/sync_order_model.dart
class SyncOrderModel {
  final int? id;
  final String deviceId;
  final String companyId;
  final String serviceType;
  final List<OrderItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final String status;
  final String createdAt;
  final String? customerId;
  final String? paymentMethod;
  final double? cashAmount;
  final double? bankAmount;
  final bool isSynced;
  final String? syncedAt;

  SyncOrderModel({
    this.id,
    required this.deviceId,
    required this.companyId,
    required this.serviceType,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    required this.status,
    required this.createdAt,
    this.customerId,
    this.paymentMethod,
    this.cashAmount,
    this.bankAmount,
    this.isSynced = false,
    this.syncedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'companyId': companyId,
      'serviceType': serviceType,
      'items': items.map((item) => {
        'id': item.id,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'kitchenNote': item.kitchenNote,
        'taxExempt': item.taxExempt,
      }).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': total,
      'status': status,
      'createdAt': createdAt,
      'customerId': customerId,
      'paymentMethod': paymentMethod,
      'cashAmount': cashAmount,
      'bankAmount': bankAmount,
      'isSynced': isSynced,
      'syncedAt': syncedAt,
    };
  }

  factory SyncOrderModel.fromJson(Map<String, dynamic> json) {
    return SyncOrderModel(
      id: json['id'] as int?,
      deviceId: json['deviceId'] as String,
      companyId: json['companyId'] as String,
      serviceType: json['serviceType'] as String,
      items: (json['items'] as List).map((item) => OrderItem(
        id: item['id'] as int,
        name: item['name'] as String,
        price: (item['price'] as num).toDouble(),
        quantity: item['quantity'] as int,
        kitchenNote: item['kitchenNote'] as String? ?? '',
        taxExempt: item['taxExempt'] as bool? ?? false,
      )).toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      tax: (json['tax'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: json['createdAt'] as String,
      customerId: json['customerId'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      cashAmount: json['cashAmount'] != null 
          ? (json['cashAmount'] as num).toDouble()
          : null,
      bankAmount: json['bankAmount'] != null 
          ? (json['bankAmount'] as num).toDouble()
          : null,
      isSynced: json['isSynced'] as bool? ?? false,
      syncedAt: json['syncedAt'] as String?,
    );
  }

  factory SyncOrderModel.fromOrder(Order order, String deviceId, String companyId) {
    return SyncOrderModel(
      id: order.id,
      deviceId: deviceId,
      companyId: companyId,
      serviceType: order.serviceType,
      items: order.items,
      subtotal: order.subtotal,
      tax: order.tax,
      discount: order.discount,
      total: order.total,
      status: order.status,
      createdAt: order.createdAt ?? DateTime.now().toIso8601String(),
      customerId: order.customerId,
      paymentMethod: order.paymentMethod,
      cashAmount: order.cashAmount,
      bankAmount: order.bankAmount,
    );
  }
}