import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_task_item_model.dart';
import 'package:mountain_fairytale/presentation/widgets/icon_button_widget.dart';

class TaskItemRow extends StatefulWidget {
  final DeliveryTaskItem item;
  final VoidCallback onDelete;
  final ValueChanged<int> onQuantityChanged;

  const TaskItemRow({
    super.key,
    required this.item,
    required this.onDelete,
    required this.onQuantityChanged,
  });

  @override
  State<TaskItemRow> createState() => _TaskItemRowState();
}

class _TaskItemRowState extends State<TaskItemRow> {
  bool _isEditing = false;
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
    if (value != null && value > 0) {
      widget.onQuantityChanged(value);
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.item.productName,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Блок количества
          SizedBox(
            width: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (!_isEditing) ...[
                  Text(
                    '${widget.item.quantity} шт.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  AppIconButton(
                    icon: Icons.edit,
                    tooltip: 'Изменить количество',
                    onPressed: _startEditing,
                  ),
                ] else ...[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.check,
                    tooltip: 'Подтвердить',
                    onPressed: _saveEditing,
                  ),
                ],
              ],
            ),
          ),

          // Сумма
          SizedBox(
            width: 100,
            child: Text(
              '${widget.item.amount.toStringAsFixed(2)} ₽',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          // Удаление
          AppIconButton(
            icon: Icons.delete_outline,
            destructive: true,
            tooltip: 'Удалить позицию',
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}
