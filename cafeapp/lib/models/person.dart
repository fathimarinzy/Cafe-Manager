// models/person.dart
class Person {
  final String? id;
  final String name;
  final String phoneNumber;
  final String place;
  final String dateVisited;

  Person({
    this.id,
    required this.name,
    required this.phoneNumber,
    required this.place,
    required this.dateVisited,
  });

  // Factory method to create Person from JSON
  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      place: json['place'],
      dateVisited: json['dateVisited'],
    );
  }

  // Convert Person to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'place': place,
    };
  }
}