import 'dart:async';

import 'package:mountain_fairytale/core/theme.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/client_dialog.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_selection_panel.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/products/products_abcs.dart';
import 'package:mountain_fairytale/features/payment_methods/payment_method_abcs.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/shared/widgets/dropdown_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

Client row({String id = 'client-uuid', bool active = true}) => Client(
  id: id,
  name: 'Клиент',
  phone: '123',
  address: 'Адрес',
  sleepingThresholdDays: 0,
  createdAt: DateTime(2026),
  isActive: active,
  salesRepresentativeId: 'inactive-rep',
  salesRepresentativeName: 'Архивный представитель',
  defaultPaymentMethodId: 'inactive-method',
  defaultPaymentMethodName: 'Архивный способ оплаты',
);

class ClientsFake implements ClientRepository {
  bool conflict = false;
  bool duplicateFailure = false;
  Client? duplicate;
  Completer<Client?>? duplicateGate;
  Completer<List<Client>>? listGate;
  Future<List<Client>> Function(String?, bool)? onSearch;
  int checks = 0;
  int creates = 0;
  CreateClientRequest? created;
  UpdateClientRequest? updated;
  @override
  Future<List<ClientDirectoryEntry>> getSalesRepresentatives() async => [];
  @override
  Future<List<ClientDirectoryEntry>> getPaymentMethods() async => [];
  @override
  Future<Client?> checkDuplicate(
    String name,
    String phone,
    String address,
  ) async {
    checks++;
    if (duplicateFailure) throw Exception('offline');
    return duplicateGate == null ? duplicate : await duplicateGate!.future;
  }

  @override
  Future<Client> createClient(CreateClientRequest request) async {
    creates++;
    created = request;
    if (conflict) {
      throw const ApiException(statusCode: 409, message: 'Conflict');
    }
    return row();
  }

  @override
  Future<Client> updateClient(String id, UpdateClientRequest request) async {
    updated = request;
    return row(id: id, active: request.isActive ?? true);
  }

  @override
  Future<List<Client>> getAllClients({
    String? search,
    bool includeDeactivated = false,
  }) async => onSearch != null
      ? await onSearch!(search, includeDeactivated)
      : listGate == null
      ? [row()]
      : await listGate!.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SearchProducts implements ProductRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SearchPayments implements PaymentMethodRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SearchOrders extends OrderPointsProvider {
  SearchOrders(ClientRepository clients)
    : super(
        clientRepo: clients,
        productRepo: SearchProducts(),
        paymentMethodRepo: SearchPayments(),
      );
}

Future<void> openDialog(
  WidgetTester tester,
  ClientsFake repo, {
  Client? client,
}) async {
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = ClientsProvider(repo);
  addTearDown(provider.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: AppTheme.createTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => ClientDialog(client: client),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Открыть'));
  await tester.pumpAndSettle();
}

Finder field(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  ),
  matching: find.byType(TextFormField),
);
Future<void> fill(WidgetTester tester) async {
  await tester.enterText(field('Название организации / ФИО *'), 'Клиент');
  await tester.enterText(field('Адрес доставки *'), 'Адрес');
  await tester.enterText(field('Номер телефона *'), '123');
  await tester.enterText(field('Порог засыпания (в днях) *'), '0');
  await tester.pump();
}

void main() {
  testWidgets(
    'shared form style, zero threshold and three-field duplicate check',
    (tester) async {
      final repo = ClientsFake();
      await openDialog(tester, repo);
      expect(find.byType(BaseFormDialog), findsOneWidget);
      expect(find.byType(AppPrimaryButton), findsOneWidget);
      await tester.enterText(field('Название организации / ФИО *'), 'Клиент');
      await tester.enterText(field('Адрес доставки *'), 'Адрес');
      await tester.pumpAndSettle();
      expect(repo.checks, 0);
      await fill(tester);
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();
      expect(repo.checks, greaterThanOrEqualTo(1));
      expect(repo.creates, 1);
      expect(repo.created!.sleepingThresholdDays, 0);
      expect(find.byType(ClientDialog), findsNothing);
    },
  );

  testWidgets('phone conflict appears inside field and clears on input', (
    tester,
  ) async {
    final repo = ClientsFake()..conflict = true;
    await openDialog(tester, repo);
    await fill(tester);
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(field('Номер телефона *')).forceErrorText,
      'Телефон уже используется другим клиентом',
    );
    expect(find.byType(ClientDialog), findsOneWidget);
    await tester.enterText(field('Номер телефона *'), '456');
    await tester.pump();
    expect(
      tester.widget<TextFormField>(field('Номер телефона *')).forceErrorText,
      isNull,
    );
  });

