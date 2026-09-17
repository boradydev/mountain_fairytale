import 'package:mountain_fairytale/infra/repos/pickup/models/pickup_sheet_model.dart';

abstract class PickupDataSource {
  Future<List<Map<String, dynamic>>> getAllPickupSheets();

  Future<Map<String, dynamic>> getPickupSheetById(int id);

  Future<Map<String, dynamic>> createPickupSheet(
    Map<String, dynamic> sheetJson,
  );

  Future<Map<String, dynamic>> patchPickupSheet(
    int id,
    Map<String, dynamic> json,
  );

  Future<void> deletePickupSheet(int id);
}

abstract class PickupRepository {
  Future<List<PickupSheet>> getPickupSheets();

  Future<PickupSheet> getPickupSheetById(int id);

  Future<PickupSheet> savePickupSheet(PickupSheet sheet);

  Future<void> deletePickupSheet(int id);
}
