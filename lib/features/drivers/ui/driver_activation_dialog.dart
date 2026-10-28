import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';

Future<bool> showDriverActivationDialog(
  BuildContext context,
  Driver driver, {
  bool selectAfterActivation = true,
}) => ConfirmDialog.show(
  context,
  title: 'Водитель неактивен',
  content: selectAfterActivation
      ? 'Активировать «${driver.name}» и выбрать для маршрута?'
      : 'Активировать «${driver.name}»?',
  confirmText: selectAfterActivation
      ? 'Активировать и выбрать'
      : 'Активировать',
);
