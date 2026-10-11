import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';

abstract class RoutePrintService {
  Future<void> printRouteSheet(DeliveryRouteSheet sheet);
}
