import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';

abstract interface class DeliveryRouteDataSource {
  Future<List<Map<String, dynamic>>> getAllRouteSheets();

  Future<Map<String, dynamic>> createRouteSheet(Map<String, dynamic> sheetJson);
}

abstract interface class DeliveryRouteRepository {
  Future<List<DeliveryRouteSheet>> getRouteSheets();

  Future<DeliveryRouteSheet> saveRouteSheet(DeliveryRouteSheet sheet);
}
