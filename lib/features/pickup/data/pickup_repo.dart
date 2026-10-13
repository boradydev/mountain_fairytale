import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';
import 'package:mountain_fairytale/features/pickup/pickup_abcs.dart';

class PickupRepositoryImpl implements PickupRepository {
  final PickupDataSource dataSource;
  PickupRepositoryImpl(this.dataSource);
  @override
  Future<List<PickupSheet>> getPickupSheets({
    bool includeCancelled = false,
  }) async =>
      (await dataSource.getAll(includeCancelled: includeCancelled))
          .map(PickupSheet.fromJson)
          .toList();
  @override
  Future<PickupSheet> getPickupSheetById(String id) async =>
      PickupSheet.fromJson(await dataSource.getById(id));
  @override
  Future<PickupSheet> savePickupSheet(PickupSheet sheet) async {
    final request = sheet.toRequestJson();
    final json = sheet.id == null
        ? await dataSource.create(request)
        : await dataSource.patch(sheet.id!, request);
    return PickupSheet.fromJson(json);
  }

  @override
  Future<PickupSheet> cancelPickupSheet(String id) async =>
      PickupSheet.fromJson(await dataSource.setActive(id, false));
  @override
  Future<PickupSheet> restorePickupSheet(String id) async =>
      PickupSheet.fromJson(await dataSource.setActive(id, true));
  @override
  Future<String> acquireEditLock(String id) => dataSource.acquireEditLock(id);
  @override
  Future<String> renewEditLock(String id) => dataSource.renewEditLock(id);
  @override
  Future<void> releaseEditLock(String id) => dataSource.releaseEditLock(id);
}
