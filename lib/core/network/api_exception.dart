import 'dart:convert';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({
    required this.statusCode,
    required this.message,
  });

  factory ApiException.fromResponse({
    required int statusCode,
    required String body,
  }) {
    String message = 'Ошибка запроса к серверу.';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String) {
          message = detail;
        } else if (detail is List) {
          final messages = detail
              .whereType<Map<String, dynamic>>()
              .map((item) => item['msg'])
              .whereType<String>();
          if (messages.isNotEmpty) message = messages.join('\n');
        }
      }
    } on FormatException {
      // A proxy may return HTML instead of the API error envelope.
    }
    return ApiException(statusCode: statusCode, message: message);
  }

  @override
  String toString() => message;
}
