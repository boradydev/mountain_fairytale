import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_item_note_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';

class TaskItemRow extends StatefulWidget {
  final int index;
  final bool enabled;
  final bool allowFreePrice;
  final VoidCallback? onRefreshPrice;
  final DeliveryTaskItem item;
  final VoidCallback onDelete;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<double>? onPriceChanged;
  final ValueChanged<String>? onDriverNoteChanged;

  const TaskItemRow({
    super.key,
    required this.index,
    this.enabled = true,
    this.allowFreePrice = false,
    this.onRefreshPrice,
    required this.item,
    required this.onDelete,
    required this.onQuantityChanged,
    this.onPriceChanged,
    this.onDriverNoteChanged,
  });

  @override
  State<TaskItemRow> createState() => _TaskItemRowState();
}

class _TaskItemRowState extends State<TaskItemRow> {
  late final TextEditingController _controller;
  late final TextEditingController _priceController;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.quantity.toString());
    _priceController = TextEditingController(
      text: widget.item.price.toStringAsFixed(2),
    );
    _focusNode.addListener(_onFocusChanged);
    _priceFocusNode.addListener(_onPriceFocusChanged);
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) _restoreQuantity();
  }

  void _onPriceFocusChanged() {
    if (!_priceFocusNode.hasFocus) _restorePrice();
  }

  bool get _showFreePrice => widget.allowFreePrice && widget.item.isFreePrice;

  void _restoreQuantity() {
    final text = widget.item.quantity.toString();
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _restorePrice() {
    final text = widget.item.price.toStringAsFixed(2);
    if (_priceController.text != text) {
      _priceController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void didUpdateWidget(covariant TaskItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus || !widget.enabled) {
      // Updating a controller here can notify the ancestor Form during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (!_focusNode.hasFocus || !widget.enabled)) {
          _restoreQuantity();
        }
      });
    }
    if (!_priceFocusNode.hasFocus || !widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (!_priceFocusNode.hasFocus || !widget.enabled)) {
          _restorePrice();
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _priceFocusNode.removeListener(_onPriceFocusChanged);
    _focusNode.dispose();
    _priceFocusNode.dispose();
    _controller.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final value = widget.item.quantity + delta;
    if (!widget.enabled || value < 1) return;
    _controller.text = value.toString();
    widget.onQuantityChanged(value);
  }

  Widget _quantity() => SizedBox(
    width: 156,
    height: 48,
    child: !widget.enabled
        ? Center(
            child: Text('${widget.item.quantity}', textAlign: TextAlign.center),
          )
        : Row(
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
                      (int.tryParse(text ?? '') ?? 0) > 0 ? null : '',
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  errorBuilder: (_, _) => const SizedBox.shrink(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (text) {
                    final value = int.tryParse(text);
                    if (widget.enabled && value != null && value > 0) {
                      widget.onQuantityChanged(value);
                    }
                  },
                  onFieldSubmitted: (_) => _focusNode.unfocus(),
                  decoration: InputDecoration(
                    isDense: true,
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

  Future<void> _editNote() async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => RouteItemNoteDialog(initialNote: widget.item.driverNote),
    );
    if (note != null && mounted) widget.onDriverNoteChanged?.call(note);
  }

  Widget _price(BuildContext context) {
    if (!_showFreePrice || !widget.enabled) {
      return SizedBox(
        width: 112,
        child: Text(
          '${widget.item.price.toStringAsFixed(2)} ₽ / шт.',
          textAlign: TextAlign.right,
        ),
      );
    }
    return SizedBox(
      width: 112,
      child: TextFormField(
        controller: _priceController,
        focusNode: _priceFocusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          suffixText: '₽',
          labelText: 'Цена / шт.',
        ),
        validator: (value) {
          final price = double.tryParse(
            (value ?? '').trim().replaceAll(',', '.'),
          );
          return price != null && price.isFinite && price >= 0
              ? null
              : 'Введите цену';
        },
        onChanged: (value) {
          final price = double.tryParse(value.trim().replaceAll(',', '.'));
          if (price != null && price.isFinite && price >= 0) {
            widget.onPriceChanged?.call(price);
          }
        },
      ),
    );
  }

  Widget _noteSummary() => Tooltip(
    message: widget.item.driverNote,
    child: Text(
      'Уточнение: ${widget.item.driverNote}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final name = Text(
      widget.item.productName,
      style: const TextStyle(fontWeight: FontWeight.w500),
    );
    final price = _price(context);
    final amount = Text(
      '${widget.item.amount.toStringAsFixed(2)} ₽',
      textAlign: TextAlign.right,
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
    final actions = SizedBox(
      width: 48,
      height: 48,
      child: !widget.enabled
          ? null
          : PopupMenuButton<String>(
              tooltip: 'Действия с позицией',
              enabled: widget.enabled,
              onSelected: (value) {
                if (value == 'delete') widget.onDelete();
                if (value == 'price') widget.onRefreshPrice?.call();
                if (value == 'note') _editNote();
              },
              itemBuilder: (_) => [
                if (widget.onRefreshPrice != null && !_showFreePrice)
                  const PopupMenuItem(
                    value: 'price',
                    child: Text('Обновить цену из каталога'),
                  ),
                if (_showFreePrice)
                  PopupMenuItem(
                    value: 'note',
                    child: SizedBox(
                      width: 220,
                      child: Row(
                        children: [
                          const Icon(Icons.sticky_note_2_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.item.driverNote.isEmpty
                                  ? 'Добавить уточнение'
                                  : 'Изменить уточнение',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Удалить позицию'),
                ),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          name,
                          if (_showFreePrice) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Свободная цена',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.item.driverNote.isNotEmpty)
                              _noteSummary(),
                          ],
                        ],
                      ),
                    ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      if (_showFreePrice) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Свободная цена',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.item.driverNote.isNotEmpty) _noteSummary(),
                      ],
                    ],
                  ),
                ),
              ),
              _quantity(),
              price,
              SizedBox(width: 112, child: amount),
              actions,
            ],
          ),
        );
      },
    );
  }
}
