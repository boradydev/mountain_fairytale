class CurrentEmployeeModel {
  final String employeeId;
  final String username;
  final String role;

  const CurrentEmployeeModel({
    required this.employeeId,
    required this.username,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

  factory CurrentEmployeeModel.fromJson(Map<String, dynamic> json) {
    return CurrentEmployeeModel(
      employeeId: json['employeeId'] as String,
      username: json['username'] as String,
      role: json['role'] as String,
    );
  }
}
