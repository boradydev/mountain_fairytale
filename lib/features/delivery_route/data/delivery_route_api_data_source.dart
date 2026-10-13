import 'package:mountain_fairytale/features/delivery_route/data/delivery_document_api.dart';
import 'package:mountain_fairytale/features/delivery_route/delivery_route_abcs.dart';

class ApiDeliveryRouteDataSource extends ApiDeliveryDocumentDataSource
    implements DeliveryRouteDataSource {
  ApiDeliveryRouteDataSource(super.client)
    : super(
        path: '/protected/delivery-route-sheets',
        listKey: 'deliveryRouteSheets',
      );
}
