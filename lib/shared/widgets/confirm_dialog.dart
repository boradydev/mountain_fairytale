import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final bool destructive;
  final Widget? details;
  final bool Function()? validate;
  final double? maxWidth;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = 'Подтвердить',
    this.cancelText = 'Отмена',
    this.destructive = false,
    this.details,
    this.validate,
    this.maxWidth,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'Подтвердить',
    String cancelText = 'Отмена',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        destructive: destructive,
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      constraints: maxWidth == null
          ? null
          : BoxConstraints(minWidth: 280, maxWidth: maxWidth!),
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content),
            if (details != null) ...[
              const SizedBox(height: 16),
              details!,
            ],
          ],
        ),
      ),
      actions: [
        AppSecondaryButton(
          text: cancelText,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppPrimaryButton(
          text: confirmText,
          destructive: destructive,
          onPressed: () {
            if (validate?.call() ?? true) Navigator.of(context).pop(true);
          },
        ),
      ],
    );
  }
}
