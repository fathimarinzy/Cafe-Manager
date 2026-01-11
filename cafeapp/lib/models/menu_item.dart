// lib/models/menu_item.dart
class MenuItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String category;
  final bool isAvailable;
  int quantity;
  String kitchenNote;
  final bool taxExempt; // NEW: Add this field
  final bool isPerPlate; // NEW: Per-plate pricing flag

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
    this.isAvailable = true,
    this.quantity = 1,
    String? kitchenNote,
    this.taxExempt = false, // NEW: Default to false (tax included)
    this.isPerPlate = false, // NEW: Default to false
  }) : kitchenNote = kitchenNote ?? '';

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'].toString(),
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image'] ?? '',
      category: json['category'],
      isAvailable: json['available'] ?? true,
      quantity: json.containsKey('quantity') ? json['quantity'] : 1,
      kitchenNote: json['kitchenNote'] ?? '',
      taxExempt: json['taxExempt'] ?? false, // NEW: Parse from JSON
      isPerPlate: json['isPerPlate'] ?? false, // NEW

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
      'taxExempt': taxExempt, // NEW: Include in JSON
      'isPerPlate': isPerPlate, // NEW
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
    bool? taxExempt, // NEW: Add to copyWith
    bool? isPerPlate, // NEW

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
      taxExempt: taxExempt ?? this.taxExempt, // NEW
      isPerPlate: isPerPlate ?? this.isPerPlate, // NEW
    );
  }
}