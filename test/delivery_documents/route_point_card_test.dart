import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/core/theme_extensions.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/failed_delivery_dialog.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_point_card_content.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_point_memo_dialog.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_point_read_only_card.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_points_list.dart';

import 'document_provider_test.dart'
    show Orders, PickupOrders, Catalog, Locks, Clients, point;

const memo =
    'Позвонить заранее. Длинная памятка с подробными указаниями для водителя.';
const reason =
    'Нет доступа. Подробное описание причины недоставки заказа клиенту.';

RoutePoint delivery() => RoutePoint.fromJson({
  ...point.toJson(),
  'memo': memo,
  'isDelivered': false,
  'nonDeliveryReason': reason,
});

Future<void> pumpEditor(
  WidgetTester tester,
  OrderPointsProvider orders, {
  RoutePointsViewState? viewState,
}) async {
  final clients = ClientsProvider(Clients());
  addTearDown(clients.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: clients,
      child: MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: orders,
            builder: (_, _) => RoutePointsList(
              provider: orders,
              viewState: viewState,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> selectAction(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Действия с точкой').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

final dialogField = find.descendant(
  of: find.byType(Dialog),
  matching: find.byType(TextFormField),
);

List<Object> headerTextAppearance(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(RoutePointHeader),
        matching: find.byType(Text),
      ),
    )
    .map(
      (text) => (
        text.data ?? text.textSpan?.toPlainText(),
        text.style ?? text.textSpan?.style,
        text.maxLines,
        text.softWrap,
        text.overflow,
      ),
    )
    .toList();

Finder noteText(String label, String value) => find.descendant(
  of: find.byType(RoutePointNotes),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Text && widget.textSpan?.toPlainText() == '$label: $value',
  ),
);

void main() {
  for (final hasMemo in [false, true]) {
    for (final hasReason in [false, true]) {
      testWidgets('notes and dividers: memo=$hasMemo reason=$hasReason', (
        tester,
      ) async {
        final value = RoutePoint.fromJson({
          ...point.toJson(),
          'memo': hasMemo ? memo : '   ',
          'isDelivered': false,
          'nonDeliveryReason': hasReason ? reason : '   ',
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: RoutePointNotes(point: value)),
          ),
        );
        expect(
          find.byType(Divider),
          findsNWidgets(1 + (hasMemo ? 1 : 0) + (hasReason ? 1 : 0)),
        );
        expect(
          noteText('Памятка', memo),
          hasMemo ? findsOneWidget : findsNothing,
        );
        expect(
          noteText('Не доставлено', reason),
          hasReason ? findsOneWidget : findsNothing,
        );
        expect(find.text('Не указана'), findsNothing);
        expect(find.text('Памятка'), findsNothing);
        expect(find.text('Не доставлено'), findsNothing);
      });
    }
  }

  testWidgets('wide header has two rows, theme typography and no tooltips', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = ThemeData(
      extensions: const [
        AppColorsExtension(
          warningColor: Colors.orange,
          warningContainer: Colors.amber,
          successColor: Colors.green,
          successContainer: Colors.lightGreen,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(body: RoutePointHeader(point: delivery())),
      ),
    );
    final name = find.text(point.clientName);
    final address = find.text(point.address);
    final memoText = find.byWidgetPredicate(
      (widget) =>
          widget is Text && widget.textSpan?.toPlainText() == 'Памятка: $memo',
    );
    final reasonText = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.textSpan?.toPlainText() == 'Не доставлено: $reason',
    );
    expect(tester.getTopLeft(name).dy, tester.getTopLeft(memoText).dy);
    expect(tester.getTopLeft(address).dy, tester.getTopLeft(reasonText).dy);
    expect(tester.getTopLeft(memoText).dx, tester.getTopLeft(reasonText).dx);
    expect(tester.getSize(find.byType(RoutePointHeader)).height, lessThan(55));
    final effectiveTheme = Theme.of(tester.element(name));
    final nameStyle = tester.widget<Text>(name).style!;
    expect(nameStyle.fontSize, effectiveTheme.textTheme.bodyLarge!.fontSize);
    expect(nameStyle.fontWeight, FontWeight.w600);
    final memoSpan = tester.widget<Text>(memoText).textSpan! as TextSpan;
    expect(
      memoSpan.style!.fontSize,
      effectiveTheme.textTheme.bodyLarge!.fontSize,
    );
    expect(
      (memoSpan.children!.first as TextSpan).style!.fontWeight,
      FontWeight.w600,
    );
    final reasonSpan = tester.widget<Text>(reasonText).textSpan! as TextSpan;
    expect(
      reasonSpan.style!.fontSize,
      effectiveTheme.textTheme.bodyMedium!.fontSize,
    );
    expect(
      (reasonSpan.children!.first as TextSpan).style!.color,
      Colors.orange,
    );
    for (final finder in [name, address, memoText, reasonText]) {
      final text = tester.widget<Text>(finder);
      expect(text.maxLines, 1);
      expect(text.softWrap, false);
      expect(text.overflow, TextOverflow.ellipsis);
    }
    expect(find.byType(Tooltip), findsNothing);
  });

  for (final width in [320.0, 360.0, 1200.0]) {
    testWidgets('long editor and history notes fit width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final longPoint = RoutePoint.fromJson({
        ...delivery().toJson(),
        'clientName': List.filled(20, 'Название клиента').join(' '),
        'address': List.filled(20, 'Длинный адрес').join(' '),
        'memo': List.filled(5, memo).join('\n'),
        'nonDeliveryReason': List.filled(5, reason).join('\n'),
      });
      final orders = Orders(Catalog(), Locks())..points = [longPoint];
      addTearDown(orders.dispose);
      await pumpEditor(tester, orders);
      final editorHeader = tester.widget<RoutePointHeader>(
        find.byType(RoutePointHeader),
      );
      final editorAppearance = headerTextAppearance(tester);
      await tester.tap(find.text(longPoint.clientName));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(noteText('Памятка', longPoint.memo)).maxLines,
        isNull,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [RoutePointReadOnlyCard(point: longPoint)],
            ),
          ),
        ),
      );
      expect(
        tester.widget<RoutePointHeader>(find.byType(RoutePointHeader)).point,
        editorHeader.point,
      );
      expect(headerTextAppearance(tester), editorAppearance);
      await tester.tap(find.text(longPoint.clientName));
      await tester.pumpAndSettle();
      for (final finder in [
        noteText('Памятка', longPoint.memo),
        noteText('Не доставлено', longPoint.nonDeliveryReason),
      ]) {
        final text = tester.widget<Text>(finder);
        expect(text.maxLines, isNull);
        expect(text.overflow, isNull);
      }
      expect(
        find.descendant(
          of: find.byType(RoutePointNotes),
          matching: find.byIcon(Icons.edit_outlined),
        ),
        findsNothing,
      );
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      final phoneY = tester.getTopLeft(find.text('Телефон: ${point.phone}')).dy;
      final memoY = tester.getTopLeft(noteText('Памятка', longPoint.memo)).dy;
      final reasonY = tester
          .getTopLeft(noteText('Не доставлено', longPoint.nonDeliveryReason))
          .dy;
      expect(phoneY, lessThan(memoY));
      expect(memoY, lessThan(reasonY));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('delivery menu has three actions and preserves expansion', (
    tester,
  ) async {
    final orders = Orders(Catalog(), Locks())..points = [point];
    final state = RoutePointsViewState();
    addTearDown(orders.dispose);
    await pumpEditor(tester, orders, viewState: state);
    for (final expanded in [false, true]) {
      if (expanded) {
        await tester.tap(find.text(point.clientName));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Действия с точкой'));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<String>), findsNWidgets(3));
      expect(find.text('Добавить памятку'), findsOneWidget);
      expect(find.text('Отметить как недоставленное'), findsOneWidget);
      expect(find.text('Удалить точку'), findsOneWidget);
      expect(state.isExpanded(point.viewId), expanded);
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(state.isExpanded(point.viewId), expanded);
    }
    orders.isEditing = false;
    orders.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Действия с точкой'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(RoutePointNotes),
        matching: find.byIcon(Icons.edit_outlined),
      ),
      findsNothing,
    );
  });

  testWidgets('pickup menu only deletes purchase and has no client notes', (
    tester,
  ) async {
    final orders = PickupOrders(Catalog(), Locks())..points = [point];
    addTearDown(orders.dispose);
    await pumpEditor(tester, orders);
    expect(find.text('Покупка 1'), findsOneWidget);
    expect(find.text(point.clientName), findsNothing);
    await tester.tap(find.text('Покупка 1'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutePointNotes), findsNothing);
    await tester.tap(find.byTooltip('Действия с точкой'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsOneWidget);
    await tester.tap(find.text('Удалить покупку'));
    await tester.pumpAndSettle();
    expect(orders.points, isEmpty);
  });

  testWidgets('pencils prefill dialogs and update notes and failed status', (
    tester,
  ) async {
    final orders = Orders(Catalog(), Locks())..points = [delivery()];
    addTearDown(orders.dispose);
    await pumpEditor(tester, orders);
    await tester.tap(find.text(point.clientName));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Изменить памятку'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RoutePointMemoDialog>(find.byType(RoutePointMemoDialog))
          .initialMemo,
      memo,
    );
    await tester.enterText(dialogField, 'Новая памятка');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(orders.points.single.memo, 'Новая памятка');
    expect(
      find.text('Памятка: Новая памятка', findRichText: true),
      findsNWidgets(2),
    );
    expect(noteText('Памятка', 'Новая памятка'), findsOneWidget);
    await tester.tap(find.byTooltip('Изменить причину недоставки'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FailedDeliveryDialog>(find.byType(FailedDeliveryDialog))
          .initialReason,
      reason,
    );
    expect(tester.widget<TextFormField>(dialogField).controller!.text, reason);
    await tester.enterText(dialogField, 'Новая причина');
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    expect(orders.points.single.isDelivered, false);
    expect(orders.points.single.nonDeliveryReason, 'Новая причина');
    expect(orders.grandTotal, 0);
    expect(
      find.text('Не доставлено: Новая причина', findRichText: true),
      findsNWidgets(2),
    );
    expect(noteText('Не доставлено', 'Новая причина'), findsOneWidget);
    await selectAction(tester, 'Снять отметку «Не доставлено»');
    expect(find.byType(FailedDeliveryDialog), findsNothing);
    expect(orders.points.single.isDelivered, true);
    expect(orders.grandTotal, point.totalAmount);
    final surface = find
        .descendant(
          of: find.byType(RoutePointCardSurface),
          matching: find.byType(Container),
        )
        .first;
    final decoration =
        tester.widget<Container>(surface).decoration! as BoxDecoration;
    expect(
      decoration.color,
      Theme.of(tester.element(surface)).colorScheme.surfaceContainerLow,
    );
    expect(find.text('Не доставлено'), findsNothing);
    await selectAction(tester, 'Отметить как недоставленное');
    expect(tester.widget<TextFormField>(dialogField).controller!.text, isEmpty);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    await selectAction(tester, 'Изменить памятку');
    expect(
      tester.widget<TextFormField>(dialogField).controller!.text,
      'Новая памятка',
    );
  });

  for (final editReason in [false, true]) {
    for (final remove in [false, true]) {
      testWidgets(
        'dialog uses viewId after reorder/delete: reason=$editReason remove=$remove',
        (tester) async {
          final second = RoutePoint.fromJson({
            ...point.toJson(),
            'pointId': 'second',
            'clientId': 'second',
            'clientName': 'Другой',
          });
          final orders = Orders(Catalog(), Locks())
            ..points = [delivery(), second];
          addTearDown(orders.dispose);
          await pumpEditor(tester, orders);
          if (editReason) {
            await tester.tap(find.text(point.clientName));
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Изменить причину недоставки'));
            await tester.pumpAndSettle();
          } else {
            await selectAction(tester, 'Изменить памятку');
          }
          if (remove) {
            orders.removePoint(0);
          } else {
            orders.reorderPoints(0, 2);
          }
          await tester.pumpAndSettle();
          await tester.enterText(dialogField, 'После изменения порядка');
          await tester.tap(find.text(editReason ? 'Применить' : 'Сохранить'));
          await tester.pumpAndSettle();
          expect(orders.points.first.clientId, 'second');
          expect(orders.points.first.memo, second.memo);
          expect(orders.points.first.isDelivered, true);
          if (!remove) {
            expect(
              editReason
                  ? orders.points.last.nonDeliveryReason
                  : orders.points.last.memo,
              'После изменения порядка',
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
