import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/infra/repos/payment_methods/models/payment_method_model.dart';
import 'package:mountain_fairytale/infra/repos/payment_methods/repo.dart';
import 'package:mountain_fairytale/infra/repos/payment_methods/sources/demo_data.dart';

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

    print('\n--- ИСХОДНЫЕ СПОСОБЫ ОПЛАТЫ ---');
    for (final method in initialList) {
      printModel(method.toJson(), title: 'СПОСОБ ОПЛАТЫ ID: ${method.id}');
    }

    // 1.2 READ BY ID - Проверка чтения конкретного элемента по ID
    final firstId = initialList.first.id;
    final fetchedById = await repository.getPaymentMethodById(firstId);
    expect(fetchedById.id, firstId);

    print('\n--- ПОЛУЧЕННЫЙ СПОСОБ ОПЛАТЫ ПО ID: $firstId ---');
    printModel(fetchedById.toJson(), title: 'СПОСОБ ОПЛАТЫ ИЗ API');

    // 2. CREATE - Проверка создания нового способа оплаты через Create Request DTO
    const createRequest = CreatePaymentMethodRequest(
      name: 'СБП (Система быстрых платежей)',
    );
    final createdMethod = await repository.createPaymentMethod(createRequest);

    expect(createdMethod.id, isNot(0));
    expect(createdMethod.name, createRequest.name);

    print('\n--- СОЗДАННЫЙ СПОСОБ ОПЛАТЫ ---');
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

    print('\n--- ОБНОВЛЕННЫЙ СПОСОБ ОПЛАТЫ ---');
    printModel(updatedMethod.toJson(), title: 'ИЗМЕНЕННЫЙ СПОСОБ ОПЛАТЫ');

    // 4. DELETE - Удаление созданной сущности
    await repository.deletePaymentMethod(updatedMethod.id);

    // Проверяем, что размер списка вернулся к исходному количеству
    final finalList = await repository.getAllPaymentMethods();
    expect(finalList.length, initialLength);

    // Проверяем, что удаленного ID больше нет в списке
    final hasDeletedId = finalList.any(
      (element) => element.id == updatedMethod.id,
    );
    expect(hasDeletedId, isFalse);

    print('\n--- УСПЕШНОЕ УДАЛЕНИЕ СПОСОБА ОПЛАТЫ ID: ${updatedMethod.id} ---');
  });
}
