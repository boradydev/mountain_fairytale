import 'dart:convert';

import 'package:mountain_fairytale/infra/http/api_exception.dart';
import 'package:mountain_fairytale/infra/http/http_transport.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/auth_tokens_model.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/auth_user_model.dart';

class AuthApiDataSource {
  final HttpTransport _transport;

  AuthApiDataSource({
    required this._transport,
  });

  Future<AuthTokensModel> login({
    required String username,
    required String password,
  }) async {
    final response = await _transport.post(
      '/auth/login',
      body: {
        'username': username,
        'password': password,
      },
    );

    _checkResponse(response);

    return AuthTokensModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AuthTokensModel> refresh({
    required String refreshToken,
  }) async {
    final response = await _transport.post(
      '/auth/refresh',
      body: {
        'refresh_token': refreshToken,
      },
    );

    _checkResponse(response);

    return AuthTokensModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> logout({
    required String refreshToken,
  }) async {
    final response = await _transport.post(
      '/auth/logout',
      body: {
        'refresh_token': refreshToken,
      },
    );

    _checkResponse(response);
  }

  Future<List<AuthUserModel>> getUsers() async {
    final response = await _transport.get(
      '/auth/users',
    );

    _checkResponse(response);

    final json = jsonDecode(response.body);

    if (json is! List) {
      throw const FormatException(
        'Expected JSON array.',
      );
    }

    return json
        .map(
          (item) => AuthUserModel.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> register({
    required String username,
    required String password,
  }) async {
    final response = await _transport.post(
      '/auth/register',
      body: {
        'username': username,
        'password': password,
      },
    );

    _checkResponse(response);
  }

  void _checkResponse(HttpTransportResponse response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: response.body,
    );
  }
}
