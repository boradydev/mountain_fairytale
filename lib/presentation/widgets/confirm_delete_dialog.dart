import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';

class ConfirmDeleteDialog extends StatelessWidget {
  final String entityName;

  const ConfirmDeleteDialog({super.key, required this.entityName});

  static Future<bool> show(
    BuildContext context, {
    required String entityName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDeleteDialog(entityName: entityName),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Удалить?'),
      content: Text('Вы действительно хотите удалить $entityName?'),
      actions: [
        AppSecondaryButton(
          text: 'Отмена',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Удалить'),
        ),
      ],
    );
  }
}
