import 'dart:async';
import 'dart:convert';
import 'dart:io';

class HttpTransport {
  final String baseUrl;
  final HttpClient _client;
  final Duration requestTimeout;

  HttpTransport({
    required this.baseUrl,
    HttpClient? client,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? HttpClient() {
    _client.connectionTimeout = requestTimeout;
  }

  Future<HttpTransportResponse> get(
    String path, {
    Map<String, String>? headers,
  }) => _send(method: 'GET', path: path, headers: headers);

  Future<HttpTransportResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => _send(method: 'POST', path: path, headers: headers, body: body);

  Future<HttpTransportResponse> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => _send(method: 'PATCH', path: path, headers: headers, body: body);

  Future<HttpTransportResponse> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => _send(method: 'PUT', path: path, headers: headers, body: body);

  Future<HttpTransportResponse> delete(
    String path, {
    Map<String, String>? headers,
  }) => _send(method: 'DELETE', path: path, headers: headers);

  Future<HttpTransportResponse> _send({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  }) {
    HttpClientRequest? request;
    var timedOut = false;
    Future<HttpTransportResponse> perform() async {
      final uri = Uri.parse("${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path");
      final opened = await _client.openUrl(method, uri);
      request = opened;
      if (timedOut) {
        opened.abort();
        throw TimeoutException('API request timed out.', requestTimeout);
      }
      opened.headers.contentType = ContentType.json;
      opened.headers.set(HttpHeaders.acceptHeader, 'application/json');
      opened.headers.set(
        HttpHeaders.userAgentHeader,
        'MountainFairytale/1.0 Windows',
      );
      headers?.forEach(opened.headers.set);
      if (body != null) opened.write(jsonEncode(body));
      final response = await opened.close();
      final responseBody = await utf8.decoder.bind(response).join();
      return HttpTransportResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    }

    return perform().timeout(
      requestTimeout,
      onTimeout: () {
        timedOut = true;
        request?.abort();
        throw TimeoutException('API request timed out.', requestTimeout);
      },
    );
  }

  void close() => _client.close(force: true);
}

class HttpTransportResponse {
  final int statusCode;
  final String body;

  const HttpTransportResponse({required this.statusCode, required this.body});
}
