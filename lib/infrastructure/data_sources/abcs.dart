abstract interface class DeliveryDataSource {
  Future<List<Map<String, dynamic>>> getDeliveryDays({
    required int offset,
    required int limit,
  });

  Future<Map<String, dynamic>> getDeliveryDay(int id);
}


abstract interface class ClientDataSource {
  Future<List<Map<String, dynamic>>> getAllClients();

  Future<Map<String, dynamic>> updateCooldown(int clientId,
      String cooldownUntilIso);

  Future<Map<String, dynamic>?> checkDuplicate(String name, String address);

  // Добавляем контракт на создание клиента в источник данных
  Future<Map<String, dynamic>> createClient({
    required String name,
    required String phone,
    required String address,
    required int thresholdDays,
  });
}
