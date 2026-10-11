import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/theme_extensions.dart';

class DuplicateCheckStatusWidget extends StatefulWidget {
  final bool isChecking;
  final bool isChecked;
  final bool hasDuplicate;
  final String warningText;

  const DuplicateCheckStatusWidget({
    super.key,
    required this.isChecking,
    required this.isChecked,
    required this.hasDuplicate,
    this.warningText = 'Найдены возможные дубликаты',
  });

  @override
  State<DuplicateCheckStatusWidget> createState() =>
      _DuplicateCheckStatusWidgetState();
}

class _DuplicateCheckStatusWidgetState
    extends State<DuplicateCheckStatusWidget> {
  // Флаг: раскрыт ли текст полностью
  bool _isExpanded = false;

  @override
  void didUpdateWidget(covariant DuplicateCheckStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если статус дубликатов изменился или пришел новый запрос,
    // сбрасываем состояние раскрытия в начальное (свернуто)
    if (oldWidget.hasDuplicate != widget.hasDuplicate ||
        oldWidget.isChecking != widget.isChecking) {
      _isExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final customColors = Theme.of(context).extension<AppColorsExtension>()!;

    final Color contentColor;
    final IconData icon;
    final String text;

    if (widget.isChecking) {
      contentColor = colorScheme.onSurfaceVariant;
      icon = Icons.hourglass_empty_rounded;
      text = 'Проверка на дубликаты...';
    } else if (!widget.isChecked) {
      contentColor = colorScheme.onSurfaceVariant;
      icon = Icons.help_outline_rounded;
      text = 'Введите данные для проверки...';
    } else if (widget.hasDuplicate) {
      contentColor = customColors.warningColor;
      icon = Icons.info_outline;
      text = widget.warningText;
    } else {
      contentColor = customColors.successColor;
      icon = Icons.check_circle_outline_rounded;
      text = 'Дубликатов не обнаружено';
    }

    // Делаем область кликабельной только в том случае, если найден дубликат
    final isClickable = widget.hasDuplicate;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: isClickable
            ? () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        // Легкое скругление для эффекта нажатия
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: contentColor),
              const SizedBox(width: 8),
              Expanded(
                // AnimatedSize сделает раскрытие текста плавным 🪄
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: Text(
                    text,
                    style: TextStyle(color: contentColor, height: 1.3),
                    // Если раскрыто — лимита на строки нет, если свернуто — показываем в 1 строку с троеточием
                    maxLines: _isExpanded ? null : 1,
                    overflow: _isExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Маленькая стрелочка-индикатор (показываем только если найден дубликат)
              if (isClickable)
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: contentColor,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
