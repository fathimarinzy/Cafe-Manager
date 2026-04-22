
class DeliveryBoy {
  final String? id;
  final String name;
  final String phoneNumber;
  final String? updatedAt; // Last updated timestamp

  DeliveryBoy({
    this.id,
    required this.name,
    required this.phoneNumber,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(), // Ensure sync engine resolves conflicts correctly
    };
  }

  factory DeliveryBoy.fromMap(Map<String, dynamic> map) {
    return DeliveryBoy(
      id: map['id'] as String?,
      name: map['name'] as String,
      phoneNumber: map['phoneNumber'] as String,
      updatedAt: map['updated_at'] ?? map['updatedAt'] as String?,
    );
  }
}
