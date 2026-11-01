import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/sales_report/sales_report_abcs.dart';

class ApiSalesReportDataSource implements SalesReportDataSource {
  final ApiClient client;

  ApiSalesReportDataSource(this.client);

  @override
  Future<Map<String, dynamic>> getSalesReport({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) => client.get(
    Uri(
      path: '/protected/sales-report',
      queryParameters: {
        'date_from': _date(dateFrom),
        'date_to': _date(dateTo),
      },
    ).toString(),
  );

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
