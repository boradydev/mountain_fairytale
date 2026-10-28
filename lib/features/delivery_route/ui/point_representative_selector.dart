import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_api_repo.dart';
import 'package:mountain_fairytale/features/sales_representatives/ui/sales_rep_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/dropdown_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';

class PointRepresentativeSelector extends StatefulWidget {
  final OrderPointsProvider provider;
  final RoutePoint point;
  const PointRepresentativeSelector({
    super.key,
    required this.provider,
    required this.point,
  });

  @override
  State<PointRepresentativeSelector> createState() =>
      _PointRepresentativeSelectorState();
}

class _PointRepresentativeSelectorState
    extends State<PointRepresentativeSelector> {
  List<ClientDirectoryEntry> _items = [];
  bool _loading = true;
  bool _busy = false;
  bool _includeInactive = false;
  String? _error;
  int _version = 0;
  int _loadGeneration = 0;
  late bool _wasEditable;

  @override
  void initState() {
    super.initState();
    _wasEditable = widget.provider.canEdit;
    if (_wasEditable || widget.point.salesRepresentativeId != null) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(covariant PointRepresentativeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final editable = widget.provider.canEdit;
    if ((editable && !_wasEditable) ||
        widget.point.salesRepresentativeId !=
            oldWidget.point.salesRepresentativeId) {
      _load();
    }
    _wasEditable = editable;
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context
          .read<ClientsProvider>()
          .getSalesRepresentatives(includeDeactivated: true);
      if (mounted && generation == _loadGeneration) {
        setState(() => _items = items);
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = 'Не удалось загрузить представителей.');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _version++;
        });
      }
    }
  }

  Future<void> _select(ClientDirectoryEntry? entry) async {
    if (entry == null || _busy || !widget.provider.canEdit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var selected = entry;
      if (!entry.isActive) {
        final confirmed = await ConfirmDialog.show(
          context,
          title: 'Активировать и выбрать?',
          content: '«${entry.name}» снова станет доступен.',
          confirmText: 'Активировать и выбрать',
        );
        if (!confirmed || !mounted || !widget.provider.canEdit) return;
        final active = await context
            .read<SalesRepresentativeApiRepository>()
            .update(entry.id, {'isActive': true});
        selected = ClientDirectoryEntry(active.id, active.name);
      }
      if (!mounted || !widget.provider.canEdit) return;
      await widget.provider.selectPointRepresentative(
        widget.point.clientId,
        selected,
        context.read<ClientsProvider>(),
      );
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Не удалось сохранить представителя клиента. Повторите выбор.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _version++;
        });
      }
    }
  }

  Future<void> _edit({String? id}) async {
    if (_busy || !widget.provider.canEdit) return;
    setState(() => _busy = true);
    ApiSalesRepresentative? saved;
    ApiSalesRepresentative? openAfter;
    try {
      final repo = context.read<SalesRepresentativeApiRepository>();
      final current = id == null ? null : await repo.get(id);
      if (!mounted) return;
      saved = await showDialog<ApiSalesRepresentative>(
        context: context,
        builder: (dialogContext) => SalesRepDialog(
          apiRepository: repo,
          apiSalesRep: current,
          onOpenSalesRep: (existing) {
            openAfter = existing;
            Navigator.pop(dialogContext);
          },
        ),
      );
      if (mounted) await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось открыть представителя.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (saved != null && saved.isActive) {
      await _select(ClientDirectoryEntry(saved.id, saved.name));
    }
    if (openAfter != null) await _edit(id: openAfter!.id);
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    final selected = (_loading || _error != null)
        ? null
        : _items
              .where((item) => item.id == point.salesRepresentativeId)
              .firstOrNull;
    final visible = _items
        .where((item) => _includeInactive || item.isActive)
        .toList();
    final selectedVisible =
        selected != null && visible.any((item) => item.id == selected.id);
    final name = point.salesRepresentative.trim().isEmpty
        ? selected?.name ?? 'Не указан'
        : point.salesRepresentative;
    final hint = point.salesRepresentativeId == null
        ? name
        : selected != null
        ? '$name${selected.isActive ? '' : ' — Неактивен'}'
        : '$name — ${_loading ? 'Статус уточняется' : 'Статус неизвестен'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDropdown<ClientDirectoryEntry>(
          isLoading: widget.provider.canEdit && (_loading || _busy),
          key: ValueKey('rep-$_version-${point.salesRepresentativeId}'),
          label: 'Торговый представитель',
          items: visible,
          value: selectedVisible ? selected : null,
          hint: hint,
          enabled:
              !_busy && !_loading && _error == null && widget.provider.canEdit,
          showAdd: true,
          showEdit: true,
          editBeforeAdd: true,
          showInactiveToggle: true,
          includeInactive: _includeInactive,
          onIncludeInactiveChanged: (value) {
            setState(() => _includeInactive = value);
          },
          itemLabelBuilder: (item) =>
              '${item.name}${item.isActive ? '' : ' — Неактивен'}',
          onChanged: _select,
          onAdd: () => _edit(),
          onEdit: point.salesRepresentativeId == null
              ? null
              : () => _edit(id: point.salesRepresentativeId),
        ),
        if (widget.provider.canEdit && _error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          AppSecondaryButton(
            text: 'Повторить загрузку',
            onPressed: _busy ? null : _load,
          ),
        ],
      ],
    );
  }
}
