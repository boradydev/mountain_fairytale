import 'package:mountain_fairytale/infra/repos/abcs.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';

class DeliveryRouteRepositoryImpl implements DeliveryRouteRepository {
  final DeliveryRouteDataSource dataSource;

  DeliveryRouteRepositoryImpl(this.dataSource);

  @override
  Future<List<DeliveryRouteSheet>> getRouteSheets() async {
    final list = await dataSource.getAllRouteSheets();
    return list.map(DeliveryRouteSheet.fromJson).toList();
  }

  @override
  Future<DeliveryRouteSheet> saveRouteSheet(DeliveryRouteSheet sheet) async {
    final jsonToSend = sheet.toJson();
    final savedJson = await dataSource.createRouteSheet(jsonToSend);
    return DeliveryRouteSheet.fromJson(savedJson);
  }
}
