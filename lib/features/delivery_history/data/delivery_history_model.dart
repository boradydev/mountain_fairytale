class HistoryItem {
  final String? itemId;
  final String productId;
  final bool isFreePrice;
  final String driverNote;
  final String productName;
  final int quantity;
  final double price;
  final double amount;
  HistoryItem.fromJson(Map<String, dynamic> json)
    : itemId = json['itemId'] as String?,
      productId = json['productId'] as String? ?? '',
      isFreePrice = json['isFreePrice'] as bool? ?? false,
      driverNote = json['driverNote'] as String? ?? '',
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
  final DateTime? createdAt;
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
      createdAt = DateTime.tryParse('${json['createdAt']}'),
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

class ClientDelivery extends HistoryPurchase {
  final HistoryDocument document;
  final String? salesRepresentativeId;
  final String? salesRepresentativeName;
  final String clientAddress;
  final String deliveryDetails;
  // ignore: use_super_parameters
  ClientDelivery.fromJson(Map<String, dynamic> json)
    : document = HistoryDocument.fromJson({
        ...json,
        'documentType': 'deliveryRouteSheet',
        'isActive': true,
        'purchasesCount': 0,
        'totalAmount': json['documentTotalAmount'],
        'matchedClients': [],
      }),
      salesRepresentativeId = json['salesRepresentativeId'] as String?,
      salesRepresentativeName = json['salesRepresentativeName'] as String?,
      clientAddress = json['clientAddress'] as String,
      deliveryDetails = json['deliveryDetails'] as String,
      super.fromJson(json);
}

class ClientDeliveryHistoryPage {
  final List<ClientDelivery> deliveries;
  final int total;
  ClientDeliveryHistoryPage.fromJson(Map<String, dynamic> json)
    : total = json['total'] as int,
      deliveries = ((json['data'] as Map)['deliveries'] as List)
          .map(
            (item) => ClientDelivery.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
}
