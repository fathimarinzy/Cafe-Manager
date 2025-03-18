class MenuItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String category; // Added missing category
  final bool isAvailable; 
  int quantity; 

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category, // Ensure it's required
    this.isAvailable = true, 
    this.quantity = 1, 
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'].toString(), // Ensure id is a String
      name: json['name'],
      price: (json['price'] as num).toDouble(), // Ensure price is double
      imageUrl: json['image'], // Corrected key
      category: json['category'], // Added missing category
      isAvailable: json['available'] ?? true, // Ensure default value
      quantity: json.containsKey('quantity') ? json['quantity'] : 1, // Ensure default quantity
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'available': isAvailable,
      'quantity': quantity,
    };
  }
}
