import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_api_repo.dart';

import '../auth/auth_fakes.dart';
import 'clients_api_test.dart' show ClientTransport;

void main() {
  test('representative dialog repository uses UUIDs, envelopes and two-field duplicate query', () async {
    final transport = ClientTransport();
    final auth = AuthServiceImpl(
      repository: FakeAuthRepository(),
      tokenStorage: MemoryTokenStorage(),
    );
    await auth.login(username: 'manager', password: '');
    addTearDown(transport.close);
    addTearDown(auth.dispose);
    final repo = SalesRepresentativeApiRepository(
      ApiClient(transport: transport, authService: auth, userAgent: 'test'),
    );
    final record = {
      'salesRepresentativeId': 'rep-uuid',
      'name': 'Иван',
      'phone': '+79123456789',
      'commissionPercent': 12.5,
      'isActive': true,
    };
    transport.respond = (_) async => envelope(record);
    final created = await repo.create(
      name: 'Иван',
      phone: '+79123456789',
      commissionPercent: 12.5,
    );
    expect(created.id, 'rep-uuid');
    expect(
      transport.requests.last.path,
      '/protected/sales-representatives/create',
    );
    expect(transport.requests.last.body, {
      'name': 'Иван',
      'phone': '+79123456789',
      'commissionPercent': 12.5,
    });
    await repo.get(created.id);
    expect(
      transport.requests.last.path,
      '/protected/sales-representatives/rep-uuid',
    );
    await repo.update(created.id, {'isActive': false});
    expect(transport.requests.last.method, 'PATCH');
    expect(transport.requests.last.body, {'isActive': false});
    await repo.checkDuplicate('Иван & Co', '+79123456789');
    expect(Uri.parse(transport.requests.last.path).queryParameters, {
      'name': 'Иван & Co',
      'phone': '+79123456789',
    });
    transport.respond = (_) async => envelope(null);
    expect(await repo.checkDuplicate('Иван', '+79123456789'), isNull);
  });
}
