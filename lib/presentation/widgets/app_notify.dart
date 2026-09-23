import 'package:mountain_fairytale/core/utils/scaffold_messenger_key.dart'; // Импортируйте созданный ключ
import 'package:mountain_fairytale/presentation/widgets/snack_bar_widget.dart';

/// Глобальный менеджер для отображения всплывающих уведомлений (SnackBars).
/// Больше не требует BuildContext при вызове.
class AppNotify {
  static void show(
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    final state = scaffoldMessengerKey.currentState;
    if (state == null) return; // Если мессенджер еще не готов, выходим

    // Сбрасываем текущий SnackBar перед показом нового
    state.hideCurrentSnackBar();

    // Показываем новый SnackBar, используя контекст мессенджера
    state.showSnackBar(
      buildAppSnackBar(
        state.context,
        message,
        isError: isError,
        isWarning: isWarning,
      ),
    );
  }
}
