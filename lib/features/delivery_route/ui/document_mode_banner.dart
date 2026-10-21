import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

/// A stable mode indicator shared by delivery and pickup documents.
class DocumentModeBanner extends StatelessWidget {
  final bool creating;
  final bool editing;
  final bool active;
  final String creationTitle;
  final VoidCallback? onEdit;

  const DocumentModeBanner({
    super.key,
    required this.creating,
    required this.editing,
    required this.active,
    required this.creationTitle,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewing = !creating && !editing;
    final foreground = viewing ? scheme.onSurface : scheme.onPrimaryContainer;
    final title = creating
        ? creationTitle
        : editing
        ? 'Редактирование'
        : 'Только просмотр';
    final description = creating
        ? 'Заполните данные и сохраните документ.'
        : editing
        ? 'Изменения будут записаны после сохранения.'
        : active
        ? 'Чтобы изменить документ, начните редактирование.'
        : 'Документ отменён. Для редактирования восстановите его.';

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: viewing ? scheme.surfaceContainerLow : scheme.primaryContainer,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(
            creating
                ? Icons.add_circle_outline
                : editing
                ? Icons.edit_outlined
                : Icons.visibility_outlined,
            color: foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: foreground),
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
