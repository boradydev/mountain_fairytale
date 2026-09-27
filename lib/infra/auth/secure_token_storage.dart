import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mountain_fairytale/infra/auth/token_storage.dart';

class SecureTokenStorage implements TokenStorage {
  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';

  final FlutterSecureStorage _storage;

  SecureTokenStorage({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> getAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  @override
  Future<String?> getRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(
      key: _accessTokenKey,
      value: accessToken,
    );

    await _storage.write(
      key: _refreshTokenKey,
      value: refreshToken,
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
