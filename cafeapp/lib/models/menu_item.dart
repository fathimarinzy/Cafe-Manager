class MenuItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String category;
  final bool isAvailable;
  int quantity;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
    this.isAvailable = true,
    this.quantity = 1,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    // This is the critical part - make sure to use the correct key 'image'
    // that matches what your backend returns
    return MenuItem(
      id: json['id'].toString(),
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image'] ?? '', // Make sure to use the correct key
      category: json['category'],
      isAvailable: json['available'] ?? true,
      quantity: json.containsKey('quantity') ? json['quantity'] : 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'image': imageUrl, // Make sure to use the correct key
      'category': category,
      'available': isAvailable,
      'quantity': quantity,
    };
  }
}