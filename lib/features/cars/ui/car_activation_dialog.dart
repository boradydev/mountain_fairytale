import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/cars/data/cars_number.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';

Future<bool> showCarActivationDialog(
  BuildContext context,
  Car car,
) => ConfirmDialog.show(
  context,
  title: 'Автомобиль неактивен',
  content:
      'Активировать «${car.model} (${formatCarNumber(car.number)})» и выбрать для маршрута?',
  confirmText: 'Активировать и выбрать',
);
