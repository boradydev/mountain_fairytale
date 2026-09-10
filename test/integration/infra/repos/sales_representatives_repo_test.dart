import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/infra/repos/sales_representatives/models/sales_representative_model.dart';
import 'package:mountain_fairytale/infra/repos/sales_representatives/repo.dart';
import 'package:mountain_fairytale/infra/repos/sales_representatives/sources/demo_data.dart';

import '../../../assets/demo/demo_asset_bundle.dart';
import 'print_model.dart';

void main() {
  final demoBundle = DemoAssetBundle.instance;

  test('should manage sales representatives via repository (CRUD)', () async {
    final dataSource = DemoSalesRepresentativeDataSource(
      assetBundle: demoBundle,
    );
    final repository = SalesRepresentativeRepositoryImpl(dataSource);

    // 1. READ ALL - Проверка загрузки изначального списка
    final initialList = await repository.getAllSalesRepresentatives();
    expect(initialList, isNotEmpty);
    final int initialLength = initialList.length;

    print('\n--- ИСХОДНЫЕ ТОРГОВЫЕ ПРЕДСТАВИТЕЛИ ---');
    for (final rep in initialList) {
      printModel(rep.toJson(), title: 'ТОРГОВЫЙ ПРЕДСТАВИТЕЛЬ ID: ${rep.id}');
    }

    // 1.2 READ BY ID - Проверка чтения конкретного представителя по ID
    final firstId = initialList.first.id;
    final fetchedById = await repository.getSalesRepresentativeById(firstId);
    expect(fetchedById.id, firstId);

    print('\n--- ПОЛУЧЕННЫЙ ТОРГОВЫЙ ПРЕДСТАВИТЕЛЬ ПО ID: $firstId ---');
    printModel(fetchedById.toJson(), title: 'ТОРГОВЫЙ ПРЕДСТАВИТЕЛЬ ИЗ API');

    // 2. CREATE - Проверка создания нового торгового представителя через Create Request DTO
    const createRequest = CreateSalesRepresentativeRequest(
      name: 'Елена Козлова',
      phone: '+7 (905) 777-88-99',
    );
    final createdRep = await repository.createSalesRepresentative(
      createRequest,
    );

    expect(createdRep.id, isNot(0));
    expect(createdRep.name, createRequest.name);
    expect(createdRep.phone, createRequest.phone);

    print('\n--- СОЗДАННЫЙ ТОРГОВЫЙ ПРЕДСТАВИТЕЛЬ ---');
    printModel(createdRep.toJson(), title: 'НОВЫЙ ТОРГОВЫЙ');

    // Проверяем увеличение списка
    var updatedList = await repository.getAllSalesRepresentatives();
    expect(updatedList.length, initialLength + 1);

    // 3. UPDATE (PATCH) - Изменение только номера телефона через Update Request DTO (name остается null)
    const updateRequest = UpdateSalesRepresentativeRequest(
      phone: '+7 (905) 000-11-22',
    );
    final updatedRep = await repository.updateSalesRepresentative(
      createdRep.id,
      updateRequest,
    );

    expect(updatedRep.id, createdRep.id);
    expect(
      updatedRep.name,
      createdRep.name,
    ); // Имя должно остаться прежним на демо-сервере
    expect(updatedRep.phone, '+7 (905) 000-11-22');

    print('\n--- ОБНОВЛЕННЫЙ ТОРГОВЫЙ ПРЕДСТАВИТЕЛЬ ---');
    printModel(updatedRep.toJson(), title: 'ИЗМЕНЕННЫЙ ТОРГОВЫЙ');

    // 4. DELETE - Удаление созданной сущности
    await repository.deleteSalesRepresentative(updatedRep.id);

    // Проверяем уменьшение списка до исходного размера
    final finalList = await repository.getAllSalesRepresentatives();
    expect(finalList.length, initialLength);

    final hasDeletedId = finalList.any(
      (element) => element.id == updatedRep.id,
    );
    expect(hasDeletedId, isFalse);

    print(
      '\n--- УСПЕШНОЕ УДАЛЕНИЕ ТОРГОВОГО ПРЕДСТАВИТЕЛЯ ID: ${updatedRep.id} ---',
    );
  });
}
