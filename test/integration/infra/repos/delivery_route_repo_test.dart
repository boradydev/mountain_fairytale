import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/infra/data_sources/delivery_route/demo_delivery_route_data_source.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/repo.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_task_item_model.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/route_point_model.dart';

import '../../../assets/demo/demo_asset_bundle.dart';
import 'print_model.dart';

void main() {
  final demoBundle = DemoAssetBundle.instance;

  test('should load and save delivery route sheets via repository', () async {
    // Используем декомпозированный DataSource и реализацию репозитория
    final dataSource = DemoDeliveryRouteDataSource(assetBundle: demoBundle);
    final repository = DeliveryRouteRepositoryImpl(dataSource);

    // 1. Проверяем чтение изначального списка маршрутных листов
    final initialRoutes = await repository.getRouteSheets();
    expect(initialRoutes, isNotEmpty);
    final int initialLength = initialRoutes.length;

    print('\n--- ИСХОДНЫЕ МАРШРУТНЫЕ ЛИСТЫ ---');
    for (final sheet in initialRoutes) {
      printModel(sheet.toJson(), title: 'МАРШРУТНЫЙ ЛИСТ ID: ${sheet.id}');
    }

    // 2. Формируем тестовую модель маршрутного листа для сохранения (без ID)
    final newSheetRequest = DeliveryRouteSheet(
      id: null,
      date: DateTime.now(),
      driverName: 'Сидоров Иван',
      carId: 2,
      carModelAndNumber: 'Лада Ларгус Фургон (В456РР 26)',
      startMileage: 85200.0,
      points: [
        const RoutePoint(
          clientId: 2,
          clientName: 'ИП Петров',
          city: 'Михайловск',
          address: "ул. Ленина, д. 45",
          phone: '+7 (905) 444-55-66',
          paymentMethod: 'Наличный расчет',
          salesRepresentative: 'Мария Иванова',
          items: [
            DeliveryTaskItem(
              productId: 1,
              productName: 'Вода Горная 19л',
              quantity: 2,
              price: 350.0,
            ),
            DeliveryTaskItem(
              productId: 5,
              productName: 'Ремонт/Санитария кулера',
              quantity: 1,
              price: 1500.0,
            ),
          ],
        ),
      ],
    );

    // 3. Вызываем сохранение в репозиторий
    final savedSheet = await repository.saveRouteSheet(newSheetRequest);

    // 4. Проверяем, что модель вернулась с присвоенным ID
    expect(savedSheet.id, isNotNull);
    expect(savedSheet.id, isA<int>());

    print('\n--- УСПЕШНО СОХРАНЕННЫЙ МАРШРУТНЫЙ ЛИСТ ---');
    printModel(savedSheet.toJson(), title: 'СОХРАНЕНО С ID: ${savedSheet.id}');

    // 5. Проверяем, что в репозитории теперь на один элемент больше
    final updatedRoutes = await repository.getRouteSheets();
    expect(updatedRoutes.length, initialLength + 1);

    expect(updatedRoutes.first.id, savedSheet.id);
    expect(updatedRoutes.first.driverName, 'Сидоров Иван');

    expect(savedSheet.points.first.totalAmount, 2200.0);
    expect(savedSheet.grandTotal, 2200.0);
  });
}
