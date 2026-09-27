import 'package:flutter/foundation.dart';

import 'package:mountain_fairytale/infra/auth/auth_service.dart';

enum AuthStatus {
  initializing,
  authenticated,
  unauthenticated,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.initializing;

  bool _isLoading = false;

  String? _error;

  AuthProvider({
    required this._authService,
  });

  AuthStatus get status => _status;

  bool get isLoading => _isLoading;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  String? get error => _error;

  Future<void> restoreSession() async {
    _status = AuthStatus.initializing;
    _error = null;

    notifyListeners();

    final restored = await _authService.restoreSession();

    _status = restored ? AuthStatus.authenticated : AuthStatus.unauthenticated;

    notifyListeners();
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;

    notifyListeners();

    try {
      await _authService.login(
        username: username,
        password: password,
      );

      _status = AuthStatus.authenticated;

      return true;
    } catch (error) {
      _error = error.toString();
      _status = AuthStatus.unauthenticated;

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;

    notifyListeners();

    try {
      await _authService.logout();
    } finally {
      _status = AuthStatus.unauthenticated;
      _isLoading = false;

      notifyListeners();
    }
  }
}
