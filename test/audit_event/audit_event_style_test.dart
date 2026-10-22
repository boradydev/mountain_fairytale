import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/theme.dart';
import 'package:mountain_fairytale/features/audit_event/audit_events_abcs.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_model.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_provider.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_row.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_screen.dart';
import 'package:provider/provider.dart';

AuditEvent sample(
  String id, {
  String? operation,
  String action = 'created',
  String actor = 'manager',
  String actorId = 'manager-id',
  String name = 'Вода талая',
  String type = 'product',
  String? documentType,
  Map<String, Object?> data = const {},
  Map<String, Object?> changes = const {},
}) => AuditEvent.fromJson({
  'eventId': id,
  'operationId': operation ?? id,
  'eventType': 'TestEvent',
  'createdAt': '2026-10-14T09:35:00Z',
  'actor': {
    'actorId': actorId,
    'displayName': actorId.startsWith('00000000') ? null : actor,
  },
  'subject': {
    'id': '$id-subject',
    'type': type,
    'displayName': name,
    'documentType': documentType,
  },
  'action': action,
  'data': data,
  'changes': changes,
});

class StyleRepository implements AuditLogRepository {
  final List<AuditEvent> rows;
  StyleRepository(this.rows);
  Future<AuditPage> Function(String?)? load;
  @override
  Future<AuditPage> getAuditEvents({
    String? search,
    String? cursor,
    required int limit,
  }) async => load == null ? AuditPage(events: rows) : await load!(cursor);
}

