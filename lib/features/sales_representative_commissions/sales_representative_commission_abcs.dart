import 'package:mountain_fairytale/features/sales_representative_commissions/data/sales_representative_commission_model.dart';

abstract interface class SalesRepresentativeCommissionDataSource {
  Future<Map<String, dynamic>> getSalesRepresentativeCommissions({
    required String dateFrom,
    required String dateTo,
  });
}

abstract interface class SalesRepresentativeCommissionRepository {
  Future<SalesRepresentativeCommissionReport>
  getSalesRepresentativeCommissions({
    required DateTime dateFrom,
    required DateTime dateTo,
  });
}
