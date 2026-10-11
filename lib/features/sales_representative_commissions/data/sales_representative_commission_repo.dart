import 'package:mountain_fairytale/features/sales_representative_commissions/data/sales_representative_commission_model.dart';
import 'package:mountain_fairytale/features/sales_representative_commissions/sales_representative_commission_abcs.dart';

class SalesRepresentativeCommissionRepositoryImpl
    implements SalesRepresentativeCommissionRepository {
  final SalesRepresentativeCommissionDataSource dataSource;

  SalesRepresentativeCommissionRepositoryImpl(this.dataSource);

  @override
  Future<SalesRepresentativeCommissionReport>
  getSalesRepresentativeCommissions({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final json = await dataSource.getSalesRepresentativeCommissions(
      dateFrom: _formatDate(dateFrom),
      dateTo: _formatDate(dateTo),
    );

    return SalesRepresentativeCommissionReport.fromJson(json);
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
