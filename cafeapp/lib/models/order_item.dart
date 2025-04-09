class OrderItem {
  final int id;
  final String name;
  final double price;
  final int quantity;

  OrderItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: int.parse(json['id']),
      name: json['name'],
      price: json['price'].toDouble(),
      quantity: json['quantity'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
       'name': name,
      'price': price,
      'quantity': quantity,
    };
  }
}