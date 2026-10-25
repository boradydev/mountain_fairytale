import 'dart:async';
import 'dart:convert';
import 'dart:io';

class HttpRequestCancellation {
  bool _cancelled = false;
  void Function()? _abort;
  bool get isCancelled => _cancelled;
  void cancel() {
    _cancelled = true;
    _abort?.call();
  }
}

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
    Duration? timeout,
  }) => _send(
    method: 'POST',
    path: path,
    headers: headers,
    body: body,
    timeout: timeout,
  );

  Future<HttpTransportResponse> getLongPolling(
    String path, {
    Map<String, String>? headers,
    HttpRequestCancellation? cancellation,
  }) => _send(
    method: 'GET',
    path: path,
    headers: headers,
    timeout: const Duration(seconds: 35),
    cancellation: cancellation,
  );

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
    Duration? timeout,
    HttpRequestCancellation? cancellation,
  }) {
    HttpClientRequest? request;
    var timedOut = false;
    final effectiveTimeout = timeout ?? requestTimeout;
    cancellation?._abort = () =>
        request?.abort(const HttpException('Request cancelled'));
    Future<HttpTransportResponse> perform() async {
      if (cancellation?.isCancelled ?? false) {
        throw const HttpException('Request cancelled');
      }
      final uri = Uri.parse("${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path");
      final opened = await _client.openUrl(method, uri);
      request = opened;
      if (cancellation?.isCancelled ?? false) {
        opened.abort();
        throw const HttpException('Request cancelled');
      }
      if (timedOut) {
        opened.abort();
        throw TimeoutException('API request timed out.', effectiveTimeout);
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
        requestId: response.headers.value('X-Request-ID'),
      );
    }

    return perform()
        .timeout(
          effectiveTimeout,
          onTimeout: () {
            timedOut = true;
            request?.abort();
            throw TimeoutException('API request timed out.', effectiveTimeout);
          },
        )
        .whenComplete(() {
          cancellation?._abort = null;
        });
  }

  void close() => _client.close(force: true);
}

class HttpTransportResponse {
  final int statusCode;
  final String body;
  final String? requestId;

  const HttpTransportResponse({
    required this.statusCode,
    required this.body,
    this.requestId,
  });
}
