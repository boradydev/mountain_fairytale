class AuthUserModel {
  final String username;

  const AuthUserModel({
    required this.username,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      username: json['username'] as String,
    );
  }
}
