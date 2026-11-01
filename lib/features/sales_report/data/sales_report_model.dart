class SalesReportProduct {
  final String productId;
  final String productName;
  final int quantity;
  final String amount;

  const SalesReportProduct({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.amount,
  });

  factory SalesReportProduct.fromJson(Map<String, dynamic> json) =>
      SalesReportProduct(
        productId: json['productId'] as String,
        productName: json['productName'] as String,
        quantity: (json['quantity'] as num).toInt(),
        amount: json['amount'] as String,
      );
}

class SalesReportPaymentMethod {
  final String? paymentMethodId;
  final String paymentMethodName;
  final bool? isActive;
  final int totalQuantity;
  final String totalAmount;
  final List<SalesReportProduct> products;

  const SalesReportPaymentMethod({
    required this.paymentMethodId,
    required this.paymentMethodName,
    required this.isActive,
    required this.totalQuantity,
    required this.totalAmount,
    required this.products,
  });

  factory SalesReportPaymentMethod.fromJson(Map<String, dynamic> json) =>
      SalesReportPaymentMethod(
        paymentMethodId: json['paymentMethodId'] as String?,
        paymentMethodName: json['paymentMethodName'] as String,
        isActive: json['isActive'] as bool?,
        totalQuantity: (json['totalQuantity'] as num).toInt(),
        totalAmount: json['totalAmount'] as String,
        products: (json['products'] as List)
            .map(
              (row) => SalesReportProduct.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList(),
      );
}

class SalesReport {
  final DateTime dateFrom;
  final DateTime dateTo;
  final int totalQuantity;
  final String totalAmount;
  final List<SalesReportPaymentMethod> paymentMethods;

  const SalesReport({
    required this.dateFrom,
    required this.dateTo,
    required this.totalQuantity,
    required this.totalAmount,
    required this.paymentMethods,
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) => SalesReport(
    dateFrom: DateTime.parse(json['dateFrom'] as String),
    dateTo: DateTime.parse(json['dateTo'] as String),
    totalQuantity: (json['totalQuantity'] as num).toInt(),
    totalAmount: json['totalAmount'] as String,
    paymentMethods: (json['paymentMethods'] as List)
        .map(
          (row) => SalesReportPaymentMethod.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(),
  );
}
