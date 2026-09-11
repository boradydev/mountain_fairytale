import 'package:mountain_fairytale/infra/repos/sales_representatives/models/sales_representative_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/sales_representative.dart';

class SalesRepresentativeRepositoryImpl
    implements SalesRepresentativeRepository {
  final SalesRepresentativeDataSource dataSource;

  SalesRepresentativeRepositoryImpl(this.dataSource);

  @override
  Future<List<SalesRepresentative>> getAllSalesRepresentatives() async {
    final list = await dataSource.getAllSalesRepresentatives();
    return list.map(SalesRepresentative.fromJson).toList();
  }

  @override
  Future<SalesRepresentative> getSalesRepresentativeById(int id) async {
    final json = await dataSource.getSalesRepresentativeById(id);
    return SalesRepresentative.fromJson(json);
  }

  @override
  Future<SalesRepresentative> createSalesRepresentative(
    CreateSalesRepresentativeRequest request,
  ) async {
    final json = await dataSource.createSalesRepresentative(request.toJson());
    return SalesRepresentative.fromJson(json);
  }

  @override
  Future<SalesRepresentative> updateSalesRepresentative(
    int id,
    UpdateSalesRepresentativeRequest request,
  ) async {
    final json = await dataSource.patchSalesRepresentative(
      id,
      request.toJson(),
    );
    return SalesRepresentative.fromJson(json);
  }

  @override
  Future<void> deleteSalesRepresentative(int id) async {
    await dataSource.deleteSalesRepresentative(id);
  }

  @override
  Future<SalesRepresentative?> checkDuplicate(String name) async {
    final json = await dataSource.checkDuplicate(name);
    if (json == null) return null;
    return SalesRepresentative.fromJson(json);
  }
}
