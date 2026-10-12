import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';

abstract interface class PaymentMethodDataSource {
  Future<List<Map<String, dynamic>>> getAllPaymentMethods({
    bool includeDeactivated = false,
  });

  Future<Map<String, dynamic>> getPaymentMethodById(String id);

  Future<Map<String, dynamic>> createPaymentMethod(Map<String, dynamic> json);

  Future<Map<String, dynamic>> patchPaymentMethod(
    String id,
    Map<String, dynamic> json,
  );

  Future<Map<String, dynamic>?> checkDuplicate(String name);
}

abstract interface class PaymentMethodRepository {
  Future<List<PaymentMethod>> getAllPaymentMethods({
    bool includeDeactivated = false,
  });

  Future<PaymentMethod> getPaymentMethodById(String id);

  Future<PaymentMethod> createPaymentMethod(CreatePaymentMethodRequest request);

  Future<PaymentMethod> updatePaymentMethod(
    String id,
    UpdatePaymentMethodRequest request,
  );

  Future<PaymentMethod?> checkDuplicate(String name);
}
