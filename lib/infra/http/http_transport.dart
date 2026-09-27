import 'dart:convert';
import 'dart:io';

class HttpTransport {
  final String baseUrl;
  final HttpClient _client;

  HttpTransport({
    required this.baseUrl,
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  Future<HttpTransportResponse> get(
    String path, {
    Map<String, String>? headers,
  }) {
    return _send(
      method: 'GET',
      path: path,
      headers: headers,
    );
  }

  Future<HttpTransportResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _send(
      method: 'POST',
      path: path,
      headers: headers,
      body: body,
    );
  }

  Future<HttpTransportResponse> _send({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    final request = await _client.openUrl(method, uri);

    request.headers.contentType = ContentType.json;

    headers?.forEach((key, value) {
      request.headers.set(key, value);
    });

    if (body != null) {
      request.write(jsonEncode(body));
    }

    final response = await request.close();

    final responseBody = await utf8.decoder.bind(response).join();

    return HttpTransportResponse(
      statusCode: response.statusCode,
      body: responseBody,
    );
  }
}

class HttpTransportResponse {
  final int statusCode;
  final String body;

  const HttpTransportResponse({
    required this.statusCode,
    required this.body,
  });
}
