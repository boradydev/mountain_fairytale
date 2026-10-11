import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mountain_fairytale/features/auth/ui/auth_errors.dart';
import 'package:mountain_fairytale/features/auth/auth_abcs.dart';
import 'package:mountain_fairytale/features/auth/auth_abcs.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/features/auth/data/auth_tokens_model.dart';
import 'package:mountain_fairytale/features/auth/data/auth_user_model.dart';
import 'package:mountain_fairytale/features/auth/data/current_employee_model.dart';
import 'package:mountain_fairytale/features/auth/auth_abcs.dart';

class AuthServiceImpl extends ChangeNotifier implements AuthService {
  final AuthRepository _repository;
  final TokenStorage _tokenStorage;

  String? _accessToken;
  CurrentEmployeeModel? _currentUser;
  int _sessionVersion = 0;
  int _tokenRevision = 0;
  Future<bool>? _refreshFuture;
  Future<void> _storageQueue = Future<void>.value();

  AuthServiceImpl({
    required this._repository,
    required this._tokenStorage,
  });

  @override
  bool get isAuthenticated => _accessToken != null && _currentUser != null;

  @override
  String? get accessToken => _accessToken;

  @override
  CurrentEmployeeModel? get currentUser => _currentUser;

  @override
  int get sessionVersion => _sessionVersion;

  @override
  Future<bool> restoreSession() {
    if (isAuthenticated) return Future.value(true);
    return refresh();
  }

  @override
  Future<void> login({
    required String username,
    required String password,
  }) async {
    final version = _invalidateSession();
    await _storageTask(_tokenStorage.clear);
    _checkVersion(version);
    final tokens = await _repository.login(
      username: username,
      password: password,
    );
    _checkVersion(version);
    final user = await _repository.getMe(accessToken: tokens.accessToken);
    await _commitTokens(tokens, user, version);
  }

  @override
  Future<List<AuthUserModel>> getUsers() => _repository.getUsers();

  @override
  Future<bool> refresh() {
    final existing = _refreshFuture;
    if (existing != null) return existing;

    final version = _sessionVersion;
    late final Future<bool> future;
    future = _refreshInternal(version).whenComplete(() {
      if (identical(_refreshFuture, future)) _refreshFuture = null;
    });
    _refreshFuture = future;
    return future;
  }

  Future<bool> _refreshInternal(int version) async {
    var readingProfile = false;
    try {
      final refreshToken = await _storageTask(_tokenStorage.getRefreshToken);
      if (version != _sessionVersion) return false;
      if (refreshToken == null || refreshToken.isEmpty) {
        await _endSession(version);
        return false;
      }

      final tokens = await _repository.refresh(refreshToken: refreshToken);
      if (version != _sessionVersion) return false;
      readingProfile = true;
      final user = await _repository.getMe(accessToken: tokens.accessToken);
      await _commitTokens(tokens, user, version);
      return true;
    } on SessionChangedException {
      return false;
    } on ApiException catch (error) {
      if (version != _sessionVersion) return false;
      if (error.statusCode == 401 ||
          error.statusCode == 403 ||
          (readingProfile && error.statusCode == 404)) {
        await _endSession(version);
        return false;
      }
      // Network failures, 5xx and invalid responses preserve the saved pair.
      rethrow;
    }
  }

  @override
  Future<T> authenticatedRequest<T>(
    Future<T> Function(String accessToken) request,
  ) async {
    final version = _sessionVersion;
    final originalToken = _accessToken;
    final originalRevision = _tokenRevision;
    if (!isAuthenticated || originalToken == null) {
      throw const ApiException(
        statusCode: 401,
        message: 'Сессия не восстановлена.',
      );
    }

    try {
      final result = await request(originalToken);
      _checkVersion(version);
      return result;
    } on ApiException catch (error) {
      _checkVersion(version);
      if (error.statusCode != 401) rethrow;
    }

    // Another request may already have completed refresh for this token.
    if (_tokenRevision == originalRevision && !await refresh()) {
      throw const ApiException(statusCode: 401, message: 'Сессия завершена.');
    }
    _checkVersion(version);
    final newToken = _accessToken;
    if (newToken == null) throw const SessionChangedException();

    try {
      final result = await request(newToken);
      _checkVersion(version);
      return result;
    } on ApiException catch (error) {
      _checkVersion(version);
      if (error.statusCode == 401) await _endSession(version);
      rethrow;
    }
  }

  @override
  Future<void> changePassword({required String password}) =>
      authenticatedRequest(
        (token) =>
            _repository.changePassword(accessToken: token, password: password),
      );

  @override
  Future<void> logout() async {
    final token = _accessToken;
    _invalidateSession();
    // Clear local credentials before waiting for any server response.
    final clear = _storageTask(_tokenStorage.clear);
    if (token != null) {
      unawaited(
        _repository.logout(accessToken: token).catchError((Object _) {
          // Local logout succeeds even when the server is unreachable.
        }),
      );
    }
    await clear;
  }

  int _invalidateSession() {
    final version = ++_sessionVersion;
    _accessToken = null;
    _currentUser = null;
    _refreshFuture = null;
    notifyListeners();
    return version;
  }

  Future<void> _endSession(int version) async {
    if (version != _sessionVersion) return;
    _invalidateSession();
    await _storageTask(_tokenStorage.clear);
  }

  Future<void> _commitTokens(
    AuthTokensModel tokens,
    CurrentEmployeeModel user,
    int version,
  ) async {
    await _storageTask(() async {
      _checkVersion(version);
      await _tokenStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      _checkVersion(version);
      _accessToken = tokens.accessToken;
      _currentUser = user;
      _tokenRevision++;
    });
    _checkVersion(version);
    notifyListeners();
  }

  // Serialize persistence so a refresh finishing after logout cannot leave
  // credentials on disk or overwrite a newer user's tokens.
  Future<T> _storageTask<T>(Future<T> Function() task) {
    final operation = _storageQueue.then((_) => task());
    _storageQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  void _checkVersion(int version) {
    if (version != _sessionVersion) throw const SessionChangedException();
  }
}
