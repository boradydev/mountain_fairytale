import 'dart:convert';
import 'dart:typed_data';

import 'package:mountain_fairytale/features/clients/data/location_repository.dart';
import 'package:mountain_fairytale/shared/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_api_repo.dart';
import 'package:mountain_fairytale/features/sales_representatives/ui/sales_rep_dialog.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/payment_methods/ui/payment_method_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';

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

const testAddress = DeliveryAddress(
  district: 'Шпаковский округ',
  locality: 'Михайловск',
  street: 'Локомотивная улица',
  house: '147',
  latitude: 45.1373445,
  longitude: 41.9974531,
);

class FakeLocations implements LocationRepository {
  int searches = 0;
  bool fail = false;
  @override
  Future<List<LocationCandidate>> search(Map<String, String> a) async {
    searches++;
    if (fail) throw StateError('Provider unavailable');
    return [
      LocationCandidate({
        'formatted': 'Локомотивная улица 147, Михайловск',
        'latitude': 45.1373445,
        'longitude': 41.9974531,
        'confidence': 1.0,
        'exactHouse': true,
      }),
    ];
  }

  @override
  Future<Uint8List> tile(int z, int x, int y) async => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Client row({
  String id = 'client-uuid',
  bool active = true,
  DateTime? cooldownUntil,
}) => Client(
  id: id,
  cooldownUntil: cooldownUntil,
  name: 'Клиент',
  phone: '+79123456789',
  address: 'Адрес',
  deliveryAddress: testAddress,
  sleepingThresholdDays: 0,
  createdAt: DateTime(2026),
  isActive: active,
  salesRepresentativeId: 'inactive-rep',
  salesRepresentativeName: 'Архивный представитель',
  defaultPaymentMethodId: 'inactive-method',
  defaultPaymentMethodName: 'Архивный способ оплаты',
);

class ClientsFake implements ClientRepository {
  List<ClientDirectoryEntry> salesRepRows = [];
  List<ClientDirectoryEntry> paymentRows = [];
  Client? selected;
  bool conflict = false;
  bool duplicateFailure = false;
  Client? duplicate;
  Completer<Client?>? duplicateGate;
  Completer<List<ClientDirectoryEntry>>? salesRepGate;
  Completer<List<ClientDirectoryEntry>>? paymentGate;
  int salesRepLoads = 0;
  int paymentLoads = 0;
  Completer<List<Client>>? listGate;
  Future<List<Client>> Function(String?, bool)? onSearch;
  int checks = 0;
  int creates = 0;
  CreateClientRequest? created;
  UpdateClientRequest? updated;
  @override
  Future<List<ClientDirectoryEntry>> getSalesRepresentatives({
    bool includeDeactivated = false,
  }) async {
    salesRepLoads++;
    return salesRepGate == null
        ? salesRepRows
              .where((row) => includeDeactivated || row.isActive)
              .toList()
        : await salesRepGate!.future;
  }

  @override
  Future<List<ClientDirectoryEntry>> getPaymentMethods({
    bool includeDeactivated = false,
  }) async {
    paymentLoads++;
    return paymentGate == null
        ? paymentRows
              .where((row) => includeDeactivated || row.isActive)
              .toList()
        : await paymentGate!.future;
  }

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
  SearchOrders(ClientRepository clients, {PaymentMethodRepository? payments})
    : super(
        clientRepo: clients,
        productRepo: SearchProducts(),
        paymentMethodRepo: payments ?? SearchPayments(),
      );
}

class FormRepresentatives implements SalesRepresentativeApiRepository {
  final ClientsFake clients;
  FormRepresentatives(this.clients);
  ApiSalesRepresentative? saved;
  @override
  Future<ApiSalesRepresentative?> checkDuplicate(
    String name,
    String phone,
  ) async => null;
  @override
  Future<ApiSalesRepresentative> create({
    required String name,
    required String phone,
    required double commissionPercent,
  }) async {
    final record = ApiSalesRepresentative(
      id: 'new-rep',
      name: name,
      phone: phone,
      commissionPercent: commissionPercent,
      isActive: true,
    );
    clients.salesRepRows.add(ClientDirectoryEntry(record.id, record.name));
    return saved = record;
  }

