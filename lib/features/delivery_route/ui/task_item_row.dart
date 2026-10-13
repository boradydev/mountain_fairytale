import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';

class TaskItemRow extends StatefulWidget {
  final int index;
  final bool enabled;
  final VoidCallback? onRefreshPrice;
  final DeliveryTaskItem item;
  final VoidCallback onDelete;
  final ValueChanged<int> onQuantityChanged;

  const TaskItemRow({
    super.key,
    required this.index,
    this.enabled = true,
    this.onRefreshPrice,
    required this.item,
    required this.onDelete,
    required this.onQuantityChanged,
  });

  @override
  State<TaskItemRow> createState() => _TaskItemRowState();
}

class _TaskItemRowState extends State<TaskItemRow> {
  bool _isEditing = false;
  String? _quantityError;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.quantity.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    _controller.text = widget.item.quantity.toString();
    setState(() => _isEditing = true);
  }

  void _saveEditing() {
    final value = int.tryParse(_controller.text);
    if (value == null || value <= 0) {
      setState(() => _quantityError = 'Введите количество больше нуля');
      return;
    }
    if (value > 0) {
      widget.onQuantityChanged(value);
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${widget.index + 1}. ',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(
                widget.item.productName,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: 125,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (!_isEditing) ...[
                  Text(
                    '${widget.item.quantity} шт.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 4),
                  AppIconButton(
                    icon: Icons.edit,
                    tooltip: 'Изменить количество',
                    color: colorScheme.primary,
                    onPressed: widget.enabled ? _startEditing : null,
                  ),
                ] else ...[
                  Expanded(
                    child: TextFormField(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      controller: _controller,
                      validator: (value) =>
                          !_isEditing || (int.tryParse(value ?? '') ?? 0) > 0
                          ? null
                          : 'Введите количество больше нуля',
                      onChanged: (text) {
                        setState(() => _quantityError = null);
                        final quantity = int.tryParse(text);
                        if (widget.enabled &&
                            quantity != null &&
                            quantity > 0) {
                          widget.onQuantityChanged(quantity);
                        }
                      },
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        errorText: _quantityError,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AppIconButton(
                    icon: Icons.check,
                    tooltip: 'Подтвердить',
                    color: colorScheme.primary,
                    onPressed: widget.enabled ? _saveEditing : null,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 16),
          Text('${widget.item.price.toStringAsFixed(2)} ₽ / шт.'),
          AppIconButton(
            icon: Icons.price_change_outlined,
            tooltip: 'Обновить цену из каталога',
            onPressed: widget.enabled ? widget.onRefreshPrice : null,
          ),
          SizedBox(
            width: 105,
            child: Text(
              '${widget.item.amount.toStringAsFixed(2)} ₽',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          AppIconButton(
            icon: Icons.delete_outline,
            destructive: true,
            tooltip: 'Удалить позицию',
            onPressed: widget.enabled ? widget.onDelete : null,
          ),
        ],
      ),
    );
  }
}
