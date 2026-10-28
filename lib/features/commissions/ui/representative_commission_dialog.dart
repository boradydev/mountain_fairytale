import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_api_repo.dart';
import 'package:mountain_fairytale/features/sales_representatives/ui/sales_rep_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/active_status_label.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/shared/widgets/app_notify.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/dropdown_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

import 'package:mountain_fairytale/features/commissions/data/commission_amount.dart';
import 'package:mountain_fairytale/features/commissions/data/commission_models.dart';
import 'package:mountain_fairytale/features/commissions/data/commissions_repo.dart';
import 'package:mountain_fairytale/features/commissions/ui/commission_widgets.dart';

class RepresentativeCommissionDialog extends StatefulWidget {
  final CommissionsRepository repository;
  final String representativeId;
  final DateTime month;
  final List<RepresentativeCommission> targets;
  const RepresentativeCommissionDialog({
    super.key,
    required this.repository,
    required this.representativeId,
    required this.month,
    required this.targets,
  });
  @override
  State<RepresentativeCommissionDialog> createState() =>
      _RepresentativeCommissionDialogState();
}

class _RepresentativeCommissionDialogState
    extends State<RepresentativeCommissionDialog> {
  RepresentativeCommissionDetails? _details;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  bool? _active;
  String? _error;
  String _search = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await widget.repository.details(
        widget.representativeId,
        widget.month,
      );
      if (!mounted) return;
      setState(() {
        _details = details;
        _active = details.representative.isActive;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось загрузить клиентов и начисления.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assign(String? targetId, String targetName) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: targetId == null ? 'Снять представителя?' : 'Передать клиентов?',
      content: targetId == null
          ? 'Все закреплённые клиенты, включая деактивированных, останутся без представителя. Исторические начисления сохранятся.'
          : 'Передать всех закреплённых клиентов, включая деактивированных, представителю $targetName? Исторические начисления сохранятся.',
      destructive: targetId == null,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final count = await widget.repository.assign(
        widget.representativeId,
        targetId,
      );
      if (!mounted) return;
      _changed = true;
      _details = null;
      AppNotify.show(
        targetId == null
            ? 'Представитель снят у $count клиентов'
            : 'Передано клиентов: $count',
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.statusCode == 409
              ? 'Выбранный представитель деактивирован. Обновите список и выберите другого.'
              : 'Не удалось изменить назначения клиентов. Повторите запрос.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Не удалось изменить назначения клиентов. Повторите запрос.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseTarget() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => _TargetDialog(widget.targets),
    );
    if (selected == null || !mounted) return;
    await _assign(
      selected,
      widget.targets.firstWhere((row) => row.id == selected).name,
    );
  }

  Future<void> _changeActivity() async {
    final representative = _details?.representative;
    if (_busy || _loading || representative == null) return;
    final active = !(_active ?? representative.isActive);
    setState(() => _busy = true);
    try {
      final confirmed = await confirmSalesRepresentativeActivity(
        context,
        name: representative.name,
        active: active,
      );
      if (!mounted || !confirmed) return;
      setState(() => _error = null);
      final saved = await context
          .read<SalesRepresentativeApiRepository>()
          .update(representative.id, {'isActive': active});
      if (!mounted) return;
      setState(() {
        _active = saved.isActive;
        _changed = true;
      });
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Не удалось изменить активность представителя. Повторите запрос.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final representative = details?.representative;
    final query = _search.trim().toLowerCase();
    final clients =
        details?.clients
            .where(
              (row) =>
                  row.name.toLowerCase().contains(query) ||
                  row.phone.contains(query),
            )
            .toList() ??
        const <ClientCommission>[];
    final canAssign =
        !_busy && !_loading && (representative?.assignedClientsCount ?? 0) > 0;
    return PopScope(
      canPop: false,
      child: Dialog(
        child: SizedBox(
          width: 950,
          height: MediaQuery.sizeOf(context).height * .85,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (representative != null)
                  CommissionPersonHeader(
                    name: representative.name,
                    isActive: _active ?? representative.isActive,
                    nameStyle: Theme.of(context).textTheme.titleLarge,
                  )
                else
                  Text(
                    'Торговый представитель',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                const SizedBox(height: 4),
                Text(commissionPeriodLabel(widget.month)),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Wrap(
                      spacing: 16,
                      children: [
                        Text(_error!),
                        AppSecondaryButton(
                          text: 'Повторить',
                          onPressed: _busy ? null : _load,
                        ),
                      ],
                    ),
                  ),
                if (details != null) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 28,
                    runSpacing: 12,
                    children: [
                      CommissionMetric(
                        'Оборотная база',
                        formatCommissionCents(details.turnoverCents),
                      ),
                      CommissionMetric(
                        'К выплате',
                        formatCommissionCents(details.payableCents),
                      ),
                      CommissionMetric(
                        'Сейчас закреплено клиентов',
                        '${representative!.assignedClientsCount}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ExpansionTile(
                    title: const Text('Начисления по фактическим ставкам'),
                    children: [CommissionRates(representative.rates)],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Поиск по имени и телефону',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: clients.isEmpty
                      ? Center(
                          child: Text(_loading ? 'Загрузка…' : 'Клиентов нет'),
                        )
                      : ListView.builder(
                          itemCount: clients.length,
                          itemBuilder: (context, index) {
                            final row = clients[index];
                            return Card(
                              child: ExpansionTile(
                                title: Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    Text(row.name),
                                    if (!row.isActive)
                                      const ActiveStatusLabel(
                                        isActive: false,
                                      ),
                                    if (!row.isCurrentlyAssigned)
                                      const Text(
                                        'Передан / снят',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(row.phone),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 24,
                                        runSpacing: 12,
                                        children: [
                                          CommissionMetric(
                                            'Заказов',
                                            '${row.ordersCount}',
                                          ),
                                          CommissionMetric(
                                            'Оборотная база',
                                            row.turnover.formatted,
                                          ),
                                          CommissionMetric(
                                            'К выплате',
                                            row.payable.formatted,
                                          ),
                                          if (row.lastOrderDate != null)
                                            CommissionMetric(
                                              'Последний заказ',
                                              row.lastOrderDate!,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                children: [CommissionRates(row.rates)],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  overflowAlignment: OverflowBarAlignment.start,
                  spacing: 24,
                  overflowSpacing: 12,
                  children: [
                    if (representative != null)
                      AppSecondaryButton(
                        text: (_active ?? representative.isActive)
                            ? 'Деактивировать'
                            : 'Активировать',
                        destructive: _active ?? representative.isActive,
                        onPressed: _busy || _loading ? null : _changeActivity,
                      ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        AppSecondaryButton(
                          text: 'Закрыть',
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context, _changed),
                        ),
                        AppSecondaryButton(
                          text: 'Снять представителя',
                          onPressed: canAssign ? () => _assign(null, '') : null,
                        ),
                        AppPrimaryButton(
                          text: 'Передать клиентов',
                          onPressed: canAssign && widget.targets.isNotEmpty
                              ? _chooseTarget
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetDialog extends StatefulWidget {
  final List<RepresentativeCommission> targets;
  const _TargetDialog(this.targets);
  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  String? _selected;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Передать клиентов'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 440,
        child: AppDropdown<String>(
          label: 'Торговый представитель',
          items: widget.targets.map((row) => row.id).toList(),
          value: _selected,
          itemLabelBuilder: (id) =>
              widget.targets.firstWhere((row) => row.id == id).name,
          onChanged: (value) => setState(() => _selected = value),
        ),
      ),
    ),
    actions: [
      AppSecondaryButton(
        text: 'Отмена',
        onPressed: () => Navigator.pop(context),
      ),
      AppPrimaryButton(
        text: 'Выбрать',
        onPressed: _selected == null
            ? null
            : () => Navigator.pop(context, _selected),
      ),
    ],
  );
}
