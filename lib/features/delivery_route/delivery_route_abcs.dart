import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_document_api.dart';

abstract interface class DeliveryRouteDataSource
    implements DeliveryDocumentDataSource {}

abstract interface class DeliveryRouteRepository
    implements DocumentLockRepository {
  Future<List<DeliveryRouteSheet>> getRouteSheets({
    bool includeCancelled = false,
  });
  Future<DeliveryRouteSheet> getRouteSheetById(String id);
  Future<DeliveryRouteSheet> saveRouteSheet(DeliveryRouteSheet sheet);
  Future<DeliveryRouteSheet> cancelRouteSheet(String id);
  Future<DeliveryRouteSheet> restoreRouteSheet(String id);
}

abstract class RoutePrintService {
  Future<void> printRouteSheet(DeliveryRouteSheet sheet);
}
