// lib/models/sync_order_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'order.dart' as order_model;
import 'order_item.dart';

class SyncOrderModel {
  final int? id;
  final int? staffOrderNumber; // Staff device's local order number
  final int? mainOrderNumber; // Main device's global order number (null until assigned)
  final String staffDeviceId; // Device that created the order
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
  final bool mainNumberAssigned; // Whether main order number has been assigned
  final String? lastUpdatedBy;
  // NEW: Catering and Delivery fields
  final double? deliveryCharge;
  final String? deliveryAddress;
  final String? deliveryBoy;
  final String? eventDate;
  final String? eventTime;
  final int? eventGuestCount;
  final String? eventType;
  final String? tokenNumber;
  final String? customerName;
  final double? depositAmount;

  SyncOrderModel({
    this.id,
    this.staffOrderNumber,
    this.mainOrderNumber,
    required this.staffDeviceId,
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
    this.mainNumberAssigned = false,
    this.lastUpdatedBy,
    this.deliveryCharge,
    this.deliveryAddress,
    this.deliveryBoy,
    this.eventDate,
    this.eventTime,
    this.eventGuestCount,
    this.eventType,
    this.tokenNumber,
    this.customerName,
    this.depositAmount,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffOrderNumber': staffOrderNumber,
      'mainOrderNumber': mainOrderNumber,
      'staffDeviceId': staffDeviceId,
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
      'isSynced': isSynced,
      'syncedAt': syncedAt,
      'mainNumberAssigned': mainNumberAssigned,
      
      // Conditional fields - omit if null to satisfy Firestore strict type checks
      if (customerId != null) 'customerId': customerId,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (cashAmount != null) 'cashAmount': cashAmount,
      if (bankAmount != null) 'bankAmount': bankAmount,
      if (lastUpdatedBy != null) 'lastUpdatedBy': lastUpdatedBy,
      if (deliveryCharge != null) 'deliveryCharge': deliveryCharge,
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      if (deliveryBoy != null) 'deliveryBoy': deliveryBoy,
      if (eventDate != null) 'eventDate': eventDate,
      if (eventTime != null) 'eventTime': eventTime,
      if (eventGuestCount != null) 'eventGuestCount': eventGuestCount,
      if (eventType != null) 'eventType': eventType,
      if (tokenNumber != null) 'tokenNumber': tokenNumber,
      if (customerName != null) 'customerName': customerName,
      if (depositAmount != null) 'depositAmount': depositAmount,
    };
  }

