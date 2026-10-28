import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';

class AppDropdown<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final T? value;
  final String? hint;
  final String Function(T)? itemLabelBuilder;
  final ValueChanged<T?> onChanged;

  /// Отключает поле и кнопки, сохраняя их расположение.
  final bool enabled;

  /// Показывает загрузку под полем; место под индикатор зарезервировано всегда.
  final bool isLoading;
  final VoidCallback? onAdd;
  final VoidCallback? onEdit;
  final String? Function(T?)? validator;
  final IconData? prefixIcon;
  final FocusNode? focusNode;
  final bool showEdit;

  /// Оставляет кнопку создания видимой, когда её обработчик недоступен.
  final bool showAdd;

  /// Показывает кнопку фильтра; по умолчанию она скрыта.
  final bool showInactiveToggle;

  /// Текущее состояние фильтра, которым управляет вызывающий экран.
  final bool includeInactive;

  /// null оставляет кнопку видимой, но недоступной (например, при загрузке).
  final ValueChanged<bool>? onIncludeInactiveChanged;
  final bool editBeforeAdd;
  final Widget Function(T)? itemBuilder;

  /// Use the same label and actions with a server-backed search field.
  final Widget? field;

  const AppDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.isLoading = false,
    this.hint,
    this.itemLabelBuilder,
    this.onAdd,
    this.onEdit,
    this.validator,
    this.prefixIcon,
    this.focusNode,
    this.showEdit = false,
    this.showAdd = false,
    this.showInactiveToggle = false,
    this.includeInactive = false,
    this.onIncludeInactiveChanged,
    this.editBeforeAdd = false,
    this.itemBuilder,
    this.field,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (showAdd || onAdd != null)
        AppIconButton(
          icon: Icons.add,
          tooltip: 'Добавить $label',
          onPressed: enabled ? onAdd : null,
        ),
      if (showEdit || onEdit != null)
        AppIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Редактировать выбранный элемент',
          onPressed: enabled ? onEdit : null,
        ),
    ];
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
                onPressed: !enabled || onIncludeInactiveChanged == null
                    ? null
                    : () => onIncludeInactiveChanged!(!includeInactive),
              ),
              const SizedBox(width: 12),
            ],
            ...(editBeforeAdd ? actions.reversed : actions),
          ],
        ),
        const SizedBox(height: 8),
        field ??
            DropdownButtonFormField<T>(
              focusNode: focusNode,
              isExpanded: true,
              initialValue: value,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
                isDense: true,
                enabled: enabled,
              ),
              hint: hint != null
                  ? Text(hint!, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              validator: validator,
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child:
                      itemBuilder?.call(item) ??
                      Text(itemLabelBuilder?.call(item) ?? item.toString()),
                );
              }).toList(),
              onChanged: enabled ? onChanged : null,
            ),
        const SizedBox(height: 4),
        SizedBox(
          height: 4,
          child: isLoading ? const LinearProgressIndicator(minHeight: 4) : null,
        ),
      ],
    );
  }
}
