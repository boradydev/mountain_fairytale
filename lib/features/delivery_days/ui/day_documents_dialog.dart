import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/day_documents_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/select_delivery_type_dialog.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_screen.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_screen.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

typedef DayDocumentOpener = Future<bool?> Function(
  BuildContext context,
  DeliveryType type,
  DateTime date,
  RouteDocument? document,
  VoidCallback onChanged,
);

Future<bool?> openDayDocument(
  BuildContext context,
  DeliveryType type,
  DateTime date,
  RouteDocument? document,
  VoidCallback onChanged,
) => Navigator.of(context).push<bool>(
  MaterialPageRoute(
    builder: (_) => type == DeliveryType.delivery
        ? RouteConstructorScreen(
            existingRouteId: document?.id,
            initialDate: date,
            onDocumentChanged: onChanged,
          )
        : PickupConstructorScreen(
            existingPickupId: document?.id,
            initialDate: date,
            onDocumentChanged: onChanged,
          ),
  ),
);

class DayDocumentsDialog extends StatefulWidget {
  final DateTime date;
  final DeliveryDaysProvider daysProvider;
  final DayDocumentOpener openDocument;
  const DayDocumentsDialog({
    super.key,
    required this.date,
    required this.daysProvider,
    this.openDocument = openDayDocument,
  });
  @override
  State<DayDocumentsDialog> createState() => _DayDocumentsDialogState();
}

class _DayDocumentsDialogState extends State<DayDocumentsDialog> {
  late final DayDocumentsProvider _provider;
  bool _opening = false;
  int _mutations = 0;
  @override
  void initState() {
    super.initState();
    _provider = DayDocumentsProvider(
      widget.daysProvider.repository,
      widget.date,
    );
    unawaited(_provider.load());
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    _mutations++;
    unawaited(_provider.load());
    unawaited(widget.daysProvider.refreshDeliveryDays());
  }

  Future<void> _open(DeliveryType type, [RouteDocument? document]) async {
    if (_opening) return;
    setState(() => _opening = true);
    final before = _mutations;
    try {
      final updated = await widget.openDocument(
        context,
        type,
        widget.date,
        document,
        _changed,
      );
      if (mounted && updated == true && before == _mutations) _changed();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_provider, widget.daysProvider]),
    builder: (context, _) {
      final locale = Localizations.localeOf(context).toLanguageTag();
      return Dialog(
        child: SizedBox(
          width: 620,
          height: MediaQuery.sizeOf(context).height * .8,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Документы на ${DateFormat.yMd(locale).format(widget.date)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: LabeledCheckboxToggle(
                      label: 'Показывать отменённые',
                      value: _provider.includeCancelled,
                      onChanged: _opening
                          ? null
                          : _provider.setIncludeCancelled,
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth < 500
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: width,
                          child: AppSecondaryButton(
                            text: 'Добавить доставку',
                            icon: Icons.local_shipping_outlined,
                            onPressed: _opening
                                ? null
                                : () => _open(DeliveryType.delivery),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: AppSecondaryButton(
                            text: 'Добавить самовывоз',
                            icon: Icons.store_outlined,
                            onPressed: _opening
                                ? null
                                : () => _open(DeliveryType.pickup),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    children: [
                      if (widget.daysProvider.hasError)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Text(
                                widget.daysProvider.errorMessage,
                                textAlign: TextAlign.center,
                              ),
                              AppSecondaryButton(
                                text: 'Обновить карточки',
                                onPressed: widget.daysProvider.isLoadingMore
                                    ? null
                                    : widget.daysProvider.refreshDeliveryDays,
                              ),
                            ],
                          ),
                        ),
                      if (_provider.loading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_provider.error != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                _provider.error!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              AppSecondaryButton(
                                text: 'Повторить',
                                onPressed: _provider.load,
                              ),
                            ],
                          ),
                        )
                      else if (_provider.documents.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _provider.includeCancelled
                                ? 'На эту дату нет документов'
                                : 'На эту дату нет активных документов',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ..._buildDocumentSections(locale),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppSecondaryButton(
                    text: 'Закрыть',
                    onPressed: _opening
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  List<Widget> _buildDocumentSections(String locale) {
    final deliveries = _provider.documents
        .where((document) => document is DeliveryRouteSheet)
        .toList();
    final pickups = _provider.documents
        .where((document) => document is! DeliveryRouteSheet)
        .toList();
    final sections = <Widget>[];

    if (deliveries.isNotEmpty) {
      sections.addAll(
        _buildDocumentSection(
          title: 'Доставки',
          documents: deliveries,
          type: DeliveryType.delivery,
          locale: locale,
        ),
      );
    }
    if (pickups.isNotEmpty) {
      if (sections.isNotEmpty) sections.add(const Divider(height: 24));
      sections.addAll(
        _buildDocumentSection(
          title: 'Самовывозы',
          documents: pickups,
          type: DeliveryType.pickup,
          locale: locale,
        ),
      );
    }
    return sections;
  }

  List<Widget> _buildDocumentSection({
    required String title,
    required List<RouteDocument> documents,
    required DeliveryType type,
    required String locale,
  }) {
    final activeDocuments = documents
        .where((document) => document.isActive)
        .toList();
    final cancelledDocuments = documents
        .where((document) => !document.isActive)
        .toList();
    final colors = Theme.of(context).colorScheme;

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colors.primary,
          ),
        ),
      ),
      for (final document in activeDocuments)
        _buildDocumentTile(document, type, locale),
      if (cancelledDocuments.isNotEmpty) ...[
        if (activeDocuments.isNotEmpty)
          const Divider(height: 16, indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            'Отменённые',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        for (final document in cancelledDocuments)
          _buildDocumentTile(document, type, locale),
      ],
    ];
  }

  Widget _buildDocumentTile(
    RouteDocument document,
    DeliveryType type,
    String locale,
  ) {
    final colors = Theme.of(context).colorScheme;
    final iconColor = document.isActive
        ? colors.primary
        : colors.onSurfaceVariant;
    final subtitleLines = <Widget>[];

    if (document is DeliveryRouteSheet) {
      subtitleLines.add(Text('Автомобиль: ${document.carModelAndNumber}'));
    }
    if (document.createdAt != null) {
      subtitleLines.add(
        Text(
          'Создан: ${DateFormat.yMd(locale).add_Hm().format(document.createdAt!)}',
        ),
      );
    }

    return ListTile(
      leading: Icon(
        type == DeliveryType.delivery
            ? Icons.local_shipping_outlined
            : Icons.store_outlined,
        color: iconColor,
      ),
      title: Text(
        '${document.title}${document.isActive ? '' : ' — Отменён'}',
      ),
      subtitle: subtitleLines.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: subtitleLines,
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _opening ? null : () => _open(type, document),
    );
  }
}
