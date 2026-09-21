import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/widgets/icon_button_widget.dart';

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
            if (onAdd != null)
              AppIconButton(
                icon: Icons.add,
                tooltip: 'Добавить $label',
                onPressed: onAdd,
              ),
            if (onEdit != null)
              AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Редактировать выбранный элемент',
                onPressed: onEdit,
              ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
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
              child: Text(
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