  // Create from JSON (Firestore data) - FIXED to handle Timestamp
  factory SyncOrderModel.fromJson(Map<String, dynamic> json) {
    // Helper function to convert Firestore Timestamp to String
    String? timestampToString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is Timestamp) return value.toDate().toIso8601String();
      return null;
    }

    return SyncOrderModel(
      id: json['id'] as int?,
      staffOrderNumber: json['staffOrderNumber'] as int?,
      mainOrderNumber: json['mainOrderNumber'] as int?,
      staffDeviceId: json['staffDeviceId'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      serviceType: json['serviceType'] as String? ?? 'Dine-in', // Fallback to avoid crash
      items: (json['items'] as List?)?.map((item) => OrderItem(
        id: item['id'] as int,
        name: item['name'] as String,
        price: (item['price'] as num).toDouble(),
        quantity: item['quantity'] as int,
        kitchenNote: item['kitchenNote'] as String? ?? '',
        taxExempt: item['taxExempt'] as bool? ?? false,
      )).toList() ?? [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
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
      syncedAt: timestampToString(json['syncedAt']),
      mainNumberAssigned: json['mainNumberAssigned'] as bool? ?? false,
      lastUpdatedBy: json['lastUpdatedBy'] as String?,
      deliveryCharge: json['deliveryCharge'] != null ? (json['deliveryCharge'] as num).toDouble() : null,
      deliveryAddress: json['deliveryAddress'] as String?,
      deliveryBoy: json['deliveryBoy'] as String?,
      eventDate: json['eventDate'] as String?,
      eventTime: json['eventTime'] as String?,
      eventGuestCount: json['eventGuestCount'] as int?,
      eventType: json['eventType'] as String?,
      tokenNumber: json['tokenNumber'] as String?,
      customerName: json['customerName'] as String?,
      depositAmount: json['depositAmount'] != null ? (json['depositAmount'] as num).toDouble() : null,
    );
  }

  // Create from local Order model
  factory SyncOrderModel.fromOrder(order_model.Order order, String deviceId, String companyId) {
    return SyncOrderModel(
      id: order.id,
      staffOrderNumber: order.staffOrderNumber,
      mainOrderNumber: order.mainOrderNumber,
      staffDeviceId: order.staffDeviceId.isNotEmpty ? order.staffDeviceId : deviceId,
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
      isSynced: order.isSynced,
      syncedAt: order.syncedAt,
      mainNumberAssigned: order.mainNumberAssigned,
      deliveryCharge: order.deliveryCharge,
      deliveryAddress: order.deliveryAddress,
      deliveryBoy: order.deliveryBoy,
      eventDate: order.eventDate,
      eventTime: order.eventTime,
      eventGuestCount: order.eventGuestCount,
      eventType: order.eventType,
      tokenNumber: order.tokenNumber,
      customerName: order.customerName,
      depositAmount: order.depositAmount,
    );
  }

  // Convert to local Order model
  order_model.Order toOrder() {
    return order_model.Order(
      id: id,
      staffOrderNumber: staffOrderNumber,
      mainOrderNumber: mainOrderNumber,
      staffDeviceId: staffDeviceId,
      serviceType: serviceType,
      items: items,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      total: total,
      status: status,
      createdAt: createdAt,
      customerId: customerId,
      paymentMethod: paymentMethod,
      cashAmount: cashAmount,
      bankAmount: bankAmount,
      isSynced: isSynced,
      syncedAt: syncedAt,
      mainNumberAssigned: mainNumberAssigned,
      deliveryCharge: deliveryCharge,
      deliveryAddress: deliveryAddress,
      deliveryBoy: deliveryBoy,
      eventDate: eventDate,
      eventTime: eventTime,
      eventGuestCount: eventGuestCount,
      eventType: eventType,
      tokenNumber: tokenNumber,
      customerName: customerName,
      depositAmount: depositAmount,
    );
  }

  // Copy with method for updates
  SyncOrderModel copyWith({
    int? id,
    int? staffOrderNumber,
    int? mainOrderNumber,
    String? staffDeviceId,
    String? companyId,
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
    String? lastUpdatedBy,
    double? deliveryCharge,
    String? deliveryAddress,
    String? deliveryBoy,
    String? eventDate,
    String? eventTime,
    int? eventGuestCount,
    String? eventType,
    String? tokenNumber,
    String? customerName,
    double? depositAmount,
  }) {
    return SyncOrderModel(
      id: id ?? this.id,
      staffOrderNumber: staffOrderNumber ?? this.staffOrderNumber,
      mainOrderNumber: mainOrderNumber ?? this.mainOrderNumber,
      staffDeviceId: staffDeviceId ?? this.staffDeviceId,
      companyId: companyId ?? this.companyId,
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
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryBoy: deliveryBoy ?? this.deliveryBoy,
      eventDate: eventDate ?? this.eventDate,
      eventTime: eventTime ?? this.eventTime,
      eventGuestCount: eventGuestCount ?? this.eventGuestCount,
      eventType: eventType ?? this.eventType,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      customerName: customerName ?? this.customerName,
      depositAmount: depositAmount ?? this.depositAmount,
    );
  }

  @override
  String toString() {
    return 'SyncOrderModel(id: $id, staffOrderNumber: $staffOrderNumber, mainOrderNumber: $mainOrderNumber, '
           'staffDeviceId: $staffDeviceId, companyId: $companyId, '
           'serviceType: $serviceType, total: $total, status: $status, '
           'isSynced: $isSynced, mainNumberAssigned: $mainNumberAssigned)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is SyncOrderModel &&
      other.id == id &&
      other.staffOrderNumber == staffOrderNumber &&
      other.mainOrderNumber == mainOrderNumber &&
      other.staffDeviceId == staffDeviceId &&
      other.companyId == companyId &&
      other.serviceType == serviceType &&
      other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      staffOrderNumber.hashCode ^
      mainOrderNumber.hashCode ^
      staffDeviceId.hashCode ^
      companyId.hashCode ^
      serviceType.hashCode ^
      status.hashCode;
  }
}