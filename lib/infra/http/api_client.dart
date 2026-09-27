import 'dart:convert';

import 'package:mountain_fairytale/infra/auth/auth_service.dart';
import 'package:mountain_fairytale/infra/http/api_exception.dart';
import 'package:mountain_fairytale/infra/http/http_transport.dart';

class ApiClient {
  final HttpTransport _transport;
  final AuthService _authService;
  final String userAgent;

  ApiClient({
    required this._transport,
    required this._authService,
    required this.userAgent,
  });

  Future<Map<String, dynamic>> get(
    String path,
  ) async {
    final response = await _send(
      method: 'GET',
      path: path,
    );

    return _decodeJson(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
  }) async {
    final response = await _send(
      method: 'POST',
      path: path,
      body: body,
    );

    return _decodeJson(response);
  }

  Future<List<dynamic>> getList(
    String path,
  ) async {
    final response = await _send(
      method: 'GET',
      path: path,
    );

    return _decodeJsonList(response);
  }

  Future<List<dynamic>> postList(
    String path, {
    Object? body,
  }) async {
    final response = await _send(
      method: 'POST',
      path: path,
      body: body,
    );

    return _decodeJsonList(response);
  }

  Future<HttpTransportResponse> _send({
    required String method,
    required String path,
    Object? body,
    bool retryAfterRefresh = true,
  }) async {
    final headers = <String, String>{
      'User-Agent': userAgent,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final accessToken = _authService.accessToken;

    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final response = await _transportRequest(
      method: method,
      path: path,
      headers: headers,
      body: body,
    );

    if (response.statusCode != 401 || !retryAfterRefresh) {
      _checkResponse(response);
      return response;
    }

    final refreshed = await _authService.refresh();

    if (!refreshed) {
      throw ApiException(
        statusCode: 401,
        message: 'Authentication expired.',
      );
    }

    return _send(
      method: method,
      path: path,
      body: body,
      retryAfterRefresh: false,
    );
  }

  Future<HttpTransportResponse> _transportRequest({
    required String method,
    required String path,
    required Map<String, String> headers,
    Object? body,
  }) {
    switch (method) {
      case 'GET':
        return _transport.get(
          path,
          headers: headers,
        );

      case 'POST':
        return _transport.post(
          path,
          headers: headers,
          body: body,
        );

      default:
        throw UnsupportedError('HTTP method $method is not supported.');
    }
  }

  Map<String, dynamic> _decodeJson(
    HttpTransportResponse response,
  ) {
    _checkResponse(response);

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected JSON object.',
      );
    }

    return decoded;
  }

  List<dynamic> _decodeJsonList(
    HttpTransportResponse response,
  ) {
    _checkResponse(response);

    final decoded = jsonDecode(response.body);

    if (decoded is! List<dynamic>) {
      throw const FormatException(
        'Expected JSON array.',
      );
    }

    return decoded;
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
