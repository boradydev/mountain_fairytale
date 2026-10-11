import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mountain_fairytale/infra/auth/token_storage.dart';

class SecureTokenStorage implements TokenStorage {
  static const _tokensKey = 'auth_tokens';
  static const _legacyAccessTokenKey = 'auth_access_token';
  static const _legacyRefreshTokenKey = 'auth_refresh_token';

  final FlutterSecureStorage _storage;

  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<Map<String, dynamic>?> _readPair() async {
    final value = await _storage.read(key: _tokensKey);
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid stored token pair.');
    }
    return decoded;
  }

  @override
  Future<String?> getAccessToken() async {
    final pair = await _readPair();
    return pair == null
        ? _storage.read(key: _legacyAccessTokenKey)
        : pair['accessToken'] as String?;
  }

  @override
  Future<String?> getRefreshToken() async {
    final pair = await _readPair();
    return pair == null
        ? _storage.read(key: _legacyRefreshTokenKey)
        : pair['refreshToken'] as String?;
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) => _storage.write(
    key: _tokensKey,
    // One secure-storage write keeps the two JWTs together.
    value: jsonEncode({
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    }),
  );

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _tokensKey),
      _storage.delete(key: _legacyRefreshTokenKey),
      _storage.delete(key: _legacyAccessTokenKey),
    ]);
  }
}
