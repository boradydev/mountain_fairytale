import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/widgets/snack_bar_widget.dart';

/// Глобальный менеджер для отображения всплывающих уведомлений (SnackBars).
///
/// Предоставляет унифицированный интерфейс для показа системных уведомлений
/// без необходимости вручную вызывать [ScaffoldMessenger]
/// и управлять очередью сообщений.
///
/// ### ⚠️ ВАЖНОЕ ПРАВИЛО БЕЗОПАСНОСТИ (Async Gaps):
/// Если этот метод вызывается **после `await`** (асинхронного запроса),
/// обязательно проверяйте, что контекст или стейт все еще активны (mounted).
/// Иначе приложение упадет с ошибкой, если пользователь успел закрыть экран.
///
/// **Пример использования:**
///
/// *1. Внутри StatefulWidget (проверяем `mounted` самого State):*
/// ```dart
/// await provider.loadData();
/// if (!mounted) return; // Защита от async gap для State.context
/// AppNotify.show(context, 'Успешно!');
/// ```
///
/// *2. Вне StatefulWidget / В функциях (проверяем `context.mounted`):*
/// ```dart
/// await provider.loadData();
/// if (!context.mounted) return; // Защита для локального BuildContext
/// AppNotify.show(context, 'Успешно!');
/// ```
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
