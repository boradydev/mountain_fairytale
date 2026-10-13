import 'package:mountain_fairytale/features/delivery_route/data/delivery_document_api.dart';
import 'package:mountain_fairytale/features/pickup/pickup_abcs.dart';

class ApiPickupDataSource extends ApiDeliveryDocumentDataSource
    implements PickupDataSource {
  ApiPickupDataSource(super.client)
    : super(path: '/protected/pickup-sheets', listKey: 'pickupSheets');
}
