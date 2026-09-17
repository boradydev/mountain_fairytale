import 'package:mountain_fairytale/infra/repos/pickup/models/pickup_sheet_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/pickup.dart';

class PickupRepositoryImpl implements PickupRepository {
  final PickupDataSource dataSource;

  PickupRepositoryImpl(this.dataSource);

  @override
  Future<List<PickupSheet>> getPickupSheets() async {
    final list = await dataSource.getAllPickupSheets();

    return list.map(PickupSheet.fromJson).toList();
  }

  @override
  Future<PickupSheet> getPickupSheetById(int id) async {
    final json = await dataSource.getPickupSheetById(id);

    return PickupSheet.fromJson(json);
  }

  @override
  Future<PickupSheet> savePickupSheet(PickupSheet sheet) async {
    final jsonToSend = sheet.toJson();

    if (sheet.id != null) {
      final updatedJson = await dataSource.patchPickupSheet(
        sheet.id!,
        jsonToSend,
      );

      return PickupSheet.fromJson(updatedJson);
    }

    final savedJson = await dataSource.createPickupSheet(jsonToSend);

    return PickupSheet.fromJson(savedJson);
  }

  @override
  Future<void> deletePickupSheet(int id) async {
    await dataSource.deletePickupSheet(id);
  }
}
