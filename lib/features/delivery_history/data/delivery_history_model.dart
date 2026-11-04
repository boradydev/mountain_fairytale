class HistoryItem {
  final String driverNote;
  final String productName;
  final int quantity;
  final double price;
  final double amount;
  HistoryItem.fromJson(Map<String, dynamic> json)
    : driverNote = json['driverNote'] as String? ?? '',
      productName = json['productName'] as String,
      quantity = json['quantity'] as int,
      price = double.parse('${json['price']}'),
      amount = double.parse('${json['amount']}');
}

class HistoryPurchase {
  final bool isDelivered;
  final String nonDeliveryReason;
  final String memo;
  final String pointId;
  final String clientId;
  final String clientName;
  final String address;
  final String phone;
  final String? paymentMethodName;
  final double totalAmount;
  final List<HistoryItem> items;
  HistoryPurchase.fromJson(Map<String, dynamic> json)
    : isDelivered = json['isDelivered'] as bool? ?? true,
      nonDeliveryReason = json['nonDeliveryReason'] as String? ?? '',
      memo = json['memo'] as String? ?? '',
      pointId = json['pointId'] as String,
      clientId = json['clientId'] as String,
      clientName = json['clientName'] as String,
      address = json['address'] as String,
      phone = json['phone'] as String,
      paymentMethodName = json['paymentMethodName'] as String?,
      totalAmount = double.parse('${json['totalAmount']}'),
      items = (json['items'] as List)
          .map((item) => HistoryItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
}

class HistoryDocument {
  final String id;
  final bool isPickup;
  final DateTime plannedDate;
  final bool isActive;
  final String? driverName;
  final String? carModelAndNumber;
  final int clientsCount;
  final int purchasesCount;
  final double totalAmount;
  final List<HistoryPurchase> matchedClients;
  HistoryDocument.fromJson(Map<String, dynamic> json)
    : id = json['deliveryDocumentId'] as String,
      isPickup = json['documentType'] == 'pickupSheet',
      plannedDate = DateTime.parse(json['plannedDate'] as String),
      isActive = json['isActive'] as bool,
      driverName = json['driverName'] as String?,
      carModelAndNumber = json['carModelAndNumber'] as String?,
      clientsCount = json['clientsCount'] as int,
      purchasesCount = json['purchasesCount'] as int,
      totalAmount = double.parse('${json['totalAmount']}'),
      matchedClients = (json['matchedClients'] as List)
          .map(
            (item) => HistoryPurchase.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
}

class DeliveryHistoryPage {
  final List<HistoryDocument> documents;
  final int total;
  const DeliveryHistoryPage({required this.documents, required this.total});
  factory DeliveryHistoryPage.fromJson(Map<String, dynamic> json) =>
      DeliveryHistoryPage(
        total: json['total'] as int,
        documents: ((json['data'] as Map)['documents'] as List)
            .map(
              (item) =>
                  HistoryDocument.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
      );
}
