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
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  String? _quantityError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.quantity.toString());
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _controller.text = widget.item.quantity.toString();
      setState(() => _quantityError = null);
    }
  }

  @override
  void didUpdateWidget(covariant TaskItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus || !widget.enabled) {
      _controller.text = widget.item.quantity.toString();
      _quantityError = null;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final value = widget.item.quantity + delta;
    if (!widget.enabled || value < 1) return;
    _controller.text = value.toString();
    setState(() => _quantityError = null);
    widget.onQuantityChanged(value);
  }

  Widget _quantity() => SizedBox(
    width: 156,
    child: Row(
      children: [
        AppIconButton(
          icon: Icons.remove,
          tooltip: 'Уменьшить количество',
          onPressed: widget.enabled && widget.item.quantity > 1
              ? () => _step(-1)
              : null,
        ),
        Expanded(
          child: TextFormField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            validator: (text) =>
                (int.tryParse(text ?? '') ?? 0) > 0 ? null : 'Больше 0',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (text) {
              final value = int.tryParse(text);
              setState(
                () => _quantityError = value == null || value < 1
                    ? 'Больше 0'
                    : null,
              );
              if (widget.enabled && value != null && value > 0) {
                widget.onQuantityChanged(value);
              }
            },
            onFieldSubmitted: (_) => _focusNode.unfocus(),
            decoration: InputDecoration(
              isDense: true,
              errorText: _quantityError,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 10,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        AppIconButton(
          icon: Icons.add,
          tooltip: 'Увеличить количество',
          onPressed: widget.enabled ? () => _step(1) : null,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final name = Text(
      widget.item.productName,
      style: const TextStyle(fontWeight: FontWeight.w500),
    );
    final price = Text(
      '${widget.item.price.toStringAsFixed(2)} ₽ / шт.',
      textAlign: TextAlign.right,
    );
    final amount = Text(
      '${widget.item.amount.toStringAsFixed(2)} ₽',
      textAlign: TextAlign.right,
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
    final actions = SizedBox(
      width: 48,
      child: PopupMenuButton<String>(
        tooltip: 'Действия с позицией',
        enabled: widget.enabled,
        onSelected: (value) {
          if (value == 'delete') widget.onDelete();
          if (value == 'price') widget.onRefreshPrice?.call();
        },
        itemBuilder: (_) => [
          if (widget.onRefreshPrice != null)
            const PopupMenuItem(
              value: 'price',
              child: Text('Обновить цену из каталога'),
            ),
          const PopupMenuItem(value: 'delete', child: Text('Удалить позицию')),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: name),
                    actions,
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [_quantity(), price, amount],
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: name,
                ),
              ),
              _quantity(),
              SizedBox(width: 112, child: price),
              SizedBox(width: 112, child: amount),
              actions,
            ],
          ),
        );
      },
    );
  }
}