  @override
  Future<ApiSalesRepresentative> get(String id) async => saved!;
  @override
  Future<ApiSalesRepresentative> update(
    String id,
    Map<String, dynamic> changes,
  ) async {
    final previous = saved!;
    final record = ApiSalesRepresentative(
      id: id,
      name: changes['name'] as String? ?? previous.name,
      phone: changes['phone'] as String? ?? previous.phone,
      commissionPercent:
          changes['commissionPercent'] as double? ?? previous.commissionPercent,
      isActive: changes['isActive'] as bool? ?? previous.isActive,
    );
    clients.salesRepRows = [
      ClientDirectoryEntry(record.id, record.name, isActive: record.isActive),
    ];
    return saved = record;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FormPayments implements PaymentMethodRepository {
  final ClientsFake clients;
  FormPayments(this.clients);
  PaymentMethod? saved;
  @override
  Future<PaymentMethod?> checkDuplicate(String name) async => null;
  @override
  Future<PaymentMethod> createPaymentMethod(
    CreatePaymentMethodRequest request,
  ) async {
    final record = PaymentMethod(
      id: 'new-pay',
      name: request.name,
      createdAt: DateTime(2026),
      isActive: true,
    );
    clients.paymentRows.add(ClientDirectoryEntry(record.id, record.name));
    return saved = record;
  }

  @override
  Future<PaymentMethod> getPaymentMethodById(String id) async => saved!;
  @override
  Future<PaymentMethod> updatePaymentMethod(
    String id,
    UpdatePaymentMethodRequest request,
  ) async {
    final record = PaymentMethod(
      id: id,
      name: request.name ?? saved!.name,
      createdAt: saved!.createdAt,
      isActive: request.isActive ?? saved!.isActive,
    );
    clients.paymentRows = [
      ClientDirectoryEntry(record.id, record.name, isActive: record.isActive),
    ];
    return saved = record;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> openDialog(
  WidgetTester tester,
  ClientsFake repo, {
  Client? client,
  bool settle = true,
  SalesRepresentativeApiRepository? reps,
  OrderPointsProvider? orders,
  LocationRepository? locations,
}) async {
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = ClientsProvider(repo);
  addTearDown(provider.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        Provider<LocationRepository>.value(value: locations ?? FakeLocations()),
        if (reps != null)
          Provider<SalesRepresentativeApiRepository>.value(value: reps),
      ],
      child: MaterialApp(
        theme: AppTheme.createTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                repo.selected = await showClientDialog(
                  context,
                  client: client,
                  orderProvider: orders,
                );
              },
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Открыть'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Finder field(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  ),
  matching: find.byType(TextFormField),
);
Future<void> fill(WidgetTester tester, {bool withDistrict = true}) async {
  await tester.enterText(field('Название организации / ФИО *'), 'Клиент');
  await tester.ensureVisible(find.text('Заполнить через карту'));
  await tester.tap(find.text('Заполнить через карту'));
  await tester.pumpAndSettle();
  for (final entry in {
    'Район / муниципальный или городской округ': withDistrict
        ? 'Шпаковский округ'
        : '',
    'Населённый пункт (с типом) *': 'Михайловск',
    'Улица (с типом) *': 'Локомотивная улица',
    'Дом *': '147',
  }.entries) {
    await tester.ensureVisible(field(entry.key));
    await tester.enterText(field(entry.key), entry.value);
  }
  await tester.ensureVisible(find.text('Найти адрес'));
  await tester.tap(find.text('Найти адрес'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Подтвердить местоположение'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(field('Номер телефона *'));
  await tester.enterText(field('Номер телефона *'), '9123456789');
  await tester.enterText(field('Порог засыпания (в днях) *'), '0');
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

void main() {
  testWidgets(
    'free address and delivery details save without any Geoapify request',
    (tester) async {
      final repo = ClientsFake();
      final geo = FakeLocations()..fail = true;
      await openDialog(tester, repo, locations: geo);
      expect(field('Населённый пункт (с типом) *'), findsNothing);
      await tester.enterText(field('Название организации / ФИО *'), 'Клиент');
      await tester.enterText(field('Адрес *'), 'Михайловск, заезд Добрый 17');
      await tester.enterText(field('Детали доставки'), 'Вход со двора');
      await tester.enterText(field('Номер телефона *'), '9123456789');
      await tester.ensureVisible(find.text('Добавить'));
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();
      expect(repo.creates, 1);
      expect(repo.created!.deliveryAddress, isNull);
      expect(repo.created!.deliveryDetails, 'Вход со двора');
      expect(repo.created!.address, 'Михайловск, заезд Добрый 17');
      expect(geo.searches, 0);
    },
  );

  testWidgets('failed search and cancelling map preserve free address', (
    tester,
  ) async {
    final repo = ClientsFake();
    final geo = FakeLocations()..fail = true;
    await openDialog(tester, repo, locations: geo);
    await tester.enterText(field('Название организации / ФИО *'), 'Клиент');
    await tester.enterText(field('Адрес *'), 'Адрес введён вручную');
    await tester.enterText(field('Номер телефона *'), '9123456789');
    await tester.tap(find.text('Заполнить через карту'));
    await tester.pumpAndSettle();
    for (final e in {
      'Населённый пункт (с типом) *': 'Михайловск',
      'Улица (с типом) *': 'Некрасова',
      'Дом *': '22/5',
    }.entries) {
      await tester.ensureVisible(field(e.key));
      await tester.enterText(field(e.key), e.value);
    }
    await tester.ensureVisible(find.text('Найти адрес'));
    await tester.tap(find.text('Найти адрес'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Поиск недоступен'), findsOneWidget);
    await tester.tap(find.text('Отмена').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Добавить'));
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    expect(repo.created!.address, 'Адрес введён вручную');
    expect(repo.created!.deliveryAddress, isNull);
    expect(geo.searches, 1);
  });

  testWidgets(
    'editing text clears coordinates while delivery details preserve them',
    (tester) async {
      final repo = ClientsFake();
      await openDialog(tester, repo, client: row());
      await tester.enterText(field('Детали доставки'), 'Новые ворота');
      expect(find.text('Местоположение подтверждено'), findsOneWidget);
      await tester.enterText(field('Адрес *'), 'Другой адрес');
      expect(find.text('Адрес введён вручную'), findsOneWidget);
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(repo.updated!.toJson()['deliveryAddress'], isNull);
      expect(repo.updated!.toJson(), containsPair('address', 'Другой адрес'));
      expect(
        repo.updated!.toJson(),
        containsPair('deliveryDetails', 'Новые ворота'),
      );
    },
  );

  testWidgets(
    'client creation accepts an empty district after location confirmation',
    (tester) async {
      final repo = ClientsFake();
      await openDialog(tester, repo);
      await fill(tester, withDistrict: false);
      await tester.ensureVisible(find.text('Добавить'));
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();
      expect(repo.creates, 1);
      expect(repo.created!.deliveryAddress!.district, '');
      expect(
        repo.created!.deliveryAddress!.formatted,
        'Михайловск, Локомотивная улица, 147',
      );
    },
  );

  testWidgets(
    'directory loading stays inside client dropdowns without moving fields',
    (tester) async {
      final gate = Completer<List<ClientDirectoryEntry>>();
      final repo = ClientsFake()..salesRepGate = gate;
      await openDialog(tester, repo, settle: false);
      await tester.pump();
      final dropdowns = find.byType(AppDropdown<String>);
      expect(dropdowns, findsNWidgets(2));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        find.descendant(
          of: dropdowns.at(0),
          matching: find.byType(LinearProgressIndicator),
        ),
        findsOneWidget,
      );
      final originalRects = [
        tester.getRect(dropdowns.at(0)),
        tester.getRect(dropdowns.at(1)),
      ];
      gate.complete([]);
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.getRect(dropdowns.at(0)), originalRects[0]);
      expect(tester.getRect(dropdowns.at(1)), originalRects[1]);
      expect(repo.salesRepLoads, 1);
      expect(repo.paymentLoads, 1);
      final repsGate = Completer<List<ClientDirectoryEntry>>();
      repo.salesRepGate = repsGate;
      await tester.ensureVisible(dropdowns.at(0));
      await tester.tap(
        find.descendant(
          of: dropdowns.at(0),
          matching: find.byTooltip('Показать неактивные записи'),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<AppDropdown<String>>(dropdowns.at(0)).isLoading,
        isTrue,
      );
      expect(
        tester.widget<AppDropdown<String>>(dropdowns.at(1)).isLoading,
        isFalse,
      );
      expect(
        tester.widget<AppDropdown<String>>(dropdowns.at(1)).enabled,
        isTrue,
      );
      expect(repo.salesRepLoads, 2);
      expect(repo.paymentLoads, 1);
      repsGate.complete([]);
      await tester.pumpAndSettle();
      final methodsGate = Completer<List<ClientDirectoryEntry>>();
      repo.paymentGate = methodsGate;
      await tester.ensureVisible(dropdowns.at(1));
      await tester.tap(
        find.descendant(
          of: dropdowns.at(1),
          matching: find.byTooltip('Показать неактивные записи'),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<AppDropdown<String>>(dropdowns.at(0)).isLoading,
        isFalse,
      );
      expect(
        tester.widget<AppDropdown<String>>(dropdowns.at(0)).enabled,
        isTrue,
      );
      expect(
        tester.widget<AppDropdown<String>>(dropdowns.at(1)).isLoading,
        isTrue,
      );
      expect(repo.salesRepLoads, 2);
      expect(repo.paymentLoads, 2);
      methodsGate.complete([]);
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shared form style, zero threshold and three-field duplicate check',
    (tester) async {
      final repo = ClientsFake();
      await openDialog(tester, repo);
      expect(find.byType(BaseFormDialog), findsOneWidget);
      expect(find.byType(AppPrimaryButton), findsOneWidget);
      await tester.enterText(field('Название организации / ФИО *'), 'Клиент');
      await tester.enterText(field('Адрес *'), testAddress.formatted);
      await tester.pumpAndSettle();
      expect(repo.checks, 0);
      await fill(tester);
      await tester.ensureVisible(find.text('Добавить'));
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
    await tester.ensureVisible(find.text('Добавить'));
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
    await tester.ensureVisible(find.text('Добавить'));
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    expect(repo.creates, 0);
    expect(
      find.text('Не удалось проверить похожих клиентов. Повторите попытку.'),
      findsOneWidget,
    );
    repo.duplicateFailure = false;
    await tester.ensureVisible(find.text('Добавить'));
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
      await tester.ensureVisible(find.text('Добавить'));
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
        find.text('Архивный представитель — Неактивен'),
        findsOneWidget,
      );
      expect(
        find.text('Архивный способ оплаты — Неактивен'),
        findsOneWidget,
      );
      expect(find.byType(AppDropdown<String>), findsNWidgets(2));
      await tester.ensureVisible(find.text('ОК'));
      await tester.tap(find.text('ОК'));
      await tester.pumpAndSettle();
      expect(repo.updated, isNull);
      expect(repo.checks, 0);
      expect(repo.selected!.salesRepresentativeId, 'inactive-rep');
      expect(repo.selected!.defaultPaymentMethodId, 'inactive-method');
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
    expect(
      find.descendant(
        of: find.byType(DuplicateCheckStatusWidget),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
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
    expect(find.byType(CircularProgressIndicator), findsNothing);
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
      await tester.tap(find.byTooltip('Показать неактивные записи'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.textContaining('Деактивирован'), findsOneWidget);
      await tester.tap(find.text('Клиент'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Отмена'));
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
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
      await tester.tap(find.text('Деактивировать').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отмена').last);
      await tester.pumpAndSettle();
      expect(repo.updated, isNull);
      await tester.tap(find.text('Деактивировать').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Деактивировать').last);
      await tester.pumpAndSettle();
      expect(repo.updated!.toJson(), {'isActive': false});
      expect(find.byType(ClientDialog), findsNothing);
    },
  );

  testWidgets(
    'expanded active duplicate selects existing client or opens its editor',
    (tester) async {
      final repo = ClientsFake()..duplicate = row(id: 'existing');
      final orders = SearchOrders(repo);
      addTearDown(orders.dispose);
      await openDialog(tester, repo, orders: orders);
      await fill(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Найден похожий клиент:'));
      await tester.pumpAndSettle();
      expect(find.text('Добавить клиента'), findsOneWidget);
      expect(find.text('Открыть клиента'), findsOneWidget);
      await tester.ensureVisible(find.text('Открыть клиента'));
      await tester.tap(find.text('Открыть клиента'));
      await tester.pumpAndSettle();
      expect(find.byType(ClientDialog), findsOneWidget);
      expect(find.text('Редактирование клиента'), findsOneWidget);
      expect(repo.creates, 0);
      await tester.ensureVisible(find.text('Отмена'));
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Найден похожий клиент:'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Добавить клиента'));
      await tester.tap(find.text('Добавить клиента'));
      await tester.pumpAndSettle();
      expect(repo.selected!.id, 'existing');
      expect(repo.creates, 0);
    },
  );

  testWidgets(
    'directory dropdowns order eye, edit, add and reuse nested editors',
    (tester) async {
      final repo = ClientsFake();
      final reps = FormRepresentatives(repo);
      final payments = FormPayments(repo);
      final orders = SearchOrders(repo, payments: payments);
      addTearDown(orders.dispose);
      await openDialog(tester, repo, reps: reps, orders: orders);
      Finder directory(String label) => find.byWidgetPredicate(
        (widget) => widget is AppDropdown<String> && widget.label == label,
      );
      final buttons = find.descendant(
        of: directory('Торговый представитель'),
        matching: find.byType(AppIconButton),
      );
      expect(
        tester
            .widgetList<AppIconButton>(buttons)
            .map((button) => button.icon)
            .toList(),
        [Icons.visibility_off_outlined, Icons.edit_outlined, Icons.add],
      );
      await tester.tap(find.byTooltip('Добавить Торговый представитель'));
      await tester.pumpAndSettle();
      expect(find.byType(SalesRepDialog), findsOneWidget);
      await tester.enterText(field('ФИО представителя *'), 'Представитель');
      await tester.enterText(field('Телефон представителя'), '9123456789');
      await tester.enterText(field('Вознаграждение'), '12.5');
      await tester.tap(find.text('Добавить').last);
      await tester.pumpAndSettle();
      expect(reps.saved!.phone, '+79123456789');
      expect(find.byType(SalesRepDialog), findsNothing);
      final repDropdown = tester.widget<AppDropdown<String>>(
        directory('Торговый представитель'),
      );
      expect(repDropdown.value, 'new-rep');
      await tester.tap(
        find.descendant(
          of: directory('Торговый представитель'),
          matching: find.byTooltip('Редактировать выбранный элемент'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(field('ФИО представителя *'), 'Новое имя');
      await tester.pump();
      await tester.tap(find.text('Сохранить').last);
      await tester.pumpAndSettle();
      expect(find.text('Новое имя'), findsOneWidget);
      await tester.tap(find.byTooltip('Добавить Способ оплаты по умолчанию'));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentMethodDialog), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, 'Наличные');
      await tester.tap(find.text('Добавить').last);
      await tester.pumpAndSettle();
      expect(payments.saved!.name, 'Наличные');
      expect(
        tester
            .widget<AppDropdown<String>>(
              directory('Способ оплаты по умолчанию'),
            )
            .value,
        'new-pay',
      );
      expect(repo.creates, 0);
      await fill(tester);
      await tester.ensureVisible(find.text('Добавить'));
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();
      expect(repo.created!.salesRepresentativeId, 'new-rep');
      expect(repo.created!.defaultPaymentMethodId, 'new-pay');
      expect(repo.created!.phone, '+79123456789');
    },
  );

  for (final active in [true, false]) {
    testWidgets('dashboard duplicate has only open action, active=$active', (
      tester,
    ) async {
      final repo = ClientsFake()
        ..duplicate = row(id: 'existing', active: active);
      await openDialog(tester, repo);
      await fill(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Найден похожий клиент:'));
      await tester.pumpAndSettle();
      expect(find.text('Добавить клиента'), findsNothing);
      expect(find.text('Активировать и добавить'), findsNothing);
      expect(find.text('Открыть клиента'), findsOneWidget);
      await tester.ensureVisible(find.text('Открыть клиента'));
      await tester.tap(find.text('Открыть клиента'));
      await tester.pumpAndSettle();
      expect(find.text('Редактирование клиента'), findsOneWidget);
      expect(repo.creates, 0);
    });
  }

  testWidgets(
    'cooldown date picker closes without time picker and saves midnight',
    (tester) async {
      final repo = ClientsFake();
      await openDialog(
        tester,
        repo,
        client: row(cooldownUntil: DateTime(2026, 10, 19, 15, 30)),
      );
      final textField = find.descendant(
        of: field('Отсрочка до'),
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(textField).controller!.text,
        '19.10.2026',
      );
      await tester.ensureVisible(field('Отсрочка до'));
      await tester.tap(field('Отсрочка до'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('20'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.byType(TimePickerDialog), findsNothing);
      await tester.pump();
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.pump();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(
        repo.updated!.toJson()['cooldownUntil'],
        '2026-10-20T00:00:00.000',
      );
    },
  );
}
