import 'package:mountain_fairytale/infrastructure/data_sources/abcs.dart';
import 'package:mountain_fairytale/infrastructure/repos/clients/abcs.dart';
import 'package:mountain_fairytale/infrastructure/repos/clients/models/client_model.dart';

class ClientRepositoryImpl implements ClientRepository {
  final ClientDataSource dataSource;

  ClientRepositoryImpl(this.dataSource);

  @override
  Future<List<Client>> getAllClients() async {
    final json = await dataSource.getAllClients();

    return json.map(Client.fromJson).toList();
  }
}
