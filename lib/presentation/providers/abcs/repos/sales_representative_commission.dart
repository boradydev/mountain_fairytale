import 'package:mountain_fairytale/infra/repos/sales_representative_commissions/models/sales_representative_commission_model.dart';

abstract interface class SalesRepresentativeCommissionDataSource {
  Future<List<Map<String, dynamic>>> getSalesRepresentativeCommissions({
    required String dateFrom,
    required String dateTo,
  });
}

abstract interface class SalesRepresentativeCommissionRepository {
  Future<List<SalesRepresentativeCommission>>
  getSalesRepresentativeCommissions({
    required DateTime dateFrom,
    required DateTime dateTo,
  });
}
