import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/payment_methods/payment_method_abcs.dart';

class PaymentMethodRepositoryImpl implements PaymentMethodRepository {
  final PaymentMethodDataSource dataSource;

  PaymentMethodRepositoryImpl(this.dataSource);

  @override
  Future<List<PaymentMethod>> getAllPaymentMethods({
    bool includeDeactivated = false,
  }) async {
    final list = await dataSource.getAllPaymentMethods(
      includeDeactivated: includeDeactivated,
    );
    return list.map(PaymentMethod.fromJson).toList();
  }

  @override
  Future<PaymentMethod> getPaymentMethodById(String id) async =>
      PaymentMethod.fromJson(await dataSource.getPaymentMethodById(id));

  @override
  Future<PaymentMethod> createPaymentMethod(
    CreatePaymentMethodRequest request,
  ) async => PaymentMethod.fromJson(
    await dataSource.createPaymentMethod(request.toJson()),
  );

  @override
  Future<PaymentMethod> updatePaymentMethod(
    String id,
    UpdatePaymentMethodRequest request,
  ) async => PaymentMethod.fromJson(
    await dataSource.patchPaymentMethod(id, request.toJson()),
  );

  @override
  Future<PaymentMethod?> checkDuplicate(String name) async {
    final json = await dataSource.checkDuplicate(name);
    return json == null ? null : PaymentMethod.fromJson(json);
  }
}
