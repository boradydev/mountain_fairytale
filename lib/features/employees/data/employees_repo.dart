import 'package:mountain_fairytale/features/employees/data/employee_model.dart';
import 'package:mountain_fairytale/features/employees/employees_abcs.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  final EmployeeDataSource dataSource;

  EmployeeRepositoryImpl(this.dataSource);

  @override
  Future<List<Employee>> getEmployees({bool includeDeactivated = false}) async {
    final json = await dataSource.getEmployees(
      includeDeactivated: includeDeactivated,
    );
    return json.map(Employee.fromJson).toList();
  }

  @override
  Future<Employee> createEmployee(CreateEmployeeRequest request) async =>
      Employee.fromJson(await dataSource.createEmployee(request.toJson()));

  @override
  Future<Employee> updateEmployee(
    String id,
    UpdateEmployeeRequest request,
  ) async => Employee.fromJson(
    await dataSource.updateEmployee(id, request.toJson()),
  );

  @override
  Future<void> changePassword(String id, String password) =>
      dataSource.changePassword(id, password);
}
