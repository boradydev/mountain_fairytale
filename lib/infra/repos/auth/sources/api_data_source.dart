import 'dart:convert';

import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/auth_tokens_model.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/auth_user_model.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/current_employee_model.dart';

class AuthApiDataSource {
  final HttpTransport _transport;

  AuthApiDataSource({required this._transport});

  Future<AuthTokensModel> login({
    required String username,
    required String password,
  }) async {
    final response = await _transport.post(
      '/public/auth/login',
      body: {'username': username, 'password': password},
    );
    return AuthTokensModel.fromJson(_data(response));
  }

  Future<AuthTokensModel> refresh({required String refreshToken}) async {
    final response = await _transport.post(
      '/public/auth/refresh',
      body: {'refreshToken': refreshToken},
    );
    return AuthTokensModel.fromJson(_data(response));
  }

  Future<List<AuthUserModel>> getUsers() async {
    final response = await _transport.get('/public/auth/users');
    final usernames = _data(response)['usernames'];
    if (usernames is! List || usernames.any((item) => item is! String)) {
      throw const FormatException(
        'Expected data.usernames to be a string array.',
      );
    }
    return usernames
        .map((username) => AuthUserModel(username: username as String))
        .toList(growable: false);
  }

  Future<CurrentEmployeeModel> getMe({required String accessToken}) async {
    final response = await _transport.get(
      '/protected/me',
      headers: _bearer(accessToken),
    );
    return CurrentEmployeeModel.fromJson(_data(response));
  }

  Future<void> changePassword({
    required String accessToken,
    required String password,
  }) async {
    final response = await _transport.put(
      '/protected/me/change-password',
      headers: _bearer(accessToken),
      body: {'password': password},
    );
    _checkResponse(response);
  }

  Future<void> logout({required String accessToken}) async {
    final response = await _transport.post(
      '/protected/me/logout',
      headers: _bearer(accessToken),
    );
    _checkResponse(response);
  }

  Map<String, String> _bearer(String token) => {
    'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _data(HttpTransportResponse response) {
    _checkResponse(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['data'] is! Map<String, dynamic>) {
      throw const FormatException('Expected StdResponse.data to be an object.');
    }
    return decoded['data'] as Map<String, dynamic>;
  }

  void _checkResponse(HttpTransportResponse response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiException.fromResponse(
      statusCode: response.statusCode,
      body: response.body,
    );
  }
}
