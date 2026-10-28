import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/products/data/product_model.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';

Future<bool> showProductActivationDialog(
  BuildContext context,
  Product product, {
  bool selectAfterActivation = true,
}) => ConfirmDialog.show(
  context,
  title: 'Товар неактивен',
  content: selectAfterActivation
      ? 'Активировать «${product.name}» и выбрать для задания?'
      : 'Активировать «${product.name}»?',
  confirmText: selectAfterActivation
      ? 'Активировать и выбрать'
      : 'Активировать',
);
