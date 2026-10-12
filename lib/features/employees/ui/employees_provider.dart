import 'package:flutter/foundation.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/features/employees/data/employee_model.dart';
import 'package:mountain_fairytale/features/employees/employees_abcs.dart';

class EmployeesProvider extends ChangeNotifier {
  final EmployeeRepository _repository;

  EmployeesProvider(this._repository);

  List<Employee> _employees = const [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _usernameError;
  bool _disposed = false;

  List<Employee> get employees => _employees;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get usernameError => _usernameError;

  Future<void> loadEmployees() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      // Load deactivated usernames too: they remain unique and unavailable.
      _employees = await _repository.getEmployees(includeDeactivated: true);
    } catch (error) {
      _errorMessage = _friendlyMessage(
        error,
        fallback: 'Не удалось загрузить сотрудников.',
      );
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<Employee?> createEmployee(CreateEmployeeRequest request) async {
    _errorMessage = null;
    _usernameError = null;
    try {
      final employee = await _repository.createEmployee(request);
      _upsert(employee);
      return employee;
    } catch (error) {
      if (error is ApiException && error.statusCode == 409) {
        _usernameError = 'Такой логин уже существует.';
      } else {
        _errorMessage = _friendlyMessage(
          error,
          fallback: 'Не удалось создать сотрудника.',
        );
      }
      _notify();
      return null;
    }
  }

  Future<Employee?> updateEmployee(
    String id,
    UpdateEmployeeRequest request,
  ) async {
    _errorMessage = null;
    _usernameError = null;
    try {
      final employee = await _repository.updateEmployee(id, request);
      _upsert(employee);
      return employee;
    } catch (error) {
      if (error is ApiException && error.statusCode == 409) {
        _usernameError = 'Такой логин уже существует.';
      } else {
        _errorMessage = _friendlyMessage(
          error,
          fallback: 'Не удалось сохранить сотрудника.',
        );
      }
      _notify();
      return null;
    }
  }

  Future<bool> changePassword(String id, String password) async {
    _errorMessage = null;
    try {
      await _repository.changePassword(id, password);
      return true;
    } catch (error) {
      _errorMessage = _friendlyMessage(
        error,
        fallback: 'Не удалось изменить пароль.',
      );
      _notify();
      return false;
    }
  }

  void clearUsernameError() {
    if (_usernameError == null) return;
    _usernameError = null;
    _notify();
  }

  void clearError() {
    if (_errorMessage == null && _usernameError == null) return;
    _errorMessage = null;
    _usernameError = null;
    _notify();
  }

  void _upsert(Employee employee) {
    final index = _employees.indexWhere((item) => item.id == employee.id);
    if (index == -1) {
      _employees = [employee, ..._employees];
    } else {
      final next = [..._employees];
      next[index] = employee;
      _employees = next;
    }
    _notify();
  }

  String _friendlyMessage(Object error, {required String fallback}) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        401 => 'Сессия завершена. Войдите снова.',
        403 => 'Управлять сотрудниками может только администратор.',
        404 => 'Сотрудник не найден. Обновите список.',
        422 => 'Проверьте введённые данные.',
        _ => fallback,
      };
    }
    return fallback;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
