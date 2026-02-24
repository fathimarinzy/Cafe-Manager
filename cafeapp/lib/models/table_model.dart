class TableModel {
  final String id;
  final int number;
  bool isOccupied;
  int capacity;
  String note;
  String category;

  TableModel({
    required this.id,
    required this.number,
    this.isOccupied = false,
    this.capacity = 4,
    this.note = '',
    this.category = 'Main Area',
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'].toString(),
      number: json['number'],
      isOccupied: json['isOccupied'] ?? false,
      capacity: json['capacity'] ?? 4,
      note: json['note'] ?? '',
      category: json['category'] ?? 'Main Area',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'isOccupied': isOccupied,
      'capacity': capacity,
      'note': note,
      'category': category,
    };
  }
}