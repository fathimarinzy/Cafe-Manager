
class DeliveryBoy {
  final String? id;
  final String name;
  final String phoneNumber;

  DeliveryBoy({
    this.id,
    required this.name,
    required this.phoneNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
    };
  }

  factory DeliveryBoy.fromMap(Map<String, dynamic> map) {
    return DeliveryBoy(
      id: map['id'] as String?,
      name: map['name'] as String,
      phoneNumber: map['phoneNumber'] as String,
    );
  }
}
