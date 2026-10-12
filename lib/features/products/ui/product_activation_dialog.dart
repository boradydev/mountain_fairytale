import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/products/data/product_model.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';

Future<bool> showProductActivationDialog(
  BuildContext context,
  Product product,
) => ConfirmDialog.show(
  context,
  title: 'Товар неактивен',
  content: 'Активировать «${product.name}» и выбрать для задания?',
  confirmText: 'Активировать и выбрать',
);
