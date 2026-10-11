import 'package:mountain_fairytale/features/auth/data/auth_tokens_model.dart';
import 'package:mountain_fairytale/features/auth/data/auth_user_model.dart';
import 'package:mountain_fairytale/features/auth/data/current_employee_model.dart';
import 'package:flutter/foundation.dart';

abstract interface class AuthRepository {
  Future<AuthTokensModel> login({
    required String username,
    required String password,
  });

  Future<AuthTokensModel> refresh({required String refreshToken});

  Future<List<AuthUserModel>> getUsers();

  Future<CurrentEmployeeModel> getMe({required String accessToken});

  Future<void> changePassword({
    required String accessToken,
    required String password,
  });

  Future<void> logout({required String accessToken});
}

abstract interface class AuthService implements Listenable {
  bool get isAuthenticated;
  String? get accessToken;
  CurrentEmployeeModel? get currentUser;

  /// Changes when login/logout ends one local session and starts another.
  int get sessionVersion;

  Future<bool> restoreSession();

  Future<void> login({required String username, required String password});

  Future<List<AuthUserModel>> getUsers();

  Future<bool> refresh();

  /// One shared refresh and at most one retry for a protected request.
  Future<T> authenticatedRequest<T>(
    Future<T> Function(String accessToken) request,
  );

  Future<void> changePassword({required String password});

  Future<void> logout();
}

abstract interface class TokenStorage {
  Future<String?> getAccessToken();

  Future<String?> getRefreshToken();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  Future<void> clear();
}
