abstract interface class DeliveryDataSource {
  Future<List<Map<String, dynamic>>> getDeliveryDays({
    required int offset,
    required int limit,
  });

  Future<Map<String, dynamic>> getDeliveryDay(int id);
}

abstract interface class ClientDataSource {
  Future<List<Map<String, dynamic>>> getAllClients();
}
