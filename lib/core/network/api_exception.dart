import 'dart:convert';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? ownerName;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.ownerName,
  });

  factory ApiException.fromResponse({
    required int statusCode,
    required String body,
  }) {
    String message = 'Ошибка запроса к серверу.';
    String? ownerName;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        ownerName = decoded['ownerName'] as String?;
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
    return ApiException(
      statusCode: statusCode,
      message: message,
      ownerName: ownerName,
    );
  }

  @override
  String toString() => message;
}
