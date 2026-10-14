part of 'audit_event_row.dart';

Map<String, Object?> _auditMap(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : const {};

String _auditReferenceId(Object? value) =>
    value is Map ? '${value['id']}' : '$value';

bool _auditEqual(Object? before, Object? after) {
  if (before is Map && after is Map) {
    return before.length == after.length &&
        before.keys.every(
          (key) =>
              after.containsKey(key) && _auditEqual(before[key], after[key]),
        );
  }
  if (before is List && after is List) {
    return before.length == after.length &&
        List.generate(
          before.length,
          (index) => _auditEqual(before[index], after[index]),
        ).every((same) => same);
  }
  return before == after;
}

class _AuditSnapshotPair {
  final String id;
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;
  const _AuditSnapshotPair(this.id, this.before, this.after);

  Map<String, Object?> get value => after ?? before ?? const {};
  AuditAction? get action => before == null
      ? AuditAction.created
      : after == null
      ? AuditAction.deleted
      : _auditEqual(before, after)
      ? null
      : AuditAction.updated;
}

List<_AuditSnapshotPair> _auditPairs(
  Object? before,
  Object? after,
  String idKey,
) {
  Map<String, Map<String, Object?>> index(Object? value) => {
    if (value is List)
      for (final item in value)
        if (item is Map) _auditReferenceId(item[idKey]): _auditMap(item),
  };
  final oldValues = index(before);
  final newValues = index(after);
  return [
    for (final id in {...newValues.keys, ...oldValues.keys})
      _AuditSnapshotPair(id, oldValues[id], newValues[id]),
  ];
}

class _AuditDocumentPoints extends StatelessWidget {
  final AuditEvent event;
  const _AuditDocumentPoints({required this.event});

  @override
  Widget build(BuildContext context) {
    final change = event.changes['points'];
    final data = event.data['points'];
    if (change == null && data is! List) return const SizedBox.shrink();
    final points = _auditPairs(
      change?.oldValue ?? (event.action == AuditAction.deleted ? data : null),
      change?.newValue ?? (event.action == AuditAction.deleted ? null : data),
      'pointId',
    );
    int position(_AuditSnapshotPair point) =>
        (point.value['position'] as num?)?.toInt() ?? 0;
    points.sort((a, b) {
      if ((a.after == null) != (b.after == null)) {
        return a.after == null ? 1 : -1;
      }
      return position(a).compareTo(position(b));
    });
    return _AuditDisclosure(
      key: ValueKey('audit-points-${event.eventId}'),
      label: 'Точки · ${points.length}',
      child: points.isEmpty
          ? const _AuditFieldRow(label: 'Точки', value: 'Нет точек')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final point in points)
                  _AuditPointDetails(
                    key: ValueKey('audit-point-${point.id}'),
                    point: point,
                  ),
              ],
            ),
    );
  }
}

class _AuditPointDetails extends StatelessWidget {
  final _AuditSnapshotPair point;
  const _AuditPointDetails({super.key, required this.point});

  @override
  Widget build(BuildContext context) {
    final name = formatAuditValue(
      point.value['clientId'] ?? point.value['displayName'] ?? point.id,
    );
    final items = _auditPairs(
      point.before?['items'],
      point.after?['items'],
      'productId',
    );
    final positionBefore = point.before?['position'];
    final positionAfter = point.after?['position'];
    return _AuditDisclosure(
      label: '$name · товаров: ${items.length}',
      action: point.action,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (point.before != null &&
              point.after != null &&
              positionBefore != positionAfter)
            _AuditFieldRow(
              label: 'Порядок',
              change: AuditChange(
                oldValue: positionBefore is num
                    ? positionBefore + 1
                    : positionBefore,
                newValue: positionAfter is num
                    ? positionAfter + 1
                    : positionAfter,
              ),
            ),
          if (items.isEmpty)
            const _AuditFieldRow(label: 'Товары', value: 'Нет товаров'),
          for (final item in items) _AuditItemDetails(item: item),
        ],
      ),
    );
  }
}

class _AuditItemDetails extends StatelessWidget {
  final _AuditSnapshotPair item;
  const _AuditItemDetails({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = formatAuditValue(
      item.value['productId'] is Map
          ? item.value['productId']
          : item.value['productName'] ?? item.value['productId'],
    );
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(
            item.action == null
                ? name
                : '$name · ${auditActionLabel(item.action!)}',
            style: theme.textTheme.bodySmall,
          ),
          if (item.before != null && item.after != null) ...[
            for (final key in ['quantity', 'price'])
              if (!_auditEqual(item.before?[key], item.after?[key]))
                _AuditFieldRow(
                  label: auditFieldLabels[key]!,
                  change: AuditChange(
                    oldValue: item.before?[key],
                    newValue: item.after?[key],
                  ),
                ),
            if (_auditEqual(item.before, item.after))
              _AuditFieldRow(
                label: 'Количество × цена',
                value:
                    '${formatAuditValue(item.value['quantity'])} × ${formatAuditValue(item.value['price'])} ₽',
              ),
          ] else
            _AuditFieldRow(
              label: 'Количество × цена',
              value:
                  '${formatAuditValue(item.value['quantity'])} × ${formatAuditValue(item.value['price'])} ₽',
            ),
        ],
      ),
    );
  }
}

// Разделы журнала имеют собственное состояние раскрытия и стабильные ключи.
class _AuditDisclosure extends StatefulWidget {
  final String label;
  final AuditAction? action;
  final Widget child;
  const _AuditDisclosure({
    super.key,
    required this.label,
    this.action,
    required this.child,
  });

  @override
  State<_AuditDisclosure> createState() => _AuditDisclosureState();
}

class _AuditDisclosureState extends State<_AuditDisclosure> {
  bool _expanded = false;
  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.action == null
        ? widget.label
        : '${widget.label} · ${auditActionLabel(widget.action!)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label:
              '${widget.action == null ? '' : '${auditActionLabel(widget.action!)}. '}${widget.label}',
          onTap: _toggle,
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              mouseCursor: SystemMouseCursors.click,
              hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
              focusColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: label,
                        child: Text(
                          label,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: const Icon(Icons.expand_more, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText(
                        label,
                        style: theme.textTheme.bodySmall,
                      ),
                      widget.child,
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
