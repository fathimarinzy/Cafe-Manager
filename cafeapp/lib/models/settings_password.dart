class SettingsPassword {
  final int id;
  final String password;
  final String userType;
  final bool isActive;

  SettingsPassword({
    required this.id,
    required this.password,
    required this.userType,
    this.isActive = true,
  });

  factory SettingsPassword.fromJson(Map<String, dynamic> json) {
    return SettingsPassword(
      id: json['id'],
      password: json['password'],
      userType: json['userType'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'password': password,
      'userType': userType,
      'isActive': isActive,
    };
  }
}