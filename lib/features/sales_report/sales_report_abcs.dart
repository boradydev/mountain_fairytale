import 'package:mountain_fairytale/features/sales_report/data/sales_report_model.dart';

abstract interface class SalesReportDataSource {
  Future<Map<String, dynamic>> getSalesReport({
    required DateTime dateFrom,
    required DateTime dateTo,
  });
}

abstract interface class SalesReportRepository {
  Future<SalesReport> getSalesReport({
    required DateTime dateFrom,
    required DateTime dateTo,
  });
}
