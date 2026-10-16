import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/employees/data/employee_model.dart';
import 'package:mountain_fairytale/features/employees/data/employees_api_data_source.dart';
import 'package:mountain_fairytale/features/employees/data/employees_repo.dart';

import '../auth/auth_fakes.dart';
import '../clients/clients_api_test.dart' show ClientTransport;

void main() {
  test(
    'employee API preserves null, zero and omitted rates across requests',
    () async {
      final transport = ClientTransport();
      final auth = AuthServiceImpl(
        repository: FakeAuthRepository(),
        tokenStorage: MemoryTokenStorage(),
      );
      await auth.login(username: 'manager', password: '');
      addTearDown(transport.close);
      addTearDown(auth.dispose);
      final repo = EmployeeRepositoryImpl(
        ApiEmployeeDataSource(
          ApiClient(transport: transport, authService: auth, userAgent: 'test'),
        ),
      );
      final record = <String, dynamic>{
        'employeeId': 'employee-uuid',
        'username': 'director',
        'role': 'admin',
        'commissionPercent': null,
        'isActive': true,
        'createdAt': '2026-10-16T12:00:00',
      };
      transport.respond = (_) async => envelope(record);
      final created = await repo.createEmployee(
        const CreateEmployeeRequest(username: 'director', password: ''),
      );
      expect(created.commissionPercent, isNull);
      expect(transport.requests.last.body, {
        'username': 'director',
        'password': '',
        'commissionPercent': null,
      });

      await repo.updateEmployee(
        created.id,
        const UpdateEmployeeRequest(isActive: true),
      );
      expect(transport.requests.last.body, {'isActive': true});
      record['commissionPercent'] = 0;
      final zero = await repo.updateEmployee(
        created.id,
        const UpdateEmployeeRequest(commissionPercent: 0),
      );
      expect(zero.commissionPercent, 0);
      expect(transport.requests.last.body, {'commissionPercent': 0});
      record['commissionPercent'] = null;
      final cleared = await repo.updateEmployee(
        created.id,
        const UpdateEmployeeRequest(clearCommissionPercent: true),
      );
      expect(cleared.commissionPercent, isNull);
      expect(transport.requests.last.method, 'PATCH');
      expect(transport.requests.last.path, '/admin/employees/employee-uuid');
      expect(transport.requests.last.body, {'commissionPercent': null});
    },
  );
}
