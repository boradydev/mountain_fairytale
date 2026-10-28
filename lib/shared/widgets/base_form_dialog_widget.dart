import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

class BaseFormDialog extends StatefulWidget {
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
  final double? submitButtonWidth;

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
    this.submitButtonWidth,
  });

  @override
  State<BaseFormDialog> createState() => _BaseFormDialogState();
}

class _BaseFormDialogState extends State<BaseFormDialog> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _scrollableForm(Widget child) {
    final platform = Theme.of(context).platform;
    final desktop =
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.macOS;
    final scrollView = SingleChildScrollView(
      controller: _scrollController,
      // Reserve the scrollbar lane even when the form fits vertically.
      padding: const EdgeInsets.only(right: 16),
      child: child,
    );
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: desktop
          ? Scrollbar(
              controller: _scrollController,
              thickness: 6,
              radius: const Radius.circular(3),
              child: scrollView,
            )
          : scrollView,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        // Move 16 of the original right-hand 24 pixels inside the viewport.
        // Field widths stay unchanged; the scrollbar sits outside the fields.
        padding: const EdgeInsets.fromLTRB(24, 24, 8, 24),
        child: Form(
          key: widget.formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(
                height: 16,
                child: widget.isLoading
                    ? const Center(
                        child: LinearProgressIndicator(minHeight: 4),
                      )
                    : null,
              ),

              Flexible(
                child: _scrollableForm(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.children,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: OverflowBar(
                  alignment: widget.leadingAction == null
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.spaceBetween,
                  spacing: 8,
                  overflowSpacing: 8,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: [
                    ?widget.leadingAction,
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppSecondaryButton(
                          onPressed: widget.isBusy
                              ? null
                              : () => Navigator.of(context).pop(),
                          text: 'Отмена',
                        ),
                        SizedBox(
                          width: widget.submitButtonWidth,
                          child: AppPrimaryButton(
                            onPressed: widget.isBusy || !widget.canSubmit
                                ? null
                                : widget.onSubmit,
                            text: widget.submitButtonText,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