  testWidgets('duplicate failure prevents unverified create and allows retry', (
    tester,
  ) async {
    final repo = ClientsFake()..duplicateFailure = true;
    await openDialog(tester, repo);
    await fill(tester);
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    expect(repo.creates, 0);
    expect(
      find.text('Не удалось проверить похожих клиентов. Повторите попытку.'),
      findsOneWidget,
    );
    repo.duplicateFailure = false;
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    expect(repo.creates, 1);
  });

  testWidgets(
    'inactive duplicate offers activation and creating needs confirmation',
    (tester) async {
      final repo = ClientsFake()..duplicate = row(active: false);
      await openDialog(tester, repo);
      await fill(tester);
      await tester.tap(find.text('Добавить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Неактивен'), findsWidgets);
      expect(repo.creates, 0);
      await tester.tap(find.text('Создать нового'));
      await tester.pumpAndSettle();
      expect(repo.creates, 1);
    },
  );

  testWidgets(
    'editing preserves inactive related UUIDs absent from active directories',
    (tester) async {
      final repo = ClientsFake();
      await openDialog(tester, repo, client: row());
      expect(
        find.text('Архивный представитель (текущее значение)'),
        findsOneWidget,
      );
      expect(
        find.text('Архивный способ оплаты (текущее значение)'),
        findsOneWidget,
      );
      expect(find.byType(AppDropdown<String>), findsNWidgets(2));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(repo.updated!.toJson()['salesRepresentativeId'], 'inactive-rep');
      expect(
        repo.updated!.toJson()['defaultPaymentMethodId'],
        'inactive-method',
      );
    },
  );

  testWidgets('stale duplicate response cannot mark changed input checked', (
    tester,
  ) async {
    final gate = Completer<Client?>();
    final repo = ClientsFake()..duplicateGate = gate;
    await openDialog(tester, repo);
    await fill(tester);
    expect(repo.checks, greaterThanOrEqualTo(1));
    tester
            .widget<TextField>(
              find.descendant(
                of: field('Название организации / ФИО *'),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text =
        'Новое имя';
    gate.complete(row(active: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('Найден похожий клиент:'), findsNothing);
  });

  test(
    'a completed mutation cannot be overwritten by an older list response',
    () async {
      final gate = Completer<List<Client>>();
      final repo = ClientsFake()..listGate = gate;
      final provider = ClientsProvider(repo);
      addTearDown(provider.dispose);
      final loading = provider.fetchClients();
      expect(await provider.setClientActive('activated', true), isTrue);
      gate.complete([row(id: 'outdated')]);
      await loading;
      expect(provider.clients.single.id, 'activated');
      expect(provider.status, ClientStatus.success);
    },
  );

  testWidgets(
    'search ignores older responses and inactive clients cannot be added',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final oldResponse = Completer<List<Client>>();
      final repo = ClientsFake()
        ..onSearch = (query, include) async {
          if (query == 'старый') return oldResponse.future;
          return [row(id: include ? 'inactive' : 'current', active: !include)];
        };
      final provider = ClientsProvider(repo);
      final orders = SearchOrders(repo);
      addTearDown(provider.dispose);
      addTearDown(orders.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.createTheme(Brightness.light),
            home: Scaffold(
              body: SizedBox(
                width: 500,
                child: ClientSelectionPanel(provider: orders),
              ),
            ),
          ),
        ),
      );
      final search = find.byType(TextField);
      await tester.enterText(search, 'старый');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(search, 'новый');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      oldResponse.complete([row(id: 'outdated')]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Клиент'));
      expect(orders.points.single.clientId, 'current');
      orders.points.clear();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.textContaining('Деактивирован'), findsOneWidget);
      await tester.tap(find.text('Клиент'));
      expect(orders.points, isEmpty);
      orders.addClientPoint(row(active: false));
      expect(orders.points, isEmpty);
    },
  );

  testWidgets(
    'deactivation confirmation saves only isActive and can be cancelled',
    (tester) async {
      final repo = ClientsFake();
      await openDialog(tester, repo, client: row());
      await tester.tap(find.byTooltip('Деактивировать клиента'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отмена').last);
      await tester.pumpAndSettle();
      expect(repo.updated, isNull);
      await tester.tap(find.byTooltip('Деактивировать клиента'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Деактивировать'));
      await tester.pumpAndSettle();
      expect(repo.updated!.toJson(), {'isActive': false});
      expect(find.byType(ClientDialog), findsNothing);
    },
  );
}
