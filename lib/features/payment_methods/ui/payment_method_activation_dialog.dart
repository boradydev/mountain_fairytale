import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';

Future<bool> showPaymentMethodActivationDialog(
  BuildContext context,
  PaymentMethod paymentMethod, {
  bool selectAfterActivation = true,
}) => ConfirmDialog.show(
  context,
  title: 'Способ оплаты неактивен',
  content: selectAfterActivation
      ? 'Активировать «${paymentMethod.name}» и выбрать для клиента?'
      : 'Активировать «${paymentMethod.name}»?',
  confirmText: selectAfterActivation
      ? 'Активировать и выбрать'
      : 'Активировать',
);