Future<void> pumpRows(
  WidgetTester tester,
  List<AuditEvent> events, {
  Brightness brightness = Brightness.light,
  double width = 900,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.createTheme(brightness),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final event in events)
                  AuditOperationRow(
                    operation: AuditOperation(event.operationId, [event]),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'compact row, action colors and hidden details in $brightness',
      (tester) async {
        final event = sample(
          'create',
          data: {'name': 'Вода талая', 'basePrice': 100},
        );
        final semantics = tester.ensureSemantics();
        await pumpRows(tester, [event], brightness: brightness);
        expect(find.text('manager → Товар: Вода талая'), findsOneWidget);
        expect(find.text('Базовая цена'), findsNothing);
        expect(find.byType(Card), findsNothing);
        final header = find.byKey(const ValueKey('audit-header-create'));
        expect(tester.getSize(header).height, lessThanOrEqualTo(48));
        final icon = tester.widget<Icon>(find.byIcon(Icons.add_circle_outline));
        expect(
          icon.color,
          brightness == Brightness.dark
              ? Colors.green.shade400
              : Colors.green.shade700,
        );
        expect(find.byTooltip('Создание'), findsNWidgets(2));
        expect(
          tester
              .getSemantics(header)
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        semantics.dispose();
        await tester.tap(header);
        await tester.pumpAndSettle();
        expect(find.text('Базовая цена'), findsOneWidget);
        expect(find.text('100'), findsOneWidget);
        expect(find.byTooltip('Скрыть подробности'), findsOneWidget);
        await tester.tap(header);
        await tester.pumpAndSettle();
        expect(find.text('Базовая цена'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('system identity, login wording and red power instead of trash', (
    tester,
  ) async {
    await pumpRows(tester, [
      sample(
        'system',
        actorId: '00000000-0000-0000-0000-000000000000',
        name: 'admin',
        type: 'employee',
        data: {'username': 'admin'},
      ),
      sample(
        'login',
        action: 'login',
        actor: 'admin',
        name: 'admin',
        type: 'employee',
      ),
      sample(
        'off',
        action: 'deactivated',
        changes: {
          'isActive': {'oldValue': true, 'newValue': false},
        },
      ),
    ]);
    expect(find.text('Система → Сотрудник: admin'), findsOneWidget);
    expect(find.text('admin — вошёл в систему'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('audit-header-login')),
        matching: find.byIcon(Icons.expand_more),
      ),
      findsNothing,
    );
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.toggle_off_outlined)).color,
      AppTheme.createTheme(Brightness.light).colorScheme.error,
    );
    expect(find.byTooltip('Деактивация'), findsNWidgets(2));
  });

  testWidgets(
    'document is primary and keeps expansion as child events arrive',
    (tester) async {
      final document = sample(
        'doc',
        operation: 'save',
        action: 'updated',
        type: 'delivery_document',
        name: '2026-10-15',
        documentType: 'delivery_route_sheet',
        changes: {
          'startMileage': {'oldValue': 200, 'newValue': 205},
        },
      );
      final item = sample(
        'item',
        operation: 'save',
        action: 'updated',
        type: 'delivery_item',
        changes: {
          'quantity': {'oldValue': 2, 'newValue': 3},
        },
      );
      expect(AuditOperation('save', [item, document]).primaryEvent, document);
      final repo = StyleRepository([])
        ..load = (cursor) async => cursor == null
            ? AuditPage(events: [document], nextCursor: 'next')
            : AuditPage(events: [item]);
      final provider = AuditLogProvider(repo);
      addTearDown(provider.dispose);
      await provider.fetchEvents();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.createTheme(Brightness.light),
            home: const Scaffold(body: AuditLogScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('manager → Маршрутный лист: 15.10.2026'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('audit-header-save')));
      await tester.pumpAndSettle();
      await provider.fetchEvents();
      await tester.pumpAndSettle();
      expect(find.byType(AuditOperationRow), findsOneWidget);
      expect(find.text('Связанные изменения'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('audit-related-item')));
      await tester.pumpAndSettle();
      expect(find.text('Количество'), findsOneWidget);
      expect(find.text('Начальный пробег'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long names, large text and dynamic nested fields do not overflow',
    (tester) async {
      final name = List.filled(12, 'Длинное название').join(' ');
      await pumpRows(
        tester,
        [
          sample(
            'long',
            name: name,
            action: 'updated',
            changes: {
              'items': {
                'oldValue': [
                  {'quantity': 2, 'price': 100},
                ],
                'newValue': [
                  {'quantity': 4, 'price': 120},
                ],
              },
              'newField': {
                'oldValue': null,
                'newValue': {
                  'nested': ['value', true],
                },
              },
            },
          ),
        ],
        width: 320,
        scale: 1.8,
      );
      expect(find.byTooltip('manager → Товар: $name'), findsOneWidget);
      final text = tester.widget<Text>(find.text('manager → Товар: $name'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      await tester.tap(find.byKey(const ValueKey('audit-header-long')));
      await tester.pumpAndSettle();
      expect(find.text('newField'), findsOneWidget);
      expect(find.text('Позиции'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('render light and dark compact journal previews', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('AuditPreview')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final fallback = File('C:/Windows/Fonts/segoeui.ttf');
      if (await fallback.exists()) {
        final symbols = FontLoader('AuditSymbols')
          ..addFont(
            fallback.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await symbols.load();
      }
    });
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final repo = StyleRepository([
        sample(
          'login',
          action: 'login',
          actor: 'admin',
          type: 'employee',
          name: 'admin',
        ),
        sample(
          'employee',
          actorId: '00000000-0000-0000-0000-000000000000',
          type: 'employee',
          name: 'admin',
          data: {'username': 'admin'},
        ),
        sample(
          'manager',
          actor: 'admin',
          name: 'manager',
          type: 'employee',
          data: {'username': 'manager'},
        ),
        sample(
          'product',
          data: {'name': 'Вода талая', 'basePrice': 100, 'isActive': true},
        ),
        sample(
          'edit',
          action: 'updated',
          changes: {
            'basePrice': {'oldValue': 100, 'newValue': 120},
            'name': {'oldValue': 'Вода 19 л', 'newValue': 'Вода талая'},
          },
        ),
        sample(
          'doc',
          operation: 'document',
          action: 'updated',
          type: 'delivery_document',
          name: '2026-10-15',
          documentType: 'delivery_route_sheet',
          changes: {
            'startMileage': {'oldValue': 200, 'newValue': 205},
          },
        ),
        sample(
          'item',
          operation: 'document',
          action: 'updated',
          type: 'delivery_item',
          changes: {
            'quantity': {'oldValue': 2, 'newValue': 3},
          },
        ),
        sample(
          'off',
          action: 'deactivated',
          changes: {
            'isActive': {'oldValue': true, 'newValue': false},
          },
        ),
        sample(
          'cancel',
          action: 'cancelled',
          type: 'delivery_document',
          name: '2026-10-15',
          documentType: 'pickup_sheet',
          changes: {
            'isActive': {'oldValue': true, 'newValue': false},
          },
        ),
      ]);
      final provider = AuditLogProvider(repo);
      final key = GlobalKey();
      final theme = AppTheme.createTheme(brightness);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(
                  fontFamily: 'AuditPreview',
                  fontFamilyFallback: ['AuditSymbols'],
                ),
              ),
              home: const Scaffold(body: AuditLogScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('audit-header-edit')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1.5);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/audit-events/${brightness.name}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    }
  }, skip: !const bool.fromEnvironment('AUDIT_PREVIEW'));
}
