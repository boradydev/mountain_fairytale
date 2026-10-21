import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/payment_methods/ui/payment_method_activation_dialog.dart';
import 'package:mountain_fairytale/features/payment_methods/ui/payment_method_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/dropdown_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

class PaymentMethodSelector extends StatefulWidget {
  final OrderPointsProvider provider;
  final ClientsProvider clientsProvider;
  final String clientId;
  final String? selectedId;
  final String? selectedName;

  const PaymentMethodSelector({
    super.key,
    required this.provider,
    required this.clientsProvider,
    required this.clientId,
    this.selectedId,
    this.selectedName,
  });

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  final _focusNode = FocusNode();
  bool _busy = false;
  bool _saving = false;
  int _selectionVersion = 0;
  String? _error;
  late bool _wasEditable;

  @override
  void initState() {
    super.initState();
    _wasEditable = widget.provider.canEdit;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSelected());
  }

  @override
  void didUpdateWidget(covariant PaymentMethodSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final editable = widget.provider.canEdit;
    if (oldWidget.selectedId != widget.selectedId ||
        (editable && !_wasEditable)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSelected());
    }
    _wasEditable = editable;
  }

  Future<void> _loadSelected() async {
    if (!mounted || !widget.provider.canEdit) return;
    final id = widget.selectedId;
    if (id == null || widget.provider.paymentMethodsById.containsKey(id)) {
      return;
    }
    try {
      await widget.provider.loadSelectedPaymentMethod(id);
    } catch (_) {
      if (mounted && widget.selectedId == id) {
        setState(() => _error = 'Не удалось загрузить текущий способ оплаты.');
      }
    }
  }

  Future<void> _select(PaymentMethod? method) async {
    if (_busy || method == null || !widget.provider.canEdit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var selected = method;
      if (!selected.isActive) {
        final confirmed = await showPaymentMethodActivationDialog(
          context,
          selected,
        );
        if (!mounted || !confirmed) return;
        setState(() => _saving = true);
        final activated = await widget.provider.activatePaymentMethod(selected);
        if (!mounted) return;
        if (activated == null) {
          setState(() => _error = widget.provider.paymentMethodErrorMessage);
          return;
        }
        selected = activated;
      }
      setState(() => _saving = true);
      final success = await widget.provider.selectPointPaymentMethod(
        widget.clientId,
        selected,
        widget.clientsProvider,
      );
      if (mounted && !success) {
        setState(() => _error = widget.provider.paymentMethodErrorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
          _selectionVersion++;
        });
      }
    }
  }

  Future<void> _showEditor({PaymentMethod? method}) async {
    if (!widget.provider.canEdit) return;
    PaymentMethod? openAfter;
    final result = await showDialog<PaymentMethod>(
      context: context,
      builder: (dialogContext) => PaymentMethodDialog(
        provider: widget.provider,
        paymentMethod: method,
        onOpenPaymentMethod: (existing) {
          openAfter = existing;
          Navigator.of(dialogContext).pop();
        },
      ),
    );
    if (!mounted) return;
    if (result != null) await _select(result);
    if (!mounted) return;
    if (openAfter != null) {
      await _showEditor(method: openAfter);
    } else {
      setState(() => _selectionVersion++);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.provider,
    builder: (context, _) {
      final provider = widget.provider;
      final items = List<PaymentMethod>.of(provider.paymentMethods);
      PaymentMethod? selectable;
      for (final method in items) {
        if (method.id == widget.selectedId) selectable = method;
      }
      // Preserve the client's current value without adding filtered records
      // back to the menu. Hidden records remain available in the editor.
      final selected =
          selectable ?? provider.paymentMethodsById[widget.selectedId];
      final currentLabel = selected == null
          ? widget.selectedName
          : '${selected.name}${selected.isActive ? '' : ' — Неактивен'}';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDropdown<PaymentMethod>(
            isLoading:
                provider.canEdit &&
                (_saving || provider.isLoadingPaymentMethods),
            key: ValueKey(
              'payment-$_selectionVersion-${provider.showInactivePaymentMethods}-${selectable?.id}-${selected?.name}-${selected?.isActive}',
            ),
            label: 'Форма оплаты *',
            focusNode: _focusNode,
            enabled: !_busy && provider.canEdit,
            items: items,
            value: selectable,
            hint: currentLabel ?? 'Выберите форму оплаты',
            showEdit: true,
            showAdd: true,
            editBeforeAdd: true,
            showInactiveToggle: true,
            includeInactive: provider.showInactivePaymentMethods,
            onIncludeInactiveChanged: provider.isLoadingPaymentMethods
                ? null
                : (value) {
                    _focusNode.requestFocus();
                    provider.toggleInactivePaymentMethods(value);
                  },
            itemLabelBuilder: (method) => method.name,
            itemBuilder: (method) => Text(
              '${method.name}${method.isActive ? '' : ' — Неактивен'}',
              overflow: TextOverflow.ellipsis,
              style: method.isActive
                  ? null
                  : TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
            ),
            onChanged: _select,
            onAdd: _busy ? null : () => _showEditor(),
            onEdit: _busy || selected == null
                ? null
                : () => _showEditor(method: selected),
          ),
          if (provider.canEdit &&
              (provider.paymentMethodLoadError != null || _error != null))
            Row(
              children: [
                Expanded(
                  child: Text(
                    _error ?? provider.paymentMethodLoadError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                AppSecondaryButton(
                  text: 'Повторить',
                  onPressed: _busy || provider.isLoadingPaymentMethods
                      ? null
                      : () async {
                          setState(() => _error = null);
                          await provider.loadPaymentMethods();
                          await _loadSelected();
                        },
                ),
              ],
            ),
        ],
      );
    },
  );
}
