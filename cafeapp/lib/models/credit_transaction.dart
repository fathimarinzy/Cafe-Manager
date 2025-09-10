class CreditTransaction {
  final String id;
  final String customerId;
  final String customerName;
  final String orderNumber;
  final double amount;
  final DateTime createdAt;
  final String serviceType;
  final bool isCompleted; // false for credited, true for completed

  CreditTransaction({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.orderNumber,
    required this.amount,
    required this.createdAt,
    required this.serviceType,
    this.isCompleted = false,
  });

  CreditTransaction copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? orderNumber,
    double? amount,
    DateTime? createdAt,
    String? serviceType,
    bool? isCompleted,
  }) {
    return CreditTransaction(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      orderNumber: orderNumber ?? this.orderNumber,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      serviceType: serviceType ?? this.serviceType,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'orderNumber': orderNumber,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'serviceType': serviceType,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    return CreditTransaction(
      id: json['id'],
      customerId: json['customerId'],
      customerName: json['customerName'],
      orderNumber: json['orderNumber'],
      amount: (json['amount'] ?? 0.0).toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      serviceType: json['serviceType'],
      isCompleted: (json['isCompleted'] ?? 0) == 1,
    );
  }
}