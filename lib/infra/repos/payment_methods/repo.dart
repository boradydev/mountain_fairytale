import 'package:mountain_fairytale/presentation/providers/abcs/repos/payment_method_abcs.dart';
import 'package:mountain_fairytale/infra/repos/payment_methods/models/payment_method_model.dart';

class PaymentMethodRepositoryImpl implements PaymentMethodRepository {
  final PaymentMethodDataSource dataSource;

  PaymentMethodRepositoryImpl(this.dataSource);

  @override
  Future<List<PaymentMethod>> getAllPaymentMethods() async {
    final list = await dataSource.getAllPaymentMethods();
    return list.map(PaymentMethod.fromJson).toList();
  }

  @override
  Future<PaymentMethod> getPaymentMethodById(int id) async {
    final json = await dataSource.getPaymentMethodById(id);
    return PaymentMethod.fromJson(json);
  }

  @override
  Future<PaymentMethod> createPaymentMethod(
    CreatePaymentMethodRequest request,
  ) async {
    final json = await dataSource.createPaymentMethod(request.toJson());
    return PaymentMethod.fromJson(json);
  }

  @override
  Future<PaymentMethod> updatePaymentMethod(
    int id,
    UpdatePaymentMethodRequest request,
  ) async {
    final json = await dataSource.patchPaymentMethod(id, request.toJson());
    return PaymentMethod.fromJson(json);
  }

  @override
  Future<void> deletePaymentMethod(int id) async {
    await dataSource.deletePaymentMethod(id);
  }
}
