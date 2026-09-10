import 'package:mountain_fairytale/infra/repos/payment_methods/models/payment_method_model.dart';

abstract interface class PaymentMethodDataSource {
  Future<List<Map<String, dynamic>>> getAllPaymentMethods();

  Future<Map<String, dynamic>> getPaymentMethodById(int id);

  Future<Map<String, dynamic>> createPaymentMethod(Map<String, dynamic> json);

  Future<Map<String, dynamic>> patchPaymentMethod(
    int id,
    Map<String, dynamic> json,
  );

  Future<void> deletePaymentMethod(int id);
}

abstract interface class PaymentMethodRepository {
  Future<List<PaymentMethod>> getAllPaymentMethods();

  Future<PaymentMethod> getPaymentMethodById(int id);

  Future<PaymentMethod> createPaymentMethod(CreatePaymentMethodRequest request);

  Future<PaymentMethod> updatePaymentMethod(
    int id,
    UpdatePaymentMethodRequest request,
  );

  Future<void> deletePaymentMethod(int id);
}
