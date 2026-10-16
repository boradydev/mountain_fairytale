import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

class BaseFormDialog extends StatelessWidget {
  final String title;
  final String submitButtonText;
  final VoidCallback onSubmit;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final bool isBusy;

  /// Загрузка операции формы; место под полоску сохраняется и в покое.
  /// Проверку дубликатов отображает DuplicateCheckStatusWidget отдельно.
  final bool isLoading;
  final bool canSubmit;

  /// Дополнительное действие слева от кнопок.
  ///
  /// Например, кнопка удаления в режиме редактирования.
  final Widget? leadingAction;

  const BaseFormDialog({
    super.key,
    required this.title,
    required this.submitButtonText,
    required this.onSubmit,
    required this.formKey,
    required this.children,
    this.leadingAction,
    this.isBusy = false,
    this.isLoading = false,
    this.canSubmit = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                SizedBox(
                  height: 16,
                  child: isLoading
                      ? const Center(
                          child: LinearProgressIndicator(minHeight: 4),
                        )
                      : null,
                ),

                ...children,

                const SizedBox(height: 24),

                Row(
                  children: [
                    ?leadingAction,

                    const Spacer(),

                    AppSecondaryButton(
                      onPressed: isBusy
                          ? null
                          : () => Navigator.of(context).pop(),
                      text: 'Отмена',
                    ),
                    const SizedBox(width: 8),
                    AppPrimaryButton(
                      onPressed: isBusy || !canSubmit ? null : onSubmit,
                      text: submitButtonText,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
