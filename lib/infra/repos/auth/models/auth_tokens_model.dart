class AuthTokensModel {
  final String accessToken;
  final String refreshToken;

  const AuthTokensModel({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthTokensModel.fromJson(Map<String, dynamic> json) {
    return AuthTokensModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
    };
  }
}
