import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

/// Keeps the current form intact while server state cannot be verified.
class DocumentConnectionDialog extends StatelessWidget {
  final OrderPointsProvider provider;
  const DocumentConnectionDialog({super.key, required this.provider});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: ListenableBuilder(
      listenable: provider,
      builder: (context, _) => AlertDialog(
        title: Text(
          provider.connectionIssue == DocumentConnectionIssue.server
              ? 'Не удаётся проверить состояние сервера'
              : 'Нет связи с сервером',
        ),
        content: SizedBox(
          width: 420,
          child: Text(
            provider.connectionIssue == DocumentConnectionIssue.server
                ? 'Сервер временно не может подтвердить состояние документа. '
                      'Введённые данные остаются в открытой форме. '
                      'Попробуем восстановить работу и проверить актуальность документа.'
                : 'Введённые данные остаются в открытой форме. '
                      'Перед продолжением проверим соединение и актуальность документа. '
                      'Если вы нажимали «Сохранить», проверим, принял ли сервер изменения.',
          ),
        ),
        actions: [
          SizedBox(
            width: 32,
            height: 40,
            child: Center(
              child: provider.reconnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
          AppPrimaryButton(
            text: 'Повторить подключение',
            onPressed: provider.reconnecting ? null : provider.retryConnection,
          ),
        ],
      ),
    ),
  );
}
