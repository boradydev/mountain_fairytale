abstract interface class DeliveryDataSource {
  Future<List<Map<String, dynamic>>> getDeliveryDays();

  Future<Map<String, dynamic>> getDeliveryDay(int id);
}
