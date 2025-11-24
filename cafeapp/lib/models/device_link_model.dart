// lib/models/device_link_model.dart
class DeviceLinkCode {
  final String code;
  final String companyId;
  final String mainDeviceId;
  final String mainDeviceName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isUsed;
  final String? usedByDeviceId;
  final String? usedByDeviceName;

  DeviceLinkCode({
    required this.code,
    required this.companyId,
    required this.mainDeviceId,
    required this.mainDeviceName,
    required this.createdAt,
    required this.expiresAt,
    this.isUsed = false,
    this.usedByDeviceId,
    this.usedByDeviceName,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'companyId': companyId,
      'mainDeviceId': mainDeviceId,
      'mainDeviceName': mainDeviceName,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isUsed': isUsed,
      'usedByDeviceId': usedByDeviceId,
      'usedByDeviceName': usedByDeviceName,
    };
  }

  factory DeviceLinkCode.fromJson(Map<String, dynamic> json) {
    return DeviceLinkCode(
      code: json['code'] as String,
      companyId: json['companyId'] as String,
      mainDeviceId: json['mainDeviceId'] as String,
      mainDeviceName: json['mainDeviceName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isUsed: json['isUsed'] as bool? ?? false,
      usedByDeviceId: json['usedByDeviceId'] as String?,
      usedByDeviceName: json['usedByDeviceName'] as String?,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isUsed && !isExpired;

  DeviceLinkCode copyWith({
    String? code,
    String? companyId,
    String? mainDeviceId,
    String? mainDeviceName,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isUsed,
    String? usedByDeviceId,
    String? usedByDeviceName,
  }) {
    return DeviceLinkCode(
      code: code ?? this.code,
      companyId: companyId ?? this.companyId,
      mainDeviceId: mainDeviceId ?? this.mainDeviceId,
      mainDeviceName: mainDeviceName ?? this.mainDeviceName,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isUsed: isUsed ?? this.isUsed,
      usedByDeviceId: usedByDeviceId ?? this.usedByDeviceId,
      usedByDeviceName: usedByDeviceName ?? this.usedByDeviceName,
    );
  }
}