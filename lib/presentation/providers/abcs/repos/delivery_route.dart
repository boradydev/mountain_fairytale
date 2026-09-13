import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';

abstract interface class DeliveryRouteDataSource {
  Future<List<Map<String, dynamic>>> getAllRouteSheets();

  Future<Map<String, dynamic>> getRouteSheetById(int id);
  Future<Map<String, dynamic>> createRouteSheet(Map<String, dynamic> sheetJson);

  Future<Map<String, dynamic>> patchRouteSheet(int id,
      Map<String, dynamic> json);

  Future<void> deleteRouteSheet(int id);
}

abstract interface class DeliveryRouteRepository {
  Future<List<DeliveryRouteSheet>> getRouteSheets();

  Future<DeliveryRouteSheet> getRouteSheetById(int id);
  Future<DeliveryRouteSheet> saveRouteSheet(DeliveryRouteSheet sheet);

  Future<void> deleteRouteSheet(int id);
}
