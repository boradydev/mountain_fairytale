import 'package:mountain_fairytale/features/sales_report/data/sales_report_model.dart';
import 'package:mountain_fairytale/features/sales_report/sales_report_abcs.dart';

class SalesReportRepositoryImpl implements SalesReportRepository {
  final SalesReportDataSource _dataSource;

  SalesReportRepositoryImpl(this._dataSource);

  @override
  Future<SalesReport> getSalesReport({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final response = await _dataSource.getSalesReport(
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    return SalesReport.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }
}
