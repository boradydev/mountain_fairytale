import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_repo.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_demo_data.dart';

import '../../../assets/demo/demo_asset_bundle.dart';
import 'print_model.dart';

void main() {
  final demoBundle = DemoAssetBundle.instance;

  test('should manage payment methods via repository (CRUD)', () async {
    final dataSource = DemoPaymentMethodDataSource(assetBundle: demoBundle);
    final repository = PaymentMethodRepositoryImpl(dataSource);

    // 1. READ ALL - Проверка загрузки изначального списка
    final initialList = await repository.getAllPaymentMethods();
    expect(initialList, isNotEmpty);
    final int initialLength = initialList.length;

    debugPrint('\n--- ИСХОДНЫЕ СПОСОБЫ ОПЛАТЫ ---');
    for (final method in initialList) {
      printModel(method.toJson(), title: 'СПОСОБ ОПЛАТЫ ID: ${method.id}');
    }

    // 1.2 READ BY ID - Проверка чтения конкретного элемента по ID
    final firstId = initialList.first.id;
    final fetchedById = await repository.getPaymentMethodById(firstId);
    expect(fetchedById.id, firstId);

    debugPrint('\n--- ПОЛУЧЕННЫЙ СПОСОБ ОПЛАТЫ ПО ID: $firstId ---');
    printModel(fetchedById.toJson(), title: 'СПОСОБ ОПЛАТЫ ИЗ API');

    // 2. CREATE - Проверка создания нового способа оплаты через Create Request DTO
    const createRequest = CreatePaymentMethodRequest(
      name: 'СБП (Система быстрых платежей)',
    );
    final createdMethod = await repository.createPaymentMethod(createRequest);

    expect(createdMethod.id, isNotEmpty);
    expect(createdMethod.name, createRequest.name);

    debugPrint('\n--- СОЗДАННЫЙ СПОСОБ ОПЛАТЫ ---');
    printModel(createdMethod.toJson(), title: 'НОВЫЙ СПОСОБ ОПЛАТЫ');

    // Проверяем, что в списке теперь на один элемент больше
    var updatedList = await repository.getAllPaymentMethods();
    expect(updatedList.length, initialLength + 1);

    // 3. UPDATE (PATCH) - Изменение имени через Update Request DTO
    const updateRequest = UpdatePaymentMethodRequest(
      name: 'Оплата через СБП Qr',
    );
    final updatedMethod = await repository.updatePaymentMethod(
      createdMethod.id,
      updateRequest,
    );

    expect(updatedMethod.id, createdMethod.id);
    expect(updatedMethod.name, 'Оплата через СБП Qr');

    debugPrint('\n--- ОБНОВЛЕННЫЙ СПОСОБ ОПЛАТЫ ---');
    printModel(updatedMethod.toJson(), title: 'ИЗМЕНЕННЫЙ СПОСОБ ОПЛАТЫ');

    // 4. Деактивация сохраняет запись, но скрывает её из активного списка
    await repository.updatePaymentMethod(
      updatedMethod.id,
      const UpdatePaymentMethodRequest(isActive: false),
    );

    // Проверяем, что размер списка вернулся к исходному количеству
    final finalList = await repository.getAllPaymentMethods();
    expect(finalList.length, initialLength);

    // Проверяем, что удаленного ID больше нет в списке
    final hasDeletedId = finalList.any(
      (element) => element.id == updatedMethod.id,
    );
    expect(hasDeletedId, isFalse);
    expect(
      (await repository.getPaymentMethodById(updatedMethod.id)).isActive,
      isFalse,
    );
    expect(
      await repository.getAllPaymentMethods(includeDeactivated: true),
      hasLength(initialLength + 1),
    );

    debugPrint(
      '\n--- УСПЕШНОЕ УДАЛЕНИЕ СПОСОБА ОПЛАТЫ ID: ${updatedMethod.id} ---',
    );
  });
}
