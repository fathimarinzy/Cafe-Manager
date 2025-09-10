// models/person.dart
class Person {
  final String? id;
  final String name;
  final String phoneNumber;
  final String place;
  final String dateVisited;
  final double credit; // Add this field

  Person({
    this.id,
    required this.name,
    required this.phoneNumber,
    required this.place,
    required this.dateVisited,
    this.credit = 0.0, // Default to 0
  });

  // Add copyWith method for easy updates
  Person copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? place,
    String? dateVisited,
    double? credit,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      place: place ?? this.place,
      dateVisited: dateVisited ?? this.dateVisited,
      credit: credit ?? this.credit,
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
    };
  }
}