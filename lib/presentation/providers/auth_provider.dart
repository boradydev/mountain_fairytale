import 'package:flutter/foundation.dart';

import 'package:mountain_fairytale/infra/auth/auth_service.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/auth_user_model.dart';

enum AuthStatus {
  initializing,
  authenticated,
  unauthenticated,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.initializing;

  bool _isLoading = false;
  bool _isRegistering = false;

  String? _error;

  List<AuthUserModel> _users = const [];

  AuthProvider({
    required this._authService,
  });

  AuthStatus get status => _status;

  bool get isLoading => _isLoading;

  bool get isRegistering => _isRegistering;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  String? get error => _error;

  List<AuthUserModel> get users => _users;

  Future<void> restoreSession() async {
    _status = AuthStatus.initializing;
    _error = null;

    notifyListeners();

    final restored = await _authService.restoreSession();

    _status = restored ? AuthStatus.authenticated : AuthStatus.unauthenticated;

    notifyListeners();
  }

  Future<void> loadUsers() async {
    try {
      _users = await _authService.getUsers();
      notifyListeners();
    } catch (_) {
      // Пока список пользователей не является
      // критичным для авторизации.
    }
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

  Future<bool> register({
    required String username,
    required String password,
  }) async {
    _isRegistering = true;
    _error = null;

    notifyListeners();

    try {
      await _authService.register(
        username: username,
        password: password,
      );

      await loadUsers();

      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    } finally {
      _isRegistering = false;
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
