import 'dart:async';
import 'dart:io';

import 'package:mountain_fairytale/core/network/api_exception.dart';

class SessionChangedException implements Exception {
  const SessionChangedException();
}

String authErrorMessage(Object error, {bool loggingIn = false}) {
  if (error is SessionChangedException) {
    return 'Сессия завершена. Войдите снова.';
  }
  if (error is TimeoutException ||
      error is SocketException ||
      error is HttpException ||
      error is HandshakeException) {
    return 'Сервер недоступен. Проверьте соединение и повторите попытку.';
  }
  if (error is ApiException) {
    if (error.statusCode >= 500) {
      return 'Сервер временно недоступен. Повторите попытку позже.';
    }
    return switch (error.statusCode) {
      401 =>
        loggingIn
            ? 'Неверный пароль.'
            : 'Сессия завершена. Войдите снова.',
      403 => 'Недостаточно прав для выполнения действия.',
      422 => 'Проверьте введённые данные.',
      _ => error.message,
    };
  }
  if (error is FormatException || error is TypeError) {
    return 'Не удалось прочитать ответ сервера. Повторите попытку.';
  }
  return 'Не удалось выполнить действие. Повторите попытку.';
}
