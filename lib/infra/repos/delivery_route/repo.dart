import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/delivery_route.dart';

class DeliveryRouteRepositoryImpl implements DeliveryRouteRepository {
  final DeliveryRouteDataSource dataSource;

  DeliveryRouteRepositoryImpl(this.dataSource);

  @override
  Future<List<DeliveryRouteSheet>> getRouteSheets() async {
    final list = await dataSource.getAllRouteSheets();
    return list.map(DeliveryRouteSheet.fromJson).toList();
  }

  @override
  Future<DeliveryRouteSheet> getRouteSheetById(int id) async {
    final json = await dataSource.getRouteSheetById(id);
    return DeliveryRouteSheet.fromJson(json);
  }

  @override
  Future<DeliveryRouteSheet> saveRouteSheet(DeliveryRouteSheet sheet) async {
    final jsonToSend = sheet.toJson();
    if (sheet.id != null) {
      // Маршрут уже существует -> Обновляем (PATCH)
      final updatedJson = await dataSource.patchRouteSheet(
          sheet.id!, jsonToSend);
      return DeliveryRouteSheet.fromJson(updatedJson);
    } else {
      // Маршрута еще нет -> Создаем (POST)
      final savedJson = await dataSource.createRouteSheet(jsonToSend);
      return DeliveryRouteSheet.fromJson(savedJson);
    }
  }

  @override
  Future<void> deleteRouteSheet(int id) async {
    await dataSource.deleteRouteSheet(id);
  }
}
