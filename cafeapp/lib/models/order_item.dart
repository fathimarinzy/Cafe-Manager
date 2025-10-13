// In OrderItem class:
class OrderItem {
  final int id;
  final String name;
  final double price;
  final int quantity;
  final String kitchenNote;
  final bool taxExempt; // NEW: Add this field

  OrderItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.kitchenNote = '',
    this.taxExempt = false, // NEW: Default to false
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      name: json['name'],
      price: json['price'].toDouble(),
      quantity: json['quantity'],
      kitchenNote: json['kitchenNote'] ?? '',
      taxExempt: json['taxExempt'] ?? false, // NEW
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'name': name,
      'price': price,
      'quantity': quantity,
      'kitchenNote': kitchenNote,
      'taxExempt': taxExempt, // NEW
    };
  }
}