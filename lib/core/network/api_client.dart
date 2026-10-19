import 'dart:convert';

import 'package:mountain_fairytale/features/auth/auth_abcs.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';

class ApiClient {
  final HttpTransport _transport;
  final AuthService _authService;
  final String userAgent;

  ApiClient({
    required this._transport,
    required this._authService,
    required this.userAgent,
  });

  Future<Map<String, dynamic>> get(String path) async =>
      _decodeJson(await _send(method: 'GET', path: path));

  Future<Map<String, dynamic>> longPoll(
    String path,
    HttpRequestCancellation cancellation,
  ) async => _decodeJson(
    await _send(method: 'LONG_POLL', path: path, cancellation: cancellation),
  );

  Future<Map<String, dynamic>> post(String path, {Object? body}) async =>
      _decodeJson(await _send(method: 'POST', path: path, body: body));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) async =>
      _decodeJson(await _send(method: 'PATCH', path: path, body: body));

  Future<Map<String, dynamic>> put(String path, {Object? body}) async =>
      _decodeJson(await _send(method: 'PUT', path: path, body: body));

  Future<Map<String, dynamic>> delete(String path) async =>
      _decodeJson(await _send(method: 'DELETE', path: path));

  Future<List<dynamic>> getList(String path) async =>
      _decodeJsonList(await _send(method: 'GET', path: path));

  Future<List<dynamic>> postList(String path, {Object? body}) async =>
      _decodeJsonList(await _send(method: 'POST', path: path, body: body));

  Future<HttpTransportResponse> _send({
    required String method,
    required String path,
    Object? body,
    HttpRequestCancellation? cancellation,
  }) {
    return _authService.authenticatedRequest((accessToken) async {
      final headers = <String, String>{
        'User-Agent': userAgent,
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      final response = await switch (method) {
        'LONG_POLL' => _transport.getLongPolling(
          path,
          headers: headers,
          cancellation: cancellation,
        ),
        'GET' => _transport.get(path, headers: headers),
        'POST' => _transport.post(
          path,
          headers: headers,
          body: body,
          timeout: path.endsWith('/geocode') || path.endsWith('/optimize-order')
              ? const Duration(seconds: 40)
              : null,
        ),
        'PUT' => _transport.put(path, headers: headers, body: body),
        'PATCH' => _transport.patch(path, headers: headers, body: body),
        'DELETE' => _transport.delete(path, headers: headers),
        _ => throw UnsupportedError('HTTP method $method is not supported.'),
      };
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.fromResponse(
          statusCode: response.statusCode,
          body: response.body,
        );
      }
      return response;
    });
  }

  Map<String, dynamic> _decodeJson(HttpTransportResponse response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected StdResponse JSON object.');
    }
    return decoded;
  }

  List<dynamic> _decodeJsonList(HttpTransportResponse response) {
    final data = _decodeJson(response)['data'];
    if (data is! List<dynamic>) {
      throw const FormatException('Expected StdResponse.data array.');
    }
    return data;
  }
}
