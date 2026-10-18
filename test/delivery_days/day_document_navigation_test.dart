import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/day_documents_dialog.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_provider.dart';
import 'package:mountain_fairytale/shared/providers/theme_provider.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';

import 'delivery_days_provider_test.dart' show DaysRepository;
import '../delivery_documents/constructors_test.dart'
    show
        Routes,
        Pickups,
        Products,
        PaymentDirectory,
        Drivers,
        Cars,
        PrintService;
import '../delivery_documents/document_provider_test.dart' show Clients;

void main() {
  final date = DateTime(2025, 3, 15);
  late Routes routes;
  late Pickups pickups;
  late DaysRepository repo;
  late DeliveryDaysProvider days;
  late RouteConstructorProvider delivery;
  late PickupConstructorProvider pickup;
  late ClientsProvider clients;
  late ThemeProvider theme;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    theme = ThemeProvider(await SharedPreferences.getInstance());
    routes = Routes();
    pickups = Pickups();
    repo = DaysRepository();
    days = DeliveryDaysProvider(repo);
    delivery = RouteConstructorProvider(
      carRepo: Cars(),
      driverRepo: Drivers(),
      routeRepo: routes,
      printService: PrintService(),
      productRepo: Products(),
      paymentMethodRepo: PaymentDirectory(),
      clientRepo: Clients(),
    );
    pickup = PickupConstructorProvider(
      pickupRepo: pickups,
      productRepo: Products(),
      paymentMethodRepo: PaymentDirectory(),
      clientRepo: Clients(),
    );
    clients = ClientsProvider(Clients());
  });
  tearDown(() {
    delivery.dispose();
    pickup.dispose();
    clients.dispose();
    theme.dispose();
    days.dispose();
  });

  Future<void> showDay(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: delivery),
          ChangeNotifierProvider.value(value: pickup),
          ChangeNotifierProvider.value(value: clients),
          ChangeNotifierProvider.value(value: theme),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('День'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      DayDocumentsDialog(date: date, daysProvider: days),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('День'));
    await tester.pumpAndSettle();
  }

  for (final isDelivery in [true, false]) {
    testWidgets(
      'create ${isDelivery ? 'delivery' : 'pickup'} pre-fills editable day without autosave',
      (tester) async {
        await showDay(tester);
        await tester.tap(
          find.text(isDelivery ? 'Добавить доставку' : 'Добавить самовывоз'),
        );
        await tester.pumpAndSettle();
        expect(isDelivery ? delivery.selectedDate : pickup.selectedDate, date);
        expect(find.text('Сохранить'), findsOneWidget);
        final earlier = DateTime(2020, 1, 1);
        if (isDelivery) {
          delivery.setDate(earlier);
        } else {
          pickup.setDate(earlier);
        }
        expect(
          isDelivery ? delivery.selectedDate : pickup.selectedDate,
          earlier,
        );
        await tester.tap(find.text('Закрыть'));
        await tester.pumpAndSettle();
        expect(find.byType(DayDocumentsDialog), findsOneWidget);
        expect(routes.saved, 0);
        expect(pickups.creates, 0);
        expect(repo.dayCalls, isEmpty);
        expect(repo.documentCalls.length, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'saving pickup returns to day and refreshes documents and cards once',
    (tester) async {
      repo.loadDocuments = (_, _) async =>
          pickups.sheet == null ? [] : [pickups.sheet!];
      await showDay(tester);
      await tester.tap(find.text('Добавить самовывоз'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(pickups.creates, 1);
      expect(pickups.sheet!.date, date);
      expect(find.byType(DayDocumentsDialog), findsOneWidget);
      expect(find.text('13.10.2026 10:00'), findsOneWidget);
      expect(repo.documentCalls.length, 2);
      expect(repo.dayCalls.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'view does not acquire lock; cancel and restore each refresh day immediately',
    (tester) async {
      repo.loadDocuments = (_, includeCancelled) async =>
          routes.sheet.isActive || includeCancelled ? [routes.sheet] : [];
      await showDay(tester);
      await tester.tap(find.byType(LabeledCheckboxToggle));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Водитель'));
      await tester.pumpAndSettle();
      expect(routes.acquired, 0);
      await tester.tap(find.text('Отменить документ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отменить документ').last);
      await tester.pumpAndSettle();
      expect(routes.sheet.isActive, isFalse);
      expect(repo.dayCalls.length, 1);
      expect(repo.documentCalls.last, (date, true));
      await tester.tap(find.text('Восстановить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Восстановить').last);
      await tester.pumpAndSettle();
      expect(routes.sheet.isActive, isTrue);
      expect(repo.dayCalls.length, 2);
      expect(repo.documentCalls.length, 4);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      expect(find.byType(DayDocumentsDialog), findsOneWidget);
      expect(
        tester
            .widget<LabeledCheckboxToggle>(find.byType(LabeledCheckboxToggle))
            .value,
        isTrue,
      );
      expect(repo.dayCalls.length, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
