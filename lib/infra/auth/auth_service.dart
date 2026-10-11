import 'package:flutter/foundation.dart';

import 'package:mountain_fairytale/infra/repos/auth/models/auth_user_model.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/current_employee_model.dart';

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
