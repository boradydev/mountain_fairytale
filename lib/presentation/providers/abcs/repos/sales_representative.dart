import 'package:mountain_fairytale/infra/repos/sales_representatives/models/sales_representative_model.dart';

abstract interface class SalesRepresentativeDataSource {
  Future<List<Map<String, dynamic>>> getAllSalesRepresentatives();

  Future<Map<String, dynamic>> getSalesRepresentativeById(int id);

  Future<Map<String, dynamic>> createSalesRepresentative(
    Map<String, dynamic> json,
  );

  Future<Map<String, dynamic>> patchSalesRepresentative(
    int id,
    Map<String, dynamic> json,
  );

  Future<void> deleteSalesRepresentative(int id);
}

abstract interface class SalesRepresentativeRepository {
  Future<List<SalesRepresentative>> getAllSalesRepresentatives();

  Future<SalesRepresentative> getSalesRepresentativeById(int id);

  Future<SalesRepresentative> createSalesRepresentative(
    CreateSalesRepresentativeRequest request,
  );

  Future<SalesRepresentative> updateSalesRepresentative(
    int id,
    UpdateSalesRepresentativeRequest request,
  );

  Future<void> deleteSalesRepresentative(int id);
}
