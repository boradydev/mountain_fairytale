import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';

class BaseFormDialog extends StatelessWidget {
  final String title;
  final String submitButtonText;
  final VoidCallback onSubmit;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  const BaseFormDialog({
    super.key,
    required this.title,
    required this.submitButtonText,
    required this.onSubmit,
    required this.formKey,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500, // Единая ширина для всех десктопных форм
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
                const SizedBox(height: 16),
                ...children,
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppSecondaryButton(
                      onPressed: () => Navigator.of(context).pop(),
                      text: 'Отмена',
                    ),
                    const SizedBox(width: 8),
                    AppPrimaryButton(
                      onPressed: onSubmit,
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
