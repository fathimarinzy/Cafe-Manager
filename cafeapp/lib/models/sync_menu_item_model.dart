// lib/models/sync_menu_item_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'menu_item.dart';

class SyncMenuItemModel {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String category;
  final bool isAvailable;
  final bool taxExempt;
  final String companyId;
  final String deviceId;
  final DateTime lastUpdated;
  final String? syncedAt;

  SyncMenuItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.isAvailable,
    required this.taxExempt,
    required this.companyId,
    required this.deviceId,
    required this.lastUpdated,
    this.syncedAt,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'isAvailable': isAvailable,
      'taxExempt': taxExempt,
      'companyId': companyId,
      'deviceId': deviceId,
      'lastUpdated': lastUpdated.toIso8601String(),
      'syncedAt': syncedAt,
    };
  }

  // Create from JSON (Firestore data)
  factory SyncMenuItemModel.fromJson(Map<String, dynamic> json) {
    String? timestampToString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is Timestamp) return value.toDate().toIso8601String();
      return null;
    }

    return SyncMenuItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String? ?? '',
      category: json['category'] as String,
      isAvailable: json['isAvailable'] as bool? ?? true,
      taxExempt: json['taxExempt'] as bool? ?? false,
      companyId: json['companyId'] as String,
      deviceId: json['deviceId'] as String,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      syncedAt: timestampToString(json['syncedAt']),
    );
  }

  // Create from local MenuItem
  factory SyncMenuItemModel.fromMenuItem(
    MenuItem item,
    String deviceId,
    String companyId,
  ) {
    return SyncMenuItemModel(
      id: item.id,
      name: item.name,
      price: item.price,
      imageUrl: item.imageUrl,
      category: item.category,
      isAvailable: item.isAvailable,
      taxExempt: item.taxExempt,
      companyId: companyId,
      deviceId: deviceId,
      lastUpdated: DateTime.now(),
    );
  }

  // Convert to local MenuItem
  MenuItem toMenuItem() {
    return MenuItem(
      id: id,
      name: name,
      price: price,
      imageUrl: imageUrl,
      category: category,
      isAvailable: isAvailable,
      taxExempt: taxExempt,
    );
  }

  SyncMenuItemModel copyWith({
    String? id,
    String? name,
    double? price,
    String? imageUrl,
    String? category,
    bool? isAvailable,
    bool? taxExempt,
    String? companyId,
    String? deviceId,
    DateTime? lastUpdated,
    String? syncedAt,
  }) {
    return SyncMenuItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      taxExempt: taxExempt ?? this.taxExempt,
      companyId: companyId ?? this.companyId,
      deviceId: deviceId ?? this.deviceId,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  String toString() {
    return 'SyncMenuItemModel(id: $id, name: $name, category: $category, '
           'companyId: $companyId)';
  }
}

// Business Info Sync Model
class SyncBusinessInfoModel {
  final String companyId;
  final String businessName;
  final String secondBusinessName;
  final String businessAddress;
  final String businessPhone;
  final String businessEmail;
  final DateTime lastUpdated;
  final String? syncedAt;

  SyncBusinessInfoModel({
    required this.companyId,
    required this.businessName,
    this.secondBusinessName = '',
    required this.businessAddress,
    required this.businessPhone,
    this.businessEmail = '',
    required this.lastUpdated,
    this.syncedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'companyId': companyId,
      'businessName': businessName,
      'secondBusinessName': secondBusinessName,
      'businessAddress': businessAddress,
      'businessPhone': businessPhone,
      'businessEmail': businessEmail,
      'lastUpdated': lastUpdated.toIso8601String(),
      'syncedAt': syncedAt,
    };
  }

  factory SyncBusinessInfoModel.fromJson(Map<String, dynamic> json) {
    String? timestampToString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is Timestamp) return value.toDate().toIso8601String();
      return null;
    }

    return SyncBusinessInfoModel(
      companyId: json['companyId'] as String,
      businessName: json['businessName'] as String,
      secondBusinessName: json['secondBusinessName'] as String? ?? '',
      businessAddress: json['businessAddress'] as String,
      businessPhone: json['businessPhone'] as String,
      businessEmail: json['businessEmail'] as String? ?? '',
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      syncedAt: timestampToString(json['syncedAt']),
    );
  }
}