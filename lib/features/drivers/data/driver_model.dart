class Driver {
  final String id;
  final String name;
  final DateTime createdAt;
  final bool isActive;

  const Driver({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isActive,
  });

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
    id: json['driverId'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isActive: json['isActive'] as bool,
  );
  Map<String, dynamic> toJson() => {
    'driverId': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };
}

class CreateDriverRequest {
  final String name;
  const CreateDriverRequest({required this.name});
  Map<String, dynamic> toJson() => {'name': name};
}

class UpdateDriverRequest {
  final String? name;
  final bool? isActive;
  const UpdateDriverRequest({this.name, this.isActive});
  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (isActive != null) 'isActive': isActive,
  };
}
