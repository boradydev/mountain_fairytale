import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/employees/employees_abcs.dart';

class ApiEmployeeDataSource implements EmployeeDataSource {
  final ApiClient client;

  ApiEmployeeDataSource(this.client);

  static const _path = '/admin/employees';

  Map<String, dynamic> _employee(Map<String, dynamic> response) =>
      Map<String, dynamic>.from(response['data'] as Map);

  @override
  Future<List<Map<String, dynamic>>> getEmployees({
    bool includeDeactivated = false,
  }) async {
    final response = await client.get(
      '$_path?include_deactivated=$includeDeactivated',
    );
    return ((response['data'] as Map)['employees'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> createEmployee(
    Map<String, dynamic> json,
  ) async => _employee(await client.post('$_path/create', body: json));

  @override
  Future<Map<String, dynamic>> updateEmployee(
    String id,
    Map<String, dynamic> json,
  ) async => _employee(await client.patch('$_path/$id', body: json));

  @override
  Future<void> changePassword(String id, String password) async {
    await client.put(
      '$_path/$id/change-password',
      body: {'password': password},
    );
  }
}
