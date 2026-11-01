import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_provider.dart';

import 'constructors_test.dart' as fixtures;
import 'document_provider_test.dart' show Clients, point;

Client _client(String method) => Client(
  id: 'client',
  name: 'Клиент',
  phone: '123',
  address: 'Адрес',
  sleepingThresholdDays: 7,
  createdAt: DateTime(2026),
  isActive: true,
  defaultPaymentMethodId: method,
  defaultPaymentMethodName: method,
);

class _Clients extends Clients {
  Client saved = _client('cash');
  @override
  Future<Client> updateClient(String id, UpdateClientRequest request) async {
    saved = _client(request.defaultPaymentMethodId as String);
    return saved;
  }
}

PaymentMethod get _sbp => PaymentMethod(
  id: 'sbp',
  name: 'СБП',
  createdAt: DateTime(2026),
  isActive: true,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'new point captures default once and sends that snapshot including null',
    () async {
      final clients = _Clients();
      final directory = ClientsProvider(clients);
      final provider = PickupConstructorProvider(
        pickupRepo: fixtures.Pickups(),
        productRepo: fixtures.Products(),
        paymentMethodRepo: fixtures.PaymentDirectory(),
        clientRepo: clients,
      );
      addTearDown(provider.dispose);
      addTearDown(directory.dispose);
      provider.resetForm();
      provider.addClientPoint(clients.saved);
      expect(provider.points.single.documentPaymentMethodId, 'cash');
      provider.syncClientPoint(_client('card'));
      expect(provider.points.single.paymentMethodId, 'card');
      expect(provider.points.single.documentPaymentMethodId, 'cash');
      expect(
        provider.points.single.toRequestJson(creating: true)['paymentMethodId'],
        'cash',
      );
      expect(
        await provider.selectPointPaymentMethod('client', _sbp, directory),
        isTrue,
      );
      expect(clients.saved.defaultPaymentMethodId, 'sbp');
      expect(provider.points.single.documentPaymentMethodId, 'sbp');
      expect(
        provider.points.single.toRequestJson(creating: true)['paymentMethodId'],
        'sbp',
      );
      final legacy = RoutePoint.fromJson({
        ...point.toJson(),
        'defaultPaymentMethodId': 'card',
        'paymentMethodId': null,
      });
      expect(legacy.documentPaymentMethodId, isNull);
      expect(
        legacy
            .copyWith(items: [])
            .toRequestJson(creating: false)['paymentMethodId'],
        isNull,
      );
      expect(
        legacy.toRequestJson(creating: false).containsKey('paymentMethodId'),
        isTrue,
      );
    },
  );

  for (final delivery in [true, false]) {
    test(
      'payment selection updates client immediately; cancel restores document; delivery=$delivery',
      () async {
        final clients = _Clients();
        final directory = ClientsProvider(clients);
        final original = RoutePoint.fromJson({
          ...point.toJson(),
          'defaultPaymentMethodId': 'card',
          'paymentMethodId': 'cash',
          'paymentMethodName': 'Наличные',
        });
        final routes = fixtures.Routes();
        routes.sheet = DeliveryRouteSheet.fromJson({
          ...routes.sheet.toJson(),
          'points': [original.toJson()],
        });
        final pickups = fixtures.Pickups()
          ..sheet = PickupSheet(
            id: 'pickup',
            date: DateTime(2026, 11, 1),
            points: [original],
          );
        final OrderPointsProvider provider;
        if (delivery) {
          final route = RouteConstructorProvider(
            carRepo: fixtures.Cars(),
            driverRepo: fixtures.Drivers(),
            routeRepo: routes,
            printService: fixtures.PrintService(),
            productRepo: fixtures.Products(),
            paymentMethodRepo: fixtures.PaymentDirectory(),
            clientRepo: clients,
          );
          await route.loadExistingRouteById('document');
          provider = route;
        } else {
          final pickup = PickupConstructorProvider(
            pickupRepo: pickups,
            productRepo: fixtures.Products(),
            paymentMethodRepo: fixtures.PaymentDirectory(),
            clientRepo: clients,
          );
          await pickup.loadExistingPickupById('pickup');
          provider = pickup;
        }
        addTearDown(provider.dispose);
        addTearDown(directory.dispose);
        expect(await provider.beginEditing(), isTrue);
        expect(provider.points.single.documentPaymentMethodId, 'cash');
        expect(
          await provider.selectPointPaymentMethod('client', _sbp, directory),
          isTrue,
        );
        expect(clients.saved.defaultPaymentMethodId, 'sbp');
        expect(provider.points.single.documentPaymentMethodId, 'sbp');
        expect(routes.sheet.points.single.documentPaymentMethodId, 'cash');
        expect(pickups.sheet!.points.single.documentPaymentMethodId, 'cash');
        expect(await provider.cancelEditing(), isTrue);
        expect(provider.points.single.documentPaymentMethodId, 'cash');
        expect(clients.saved.defaultPaymentMethodId, 'sbp');
        expect(routes.saved, 0);
        expect(pickups.updates, 0);
        await provider.closeDocument();
      },
    );
  }
}
