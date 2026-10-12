import 'package:mountain_fairytale/features/employees/data/employee_model.dart';

abstract interface class EmployeeDataSource {
  Future<List<Map<String, dynamic>>> getEmployees({
    bool includeDeactivated = false,
  });
  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> json);
  Future<Map<String, dynamic>> updateEmployee(
    String id,
    Map<String, dynamic> json,
  );
  Future<void> changePassword(String id, String password);
}

abstract interface class EmployeeRepository {
  Future<List<Employee>> getEmployees({bool includeDeactivated = false});
  Future<Employee> createEmployee(CreateEmployeeRequest request);
  Future<Employee> updateEmployee(String id, UpdateEmployeeRequest request);
  Future<void> changePassword(String id, String password);
}
