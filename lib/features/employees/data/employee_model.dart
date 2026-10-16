class Employee {
  final String id;
  final String username;
  final String role;
  final double? commissionPercent;
  final bool isActive;
  final DateTime createdAt;

  const Employee({
    required this.id,
    required this.username,
    required this.role,
    required this.commissionPercent,
    required this.isActive,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: json['employeeId'] as String,
    username: json['username'] as String,
    role: json['role'] as String,
    commissionPercent: (json['commissionPercent'] as num?)?.toDouble(),
    isActive: json['isActive'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class CreateEmployeeRequest {
  final String username;
  final String password;
  final double? commissionPercent;

  const CreateEmployeeRequest({
    required this.username,
    required this.password,
    this.commissionPercent,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'commissionPercent': commissionPercent,
  };
}

class UpdateEmployeeRequest {
  final String? username;
  final double? commissionPercent;
  final bool clearCommissionPercent;
  final bool? isActive;

  const UpdateEmployeeRequest({
    this.username,
    this.commissionPercent,
    this.clearCommissionPercent = false,
    this.isActive,
  }) : assert(!clearCommissionPercent || commissionPercent == null);

  Map<String, dynamic> toJson() => {
    if (username != null) 'username': username,
    if (clearCommissionPercent || commissionPercent != null)
      'commissionPercent': clearCommissionPercent ? null : commissionPercent,
    if (isActive != null) 'isActive': isActive,
  };
}
