import 'package:mountain_fairytale/infrastructure/data_sources/abcs.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_route/models/delivery_route_sheet_model.dart';

class DeliveryRouteRepository {
  final DeliveryRouteDataSource dataSource;

  DeliveryRouteRepository(this.dataSource);

  Future<List<DeliveryRouteSheet>> getRouteSheets() async {
    final list = await dataSource.getAllRouteSheets();
    return list.map(DeliveryRouteSheet.fromJson).toList();
  }

  Future<DeliveryRouteSheet> saveRouteSheet(DeliveryRouteSheet sheet) async {
    // Переводим строго типизированную модель конструктора обратно в JSON
    final jsonToSend = sheet.toJson();

    // Отправляем в источник данных
    final savedJson = await dataSource.createRouteSheet(jsonToSend);

    // Возвращаем модель с присвоенным ID
    return DeliveryRouteSheet.fromJson(savedJson);
  }
}
