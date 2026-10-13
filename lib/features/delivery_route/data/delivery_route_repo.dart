import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/delivery_route/delivery_route_abcs.dart';

class DeliveryRouteRepositoryImpl implements DeliveryRouteRepository {
  final DeliveryRouteDataSource dataSource;
  DeliveryRouteRepositoryImpl(this.dataSource);
  @override
  Future<List<DeliveryRouteSheet>> getRouteSheets({
    bool includeCancelled = false,
  }) async =>
      (await dataSource.getAll(includeCancelled: includeCancelled))
          .map(DeliveryRouteSheet.fromJson)
          .toList();
  @override
  Future<DeliveryRouteSheet> getRouteSheetById(String id) async =>
      DeliveryRouteSheet.fromJson(await dataSource.getById(id));
  @override
  Future<DeliveryRouteSheet> saveRouteSheet(DeliveryRouteSheet sheet) async {
    final request = sheet.toRequestJson();
    final json = sheet.id == null
        ? await dataSource.create(request)
        : await dataSource.patch(sheet.id!, request);
    return DeliveryRouteSheet.fromJson(json);
  }

  @override
  Future<DeliveryRouteSheet> cancelRouteSheet(String id) async =>
      DeliveryRouteSheet.fromJson(await dataSource.setActive(id, false));
  @override
  Future<DeliveryRouteSheet> restoreRouteSheet(String id) async =>
      DeliveryRouteSheet.fromJson(await dataSource.setActive(id, true));
  @override
  Future<String> acquireEditLock(String id) => dataSource.acquireEditLock(id);
  @override
  Future<String> renewEditLock(String id) => dataSource.renewEditLock(id);
  @override
  Future<void> releaseEditLock(String id) => dataSource.releaseEditLock(id);
}
