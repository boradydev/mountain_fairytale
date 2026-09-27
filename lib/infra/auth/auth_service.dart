abstract interface class AuthService {
  bool get isAuthenticated;

  String? get accessToken;

  Future<bool> restoreSession();

  Future<void> login({
    required String username,
    required String password,
  });

  Future<bool> refresh();

  Future<void> logout();
}
