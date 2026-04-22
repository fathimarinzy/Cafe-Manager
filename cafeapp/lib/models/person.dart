// models/person.dart
class Person {
  final String? id;
  final String name;
  final String phoneNumber;
  final String place;
  final String dateVisited;
  final double credit; // Add this field
  final String? updatedAt; // Last updated timestamp

  Person({
    this.id,
    required this.name,
    required this.phoneNumber,
    required this.place,
    required this.dateVisited,
    this.credit = 0.0, // Default to 0
    this.updatedAt,
  });

  // Add copyWith method for easy updates
  Person copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? place,
    String? dateVisited,
    double? credit,
    String? updatedAt,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      place: place ?? this.place,
      dateVisited: dateVisited ?? this.dateVisited,
      credit: credit ?? this.credit,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Factory method to create Person from JSON
  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'].toString(),
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      place: json['place'],
      dateVisited: json['dateVisited'],
      credit: (json['credit'] ?? 0.0).toDouble(), // Add credit with default value
      updatedAt: json['updated_at'] ?? json['updatedAt'] as String?,
    );
  }

  // Convert Person to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'place': place,
      'dateVisited': dateVisited,
      'credit': credit, // Include credit in JSON
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(), // Ensure sync engine resolves conflicts correctly
    };
  }
}