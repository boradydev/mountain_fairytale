import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/infrastructure/data_sources/constructor/demo_constructor_data_source.dart';
import 'package:mountain_fairytale/infrastructure/repos/constructor_directory_repo.dart';

import '../../../assets/demo/demo_asset_bundle.dart';
import 'print_model.dart';

void main() {
  final demoBundle = DemoAssetBundle.instance;

  test('should load available cars and products from directory repository', () async {
    // Используем единый источник данных, реализующий нужные интерфейсы
    final dataSource = DemoConstructorDataSource(assetBundle: demoBundle);
    final repository = ConstructorDirectoryRepository(
      carDataSource: dataSource,
      productDataSource: dataSource,
      driverDataSource: dataSource,
    );

    // 1. Проверяем загрузку автомобилей
    final cars = await repository.getAvailableCars();
    expect(cars, isNotEmpty);

    print('\n--- СПИСОК ДОСТУПНЫХ АВТОМОБИЛЕЙ ---');
    for (final car in cars) {
      printModel(car.toJson(), title: 'АВТОМОБИЛЬ ID: ${car.id}');
    }

    // 2. Проверяем загрузку товаров/услуг
    final products = await repository.getAvailableProducts();
    expect(products, isNotEmpty);

    print('\n--- СПИСОК ДОСТУПНЫХ ТОВАРОВ И УСЛУГ ---');
    for (final product in products) {
      printModel(product.toJson(), title: 'ТОВАР ID: ${product.id}');
    }
  });
}
