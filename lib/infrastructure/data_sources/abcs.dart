abstract interface class DeliveryDataSource {
  Future<List<Map<String, dynamic>>> getDeliveryDays({
    required int offset,
    required int limit,
  });

  Future<Map<String, dynamic>> getDeliveryDay(int id);
}

abstract interface class ClientDataSource {
  Future<List<Map<String, dynamic>>> getAllClients();

  // Добавляем метод обновления в контракт источника данных
  Future<Map<String, dynamic>> updateCooldown(int clientId,
      String cooldownUntilIso);
}

