// Update the OrderItem class in lib/models/order_item.dart

class OrderItem {
  final int id;
  final String name;
  final double price;
  final int quantity;
  final String kitchenNote; // Add this field

  OrderItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.kitchenNote = '', // Default to empty string
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      name: json['name'],
      price: json['price'].toDouble(),
      quantity: json['quantity'],
      kitchenNote: json['kitchenNote'] ?? '', // Parse from JSON
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'name': name,
      'price': price,
      'quantity': quantity,
      'kitchenNote': kitchenNote, // Include in JSON
    };
  }
}