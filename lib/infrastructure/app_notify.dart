import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/widgets/snack_bar_widget.dart';

/// Глобальный менеджер для отображения всплывающих уведомлений (SnackBars).
///
/// Предоставляет унифицированный интерфейс для показа системных уведомлений
/// без необходимости вручную вызывать [ScaffoldMessenger]
/// и управлять очередью сообщений.
class AppNotify {
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      buildCustomSnackBar(
        context,
        message,
        isError: isError,
        isWarning: isWarning,
      ),
    );
  }
}
