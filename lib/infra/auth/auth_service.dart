import 'package:mountain_fairytale/infra/repos/auth/models/auth_user_model.dart';

abstract interface class AuthService {
  bool get isAuthenticated;

  String? get accessToken;

  Future<bool> restoreSession();

  Future<void> login({
    required String username,
    required String password,
  });

  Future<void> register({
    required String username,
    required String password,
  });

  Future<List<AuthUserModel>> getUsers();

  Future<bool> refresh();

  Future<void> logout();
}
