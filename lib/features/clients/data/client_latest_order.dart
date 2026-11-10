import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';

class ClientLatestOrder {
  final String deliveryDocumentId;
  final String pointId;
  final DateTime createdAt;
  final DateTime plannedDate;
  final List<DeliveryTaskItem> items;
  final double totalAmount;

  ClientLatestOrder.fromJson(Map<String, dynamic> json)
    : deliveryDocumentId = json['deliveryDocumentId'] as String,
      pointId = json['pointId'] as String,
      createdAt = DateTime.parse(json['createdAt'] as String),
      plannedDate = DateTime.parse(json['plannedDate'] as String),
      totalAmount = double.parse('${json['totalAmount']}'),
      items = (json['items'] as List).map((row) {
        final item = Map<String, dynamic>.from(row as Map);
        return DeliveryTaskItem.fromJson({
          ...item,
          'price': double.parse('${item['price']}'),
        });
      }).toList();
}
