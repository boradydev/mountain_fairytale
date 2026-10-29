import 'package:flutter/foundation.dart';

void printModel(
  Map<String, dynamic> json, {
  String title = 'MODEL DATA',
  int maxLength = 100, // Значение по умолчанию
}) {
  debugPrint('--- $title ---');

  final buffer = StringBuffer();

  json.forEach((key, value) {
    String valueStr = value.toString();

    // Используем переданный лимит из аргументов
    if (valueStr.length > maxLength) {
      valueStr = '${valueStr.substring(0, maxLength)}...';
    }

    buffer.write('$key: $valueStr | ');
  });

  final result = buffer.toString();
  debugPrint(
    result.isNotEmpty ? result.substring(0, result.length - 3) : result,
  );
  debugPrint('-' * (title.length + 8));
}
