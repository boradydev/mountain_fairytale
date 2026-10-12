import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/features/payment_methods/payment_method_abcs.dart';

class DemoPaymentMethodDataSource implements PaymentMethodDataSource {
  final AssetBundle _assetBundle;
  List<Map<String, dynamic>>? _paymentMethodsCache;

  DemoPaymentMethodDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  Future<void> _load() async {
    if (_paymentMethodsCache != null) return;
    await Future.delayed(const Duration(milliseconds: 40));
    final jsonString = await _assetBundle.loadString(
      'assets/demo/payment_methods/payment_methods_data.json',
    );
    final legacyPaymentMethods = List<Map<String, dynamic>>.from(
      jsonDecode(jsonString),
    );
    _paymentMethodsCache = legacyPaymentMethods.map((paymentMethod) {
      return {
        'paymentMethodId':
            paymentMethod['paymentMethodId']?.toString() ??
            paymentMethod['id'].toString(),
        'name': paymentMethod['name'],
        'createdAt': DateTime(2026).toIso8601String(),
        'isActive': true,
      };
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAllPaymentMethods({
    bool includeDeactivated = false,
  }) async {
    await _load();
    return _paymentMethodsCache!
        .where(
          (paymentMethod) =>
              includeDeactivated || paymentMethod['isActive'] == true,
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getPaymentMethodById(String id) async {
    await _load();
    return Map<String, dynamic>.from(
      _paymentMethodsCache!.firstWhere(
        (paymentMethod) => paymentMethod['paymentMethodId'] == id,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> createPaymentMethod(
    Map<String, dynamic> json,
  ) async {
    await _load();
    final paymentMethod = {
      ...json,
      'paymentMethodId': 'demo-${DateTime.now().microsecondsSinceEpoch}',
      'createdAt': DateTime.now().toIso8601String(),
      'isActive': true,
    };
    _paymentMethodsCache!.insert(0, paymentMethod);
    return Map<String, dynamic>.from(paymentMethod);
  }

  @override
  Future<Map<String, dynamic>> patchPaymentMethod(
    String id,
    Map<String, dynamic> json,
  ) async {
    await _load();
    final index = _paymentMethodsCache!.indexWhere(
      (paymentMethod) => paymentMethod['paymentMethodId'] == id,
    );
    if (index == -1) throw Exception('PaymentMethod not found');
    _paymentMethodsCache![index] = {..._paymentMethodsCache![index], ...json};
    return Map<String, dynamic>.from(_paymentMethodsCache![index]);
  }

  @override
  Future<Map<String, dynamic>?> checkDuplicate(String name) async {
    await _load();
    for (final paymentMethod in _paymentMethodsCache!) {
      if ((paymentMethod['name'] as String).toLowerCase() ==
          name.toLowerCase()) {
        return Map<String, dynamic>.from(paymentMethod);
      }
    }
    return null;
  }
}
