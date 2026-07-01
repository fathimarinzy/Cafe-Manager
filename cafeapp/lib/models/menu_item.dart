// lib/models/menu_item.dart
import 'dart:convert';

class ItemSize {
  final String name;
  final double price;
  final double purchasePrice;

  ItemSize({
    required this.name,
    required this.price,
    this.purchasePrice = 0.0,
  });

  factory ItemSize.fromJson(Map<String, dynamic> json) {
    return ItemSize(
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      purchasePrice: json['purchasePrice'] != null ? (json['purchasePrice'] as num).toDouble() : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'purchasePrice': purchasePrice,
    };
  }
}

class MenuItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String category;
  final bool isAvailable;
  int quantity;
  String kitchenNote;
  final bool taxExempt; 
  final bool isPerPlate; 
  final double purchasePrice;
  final String barcode;
  final List<ItemSize> sizes; // NEW: Item variants

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
    this.isAvailable = true,
    this.quantity = 1,
    String? kitchenNote,
    this.taxExempt = false, 
    this.isPerPlate = false, 
    this.purchasePrice = 0.0,
    this.barcode = '',
    List<ItemSize>? sizes,
  })  : kitchenNote = kitchenNote ?? '',
        sizes = sizes ?? [];

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    List<ItemSize> parsedSizes = [];
    if (json['sizes'] != null) {
      if (json['sizes'] is String) {
        try {
          var decoded = jsonDecode(json['sizes']) as List;
          parsedSizes = decoded.map((s) => ItemSize.fromJson(s as Map<String, dynamic>)).toList();
        } catch (e) {
          // Ignore parsing errors for sizes
        }
      } else if (json['sizes'] is List) {
        parsedSizes = (json['sizes'] as List).map((s) => ItemSize.fromJson(s as Map<String, dynamic>)).toList();
      }
    }

    return MenuItem(
      id: json['id'].toString(),
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image'] ?? '',
      category: json['category'],
      isAvailable: json['available'] ?? true,
      quantity: json.containsKey('quantity') ? json['quantity'] : 1,
      kitchenNote: json['kitchenNote'] ?? '',
      taxExempt: json['taxExempt'] ?? false, 
      isPerPlate: json['isPerPlate'] ?? false, 
      purchasePrice: json['purchasePrice'] != null ? (json['purchasePrice'] as num).toDouble() : 0.0,
      barcode: json['barcode'] ?? '',
      sizes: parsedSizes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'image': imageUrl,
      'category': category,
      'available': isAvailable,
      'quantity': quantity,
      'kitchenNote': kitchenNote,
      'taxExempt': taxExempt, 
      'isPerPlate': isPerPlate, 
      'purchasePrice': purchasePrice,
      'barcode': barcode,
      'sizes': sizes.map((s) => s.toJson()).toList(),
      'lastUpdated': DateTime.now().toIso8601String(), 
    };
  }

  MenuItem copyWith({
    String? id,
    String? name,
    double? price,
    String? imageUrl,
    String? category,
    bool? isAvailable,
    int? quantity,
    String? kitchenNote,
    bool? taxExempt, 
    bool? isPerPlate, 
    double? purchasePrice,
    String? barcode,
    List<ItemSize>? sizes,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      quantity: quantity ?? this.quantity,
      kitchenNote: kitchenNote ?? this.kitchenNote,
      taxExempt: taxExempt ?? this.taxExempt, 
      isPerPlate: isPerPlate ?? this.isPerPlate, 
      purchasePrice: purchasePrice ?? this.purchasePrice,
      barcode: barcode ?? this.barcode,
      sizes: sizes ?? this.sizes,
    );
  }
}