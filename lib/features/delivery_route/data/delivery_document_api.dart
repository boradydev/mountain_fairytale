import 'package:mountain_fairytale/core/network/api_client.dart';

abstract interface class DocumentLockRepository {
  Future<void> checkConnection();
  Future<String> acquireEditLock(String id);
  Future<String> renewEditLock(String id);
  Future<void> releaseEditLock(String id);
}

abstract interface class DeliveryDocumentDataSource
    implements DocumentLockRepository {
  Future<List<Map<String, dynamic>>> getAll({bool includeCancelled = false});
  Future<Map<String, dynamic>> getById(String id);
  Future<Map<String, dynamic>> findCreated(String requestId);
  Future<Map<String, dynamic>> create(Map<String, dynamic> json);
  Future<Map<String, dynamic>> patch(String id, Map<String, dynamic> json);
  Future<Map<String, dynamic>> setActive(String id, bool active);
}

class ApiDeliveryDocumentDataSource implements DeliveryDocumentDataSource {
  final ApiClient client;
  final String path;
  final String listKey;
  ApiDeliveryDocumentDataSource(
    this.client, {
    required this.path,
    required this.listKey,
  });
  @override
  Future<void> checkConnection() async {
    await client.get('/health/ready');
  }

  Map<String, dynamic> _data(Map<String, dynamic> response) =>
      Map<String, dynamic>.from(response['data'] as Map);
  @override
  Future<List<Map<String, dynamic>>> getAll({
    bool includeCancelled = false,
  }) async {
    final documents = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final response = await client.get(
        '$path?include_cancelled=$includeCancelled&offset=$offset&limit=100',
      );
      final page = (_data(response)[listKey] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      documents.addAll(page);
      offset += page.length;
      final total = (response['total'] as num).toInt();
      if (page.isEmpty || offset >= total) return documents;
    }
  }

  @override
  Future<Map<String, dynamic>> getById(String id) async =>
      _data(await client.get('$path/$id'));
  @override
  Future<Map<String, dynamic>> findCreated(String requestId) async =>
      _data(await client.get('$path/creation-requests/$requestId'));
  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> json) async =>
      _data(await client.post('$path/create', body: json));
  @override
  Future<Map<String, dynamic>> patch(
    String id,
    Map<String, dynamic> json,
  ) async => _data(await client.patch('$path/$id', body: json));
  @override
  Future<Map<String, dynamic>> setActive(String id, bool active) async =>
      _data(await client.post('$path/$id/${active ? 'restore' : 'cancel'}'));
  @override
  Future<String> acquireEditLock(String id) async =>
      _data(await client.post('$path/$id/edit-lock'))['ownerName'] as String;
  @override
  Future<String> renewEditLock(String id) async =>
      _data(await client.patch('$path/$id/edit-lock'))['ownerName'] as String;
  @override
  Future<void> releaseEditLock(String id) async {
    await client.delete('$path/$id/edit-lock');
  }
}
