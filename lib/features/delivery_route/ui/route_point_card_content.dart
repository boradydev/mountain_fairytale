import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:mountain_fairytale/core/theme_extensions.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';

import 'package:mountain_fairytale/features/delivery_route/ui/route_point_labels.dart';

/// Pure presentation shared by route documents and historical snapshots.
class RoutePointCardSurface extends StatelessWidget {
  final bool isDelivered;
  final Widget child;
  const RoutePointCardSurface({
    super.key,
    required this.isDelivered,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Keep each card's semantics together when reorderable items move.
    return Semantics(
      container: true,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDelivered
              ? colorScheme.surfaceContainerLow
              : (Theme.of(context)
                        .extension<AppColorsExtension>()
                        ?.warningContainer ??
                    Color.alphaBlend(
                      colorScheme.error.withValues(alpha: 0.08),
                      colorScheme.surfaceContainerLow,
                    )),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant,
          ),
        ),
        child: child,
      ),
    );
  }
}

class RoutePointHeader extends StatelessWidget {
  final RoutePoint point;
  final bool isPickup;
  final String pickupTitle;
  const RoutePointHeader({
    super.key,
    required this.point,
    this.isPickup = false,
    this.pickupTitle = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final warning =
        theme.extension<AppColorsExtension>()?.warningColor ?? colors.error;
    Widget line(String value, TextStyle? style) => Text(
      value,
      style: style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
    Widget note(String label, String value, TextStyle? style, {Color? color}) =>
        Text.rich(
          TextSpan(
            style: style,
            children: [
              TextSpan(
                text: '$label: ',
                style: style?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              TextSpan(text: value),
            ],
          ),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 440;
        final name = line(
          isPickup ? pickupTitle : point.clientName,
          theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        );
        final address = line(point.address, theme.textTheme.bodyMedium);
        final memo = !isPickup && point.memo.trim().isNotEmpty
            ? note('Памятка', point.memo, theme.textTheme.bodyLarge)
            : null;
        final reason =
            !isPickup &&
                !point.isDelivered &&
                point.nonDeliveryReason.trim().isNotEmpty
            ? note(
                'Не доставлено',
                point.nonDeliveryReason,
                theme.textTheme.bodyMedium,
                color: warning,
              )
            : null;
        Widget detailRow(Widget left, Widget? center) => Row(
          children: [
            Expanded(child: left),
            if (center != null) ...[
              const SizedBox(width: 16),
              Expanded(child: center),
            ],
          ],
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: narrow
              ? [
                  name,
                  ?memo,
                  if (!isPickup) address,
                  ?reason,
                ]
              : [
                  detailRow(name, memo),
                  if (!isPickup) detailRow(address, reason),
                ],
        );
        final summary = Column(
          crossAxisAlignment: narrow
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            line(
              point.items.isEmpty
                  ? 'Задание не заполнено'
                  : '${point.totalAmount.toStringAsFixed(2)} ₽',
              theme.textTheme.bodyLarge?.copyWith(
                decoration: point.isDelivered
                    ? null
                    : TextDecoration.lineThrough,
                fontWeight: FontWeight.w700,
                color: point.items.isEmpty
                    ? colors.onSurfaceVariant
                    : colors.onSurface,
              ),
            ),
            line(
              '${point.items.length} ${routePointPositionsLabel(point.items.length)} · ${point.documentPaymentMethodName ?? 'Оплата не указана'}',
              theme.textTheme.bodySmall,
            ),
          ],
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [details, const SizedBox(height: 4), summary],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 3, child: details),
            const SizedBox(width: 20),
            Expanded(child: summary),
          ],
        );
      },
    );
  }
}

/// Full point notes, shared by the editor and historical snapshots.
class RoutePointNotes extends StatelessWidget {
  final RoutePoint point;
  final VoidCallback? onEditMemo;
  final VoidCallback? onEditReason;

  const RoutePointNotes({
    super.key,
    required this.point,
    this.onEditMemo,
    this.onEditReason,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasMemo = point.memo.trim().isNotEmpty;
    final hasReason =
        !point.isDelivered && point.nonDeliveryReason.trim().isNotEmpty;
    Widget entry(String label, String value, VoidCallback? onEdit) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
            style: textTheme.bodyMedium,
          ),
        ),
        // Reserve the same space when switching between view and edit.
        SizedBox(
          width: 40,
          height: 40,
          child: onEdit == null
              ? null
              : AppIconButton(
                  icon: Icons.edit_outlined,
                  tooltip:
                      'Изменить ${label == 'Памятка' ? 'памятку' : 'причину недоставки'}',
                  onPressed: onEdit,
                ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Телефон: ${point.phone}', style: textTheme.bodyMedium),
        const Divider(height: 16),
        if (hasMemo) ...[
          entry('Памятка', point.memo, onEditMemo),
          const Divider(height: 16),
        ],
        if (hasReason) ...[
          entry('Не доставлено', point.nonDeliveryReason, onEditReason),
          const Divider(height: 16),
        ],
      ],
    );
  }
}

class RoutePointTaskHeading extends StatelessWidget {
  final bool isPickup;
  const RoutePointTaskHeading({super.key, this.isPickup = false});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          Icons.assignment_outlined,
          size: 20,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isPickup ? 'Товары и услуги' : 'Задание для водителя',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class RoutePointTaskTable extends StatelessWidget {
  final List<DeliveryTaskItem> items;
  final Widget Function(int) rowBuilder;
  final Widget footer;
  const RoutePointTaskTable({
    super.key,
    required this.items,
    required this.rowBuilder,
    required this.footer,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          if (items.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 700
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.labelMedium!,
                        child: const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Продукция / услуга',
                              ),
                            ),
                            SizedBox(
                              width: 156,
                              child: Text(
                                'Количество',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(
                              width: 112,
                              child: Text(
                                'Цена',
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(
                              width: 112,
                              child: Text(
                                'Сумма',
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(width: 48),
                          ],
                        ),
                      ),
                    ),
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Продукция или услуги не добавлены',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          for (var i = 0; i < items.length; i++) ...[
            rowBuilder(i),
            if (i < items.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: colorScheme.outlineVariant,
              ),
          ],
          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
          footer,
        ],
      ),
    );
  }
}
