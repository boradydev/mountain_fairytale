import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/theme.dart';
import 'package:mountain_fairytale/core/theme_extensions.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

/// A stable mode indicator shared by delivery and pickup documents.
class DocumentModeBanner extends StatelessWidget {
  final bool creating;
  final bool editing;
  final bool active;
  final String creationTitle;
  final VoidCallback? onEdit;
  final String? message;
  final String? editingBlockedBy;

  const DocumentModeBanner({
    super.key,
    required this.creating,
    required this.editing,
    required this.active,
    required this.creationTitle,
    this.onEdit,
    this.message,
    this.editingBlockedBy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewing = !creating && !editing;
    final cancelled = !creating && !active;
    final blocked = viewing && active && editingBlockedBy != null;
    final warningState = cancelled || blocked;
    final warning =
        Theme.of(context).extension<AppColorsExtension>() ??
        AppTheme.createTheme(scheme.brightness)
            .extension<AppColorsExtension>()!;
    final foreground = cancelled
        ? scheme.onSurface
        : viewing
        ? scheme.onSurface
        : scheme.onPrimaryContainer;
    final title = blocked
        ? 'Документ редактирует другой сотрудник'
        : cancelled
        ? 'Документ отменён'
        : creating
        ? creationTitle
        : editing
        ? 'Редактирование'
        : 'Только просмотр';
    final description =
        (blocked ? editingBlockedBy : message) ??
        (cancelled
            ? 'Не учитывается в показателях дня и вознаграждениях. Для редактирования восстановите документ.'
            : creating
            ? 'Заполните данные и сохраните документ.'
            : editing
            ? 'Изменения будут записаны после сохранения.'
            : 'Чтобы изменить документ, начните редактирование.');

    return Container(
      height:
          80 *
          (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
            1.0,
            double.infinity,
          ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: warningState
            ? warning.warningContainer
            : viewing
            ? scheme.surfaceContainerLow
            : scheme.primaryContainer,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(
            blocked
                ? Icons.lock_outline
                : cancelled
                ? Icons.archive_outlined
                : creating
                ? Icons.add_circle_outline
                : editing
                ? Icons.edit_outlined
                : Icons.visibility_outlined,
            color: warningState ? warning.warningColor : foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: blocked
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: title,
                    child: Text(
                      title,
                      textAlign: blocked ? TextAlign.center : TextAlign.start,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (blocked
                                  ? Theme.of(context).textTheme.titleMedium
                                  : Theme.of(context).textTheme.titleSmall)
                              ?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Tooltip(
                    message: description,
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Text(
                      description,
                      textAlign: blocked ? TextAlign.center : TextAlign.start,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: message == null || warningState
                            ? foreground
                            : scheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 192,
            child: viewing && active
                ? AppPrimaryButton(
                    text: 'Редактировать',
                    icon: Icons.edit_outlined,
                    maxLines: 1,
                    onPressed: onEdit,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
