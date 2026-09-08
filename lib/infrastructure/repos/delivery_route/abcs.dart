import 'package:mountain_fairytale/infrastructure/repos/delivery_route/models/delivery_route_sheet_model.dart';

abstract interface class DeliveryRouteRepository {
  Future<List<DeliveryRouteSheet>> getRouteSheets();

  Future<DeliveryRouteSheet> saveRouteSheet(DeliveryRouteSheet sheet);
}
