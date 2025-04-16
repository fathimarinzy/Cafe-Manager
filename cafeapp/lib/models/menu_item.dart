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

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
    this.isAvailable = true,
    this.quantity = 1,
    String? kitchenNote, // Accept nullable parameter
  }) : kitchenNote = kitchenNote ?? ''; // Removed unnecessary 'this.'

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'].toString(),
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image'] ?? '', // Handle null image
      category: json['category'],
      isAvailable: json['available'] ?? true,
      quantity: json.containsKey('quantity') ? json['quantity'] : 1,
      kitchenNote: json['kitchenNote'] ?? '', // Handle null kitchenNote
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
      'kitchenNote': kitchenNote, // Include kitchen note in JSON
    };
  }

  // Create a copy with modified attributes
  MenuItem copyWith({
    String? id,
    String? name,
    double? price,
    String? imageUrl,
    String? category,
    bool? isAvailable,
    int? quantity,
    String? kitchenNote,
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
    );
  }
}