import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_document_api.dart';

abstract interface class PickupDataSource
    implements DeliveryDocumentDataSource {}

abstract interface class PickupRepository implements DocumentLockRepository {
  Future<List<PickupSheet>> getPickupSheets({bool includeCancelled = false});
  Future<PickupSheet> getPickupSheetById(String id);
  Future<PickupSheet> findCreatedPickup(String requestId);
  Future<PickupSheet> savePickupSheet(PickupSheet sheet);
  Future<PickupSheet> cancelPickupSheet(String id);
  Future<PickupSheet> restorePickupSheet(String id);
}
