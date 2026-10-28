import 'package:flutter/foundation.dart';

import 'package:mountain_fairytale/features/auth/ui/auth_errors.dart';
import 'package:mountain_fairytale/features/auth/auth_abcs.dart';
import 'package:mountain_fairytale/features/auth/data/auth_user_model.dart';
import 'package:mountain_fairytale/features/auth/data/current_employee_model.dart';

enum AuthStatus {
  initializing,
  authenticated,
  unauthenticated,
  serverUnavailable,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.initializing;
  bool _isLoading = false;
  bool _isLoadingUsers = false;
  bool _isChangingPassword = false;
  bool _isRestoring = false;
  bool _disposed = false;
  int _operationId = 0;
  int _usersRequest = 0;
  int _passwordRequest = 0;
  String? _error;
  String? _usersError;
  List<AuthUserModel> _users = const [];

  AuthProvider({required this._authService}) {
    _authService.addListener(_onSessionChanged);
  }

  AuthStatus get status => _status;
  bool get isLoading => _isLoading;
  bool get isLoadingUsers => _isLoadingUsers;
  bool get isChangingPassword => _isChangingPassword;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  int get sessionVersion => _authService.sessionVersion;
  CurrentEmployeeModel? get currentUser => _authService.currentUser;
  String? get error => _error;
  String? get usersError => _usersError;
  List<AuthUserModel> get users => _users;

  void clearLoginError() {
    if (_error == null || _isLoading || _status != AuthStatus.unauthenticated) {
      return;
    }
    _error = null;
    _notify();
  }

  void _onSessionChanged() {
    if (_authService.isAuthenticated) {
      _status = AuthStatus.authenticated;
      _error = null;
    } else if (_status == AuthStatus.authenticated && !_isLoading) {
      _passwordRequest++;
      _isChangingPassword = false;
      _status = AuthStatus.unauthenticated;
      _users = const [];
      _error = 'Сессия завершена. Войдите снова.';
    }
    _notify();
  }

  Future<void> restoreSession() async {
    if (_isRestoring || _isLoading || isAuthenticated) return;
    final operation = ++_operationId;
    _isRestoring = true;
    _status = AuthStatus.initializing;
    _error = null;
    _notify();
    try {
      final restored = await _authService.restoreSession();
      if (operation != _operationId) return;
      _status = restored
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
    } catch (error) {
      if (operation != _operationId) return;
      _status = AuthStatus.serverUnavailable;
      _error = authErrorMessage(error);
    } finally {
      if (operation == _operationId) _isRestoring = false;
      _notify();
    }
  }

  Future<void> loadUsers() async {
    if (_isLoadingUsers) return;
    final request = ++_usersRequest;
    _isLoadingUsers = true;
    _users = const [];
    _usersError = null;
    _notify();
    try {
      final users = await _authService.getUsers();
      if (request == _usersRequest) _users = users;
    } catch (error) {
      if (request == _usersRequest) _usersError = authErrorMessage(error);
    } finally {
      if (request == _usersRequest) _isLoadingUsers = false;
      _notify();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    if (_isLoading || _isRestoring) return false;
    final operation = ++_operationId;
    _isLoading = true;
    _error = null;
    _notify();
    try {
      await _authService.login(username: username, password: password);
      if (operation != _operationId) return false;
      _status = AuthStatus.authenticated;
      return true;
    } catch (error) {
      if (operation != _operationId) return false;
      _error = authErrorMessage(error, loggingIn: true);
      _status = AuthStatus.unauthenticated;
      return false;
    } finally {
      if (operation == _operationId) _isLoading = false;
      _notify();
    }
  }

  Future<bool> changePassword({required String password}) async {
    if (_isChangingPassword || !isAuthenticated) return false;
    final request = ++_passwordRequest;
    final version = sessionVersion;
    _isChangingPassword = true;
    _error = null;
    _notify();
    try {
      await _authService.changePassword(password: password);
      return request == _passwordRequest && version == sessionVersion;
    } catch (error) {
      if (request != _passwordRequest || version != sessionVersion) {
        return false;
      }
      _error = authErrorMessage(error);
      return false;
    } finally {
      if (request == _passwordRequest) _isChangingPassword = false;
      _notify();
    }
  }

  Future<void> logout() async {
    final operation = ++_operationId;
    _isRestoring = false;
    _usersRequest++;
    _passwordRequest++;
    _isChangingPassword = false;
    _isLoadingUsers = false;
    _isLoading = true;
    _status = AuthStatus.initializing;
    _error = null;
    _notify();
    try {
      await _authService.logout();
    } catch (_) {
      if (operation == _operationId) {
        _error = 'Не удалось очистить сохранённый вход. Повторите выход.';
      }
    } finally {
      if (operation == _operationId) {
        _status = AuthStatus.unauthenticated;
        _isLoading = false;
        _users = const [];
        _usersError = null;
      }
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authService.removeListener(_onSessionChanged);
    super.dispose();
  }
}
