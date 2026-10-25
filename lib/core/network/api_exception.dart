import 'dart:convert';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? ownerName;
  final String? requestId;
  final Map<String, dynamic> data;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.ownerName,
    this.requestId,
    this.data = const {},
  });

  factory ApiException.fromResponse({
    required int statusCode,
    required String body,
    String? requestId,
  }) {
    String message = 'Ошибка запроса к серверу.';
    String? ownerName;
    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
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
      requestId: requestId,
      statusCode: statusCode,
      message: message,
      ownerName: ownerName,
      data: data,
    );
  }

  @override
  String toString() => message;
}
