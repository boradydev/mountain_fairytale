import 'package:mountain_fairytale/infra/repos/auth/repo.dart';
import 'package:mountain_fairytale/infra/auth/auth_service.dart';
import 'package:mountain_fairytale/infra/auth/token_storage.dart';

class AuthServiceImpl implements AuthService {
  final AuthRepository _repository;
  final TokenStorage _tokenStorage;

  String? _accessToken;

  Future<bool>? _refreshFuture;

  AuthServiceImpl({
    required this._repository,
    required this._tokenStorage,
  });

  @override
  bool get isAuthenticated => _accessToken != null;

  @override
  String? get accessToken => _accessToken;

  @override
  Future<bool> restoreSession() async {
    final refreshToken = await _tokenStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    return refresh();
  }

  @override
  Future<void> login({
    required String username,
    required String password,
  }) async {
    final tokens = await _repository.login(
      username: username,
      password: password,
    );

    await _saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
  }

  @override
  Future<bool> refresh() {
    final existingRefresh = _refreshFuture;

    if (existingRefresh != null) {
      return existingRefresh;
    }

    final future = _refreshInternal();

    _refreshFuture = future;

    future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    });

    return future;
  }

  Future<bool> _refreshInternal() async {
    final refreshToken = await _tokenStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      await _clearSession();
      return false;
    }

    try {
      final tokens = await _repository.refresh(
        refreshToken: refreshToken,
      );

      await _saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      return true;
    } catch (_) {
      await _clearSession();
      return false;
    }
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.getRefreshToken();

    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _repository.logout(
          refreshToken: refreshToken,
        );
      }
    } finally {
      await _clearSession();
    }
  }

  Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;

    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  Future<void> _clearSession() async {
    _accessToken = null;
    await _tokenStorage.clear();
  }
}
