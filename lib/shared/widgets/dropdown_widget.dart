import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';

class AppDropdown<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final T? value;
  final String? hint;
  final String Function(T)? itemLabelBuilder;
  final ValueChanged<T?> onChanged;
  final VoidCallback? onAdd;
  final VoidCallback? onEdit;
  final String? Function(T?)? validator;
  final IconData? prefixIcon;
  final bool showEdit;

  /// Показывает кнопку фильтра; по умолчанию она скрыта.
  final bool showInactiveToggle;

  /// Текущее состояние фильтра, которым управляет вызывающий экран.
  final bool includeInactive;

  /// null оставляет кнопку видимой, но недоступной (например, при загрузке).
  final ValueChanged<bool>? onIncludeInactiveChanged;
  final bool editBeforeAdd;
  final Widget Function(T)? itemBuilder;

  const AppDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.hint,
    this.itemLabelBuilder,
    this.onAdd,
    this.onEdit,
    this.validator,
    this.prefixIcon,
    this.showEdit = false,
    this.showInactiveToggle = false,
    this.includeInactive = false,
    this.onIncludeInactiveChanged,
    this.editBeforeAdd = false,
    this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (showInactiveToggle) ...[
              AppIconButton(
                icon: includeInactive
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                tooltip: includeInactive
                    ? 'Скрыть неактивные записи'
                    : 'Показать неактивные записи',
                color: includeInactive
                    ? Theme.of(context).colorScheme.primary
                    : null,
                onPressed: onIncludeInactiveChanged == null
                    ? null
                    : () => onIncludeInactiveChanged!(!includeInactive),
              ),
              const SizedBox(width: 12),
            ],
            if (editBeforeAdd && (showEdit || onEdit != null))
              AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Редактировать выбранный элемент',
                onPressed: onEdit,
              ),
            if (onAdd != null)
              AppIconButton(
                icon: Icons.add,
                tooltip: 'Добавить $label',
                onPressed: onAdd,
              ),
            if (!editBeforeAdd && (showEdit || onEdit != null))
              AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Редактировать выбранный элемент',
                onPressed: onEdit,
              ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          isExpanded: true,
          key: ValueKey(value),
          initialValue: value,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            isDense: true,
          ),
          hint: hint != null ? Text(hint!) : null,
          validator: validator,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child:
                  itemBuilder?.call(item) ??
                  Text(
                    itemLabelBuilder != null
                        ? itemLabelBuilder!(item)
                        : item.toString(),
                  ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
