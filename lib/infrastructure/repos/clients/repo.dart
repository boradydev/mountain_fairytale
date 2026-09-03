import 'package:mountain_fairytale/infrastructure/data_sources/abcs.dart';
import 'package:mountain_fairytale/infrastructure/repos/clients/abcs.dart';
import 'package:mountain_fairytale/infrastructure/repos/clients/models/client_model.dart';

class ClientRepositoryImpl implements ClientRepository {
  final ClientDataSource dataSource;

  ClientRepositoryImpl(this.dataSource);

  @override
  Future<List<Client>> getAllClients() async {
    final jsonList = await dataSource.getAllClients();
    return jsonList.map(Client.fromJson).toList();
  }

  @override
  Future<Client> updateCooldown(int clientId, DateTime cooldownUntil) async {
    // Переводим DateTime в ISO-строку, так как HTTP-клиенты/JSON работают со строками
    final String isoDate = cooldownUntil.toIso8601String();

    // Отправляем запрос в DataSource
    final updatedJson = await dataSource.updateCooldown(clientId, isoDate);

    // Маппим результат обратно в строго типизированную модель
    return Client.fromJson(updatedJson);
  }
}
