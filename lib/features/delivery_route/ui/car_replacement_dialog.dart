import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/cars/data/cars_number.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';

Future<({double? mileage})?> showCarReplacementDialog(
  BuildContext context,
  Car car,
  DeliveryRouteSheet sheet,
) async {
  double? correction;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _CarReplacementDialog(
      car: car,
      sheet: sheet,
      onConfirm: (value) => correction = value,
    ),
  );
  return confirmed == true ? (mileage: correction) : null;
}

class _CarReplacementDialog extends StatefulWidget {
  final Car car;
  final DeliveryRouteSheet sheet;
  final ValueChanged<double?> onConfirm;
  const _CarReplacementDialog({
    required this.car,
    required this.sheet,
    required this.onConfirm,
  });

  @override
  State<_CarReplacementDialog> createState() => _CarReplacementDialogState();
}

class _CarReplacementDialogState extends State<_CarReplacementDialog> {
  final form = GlobalKey<FormState>();
  final controller = TextEditingController();
  double? get mileage =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConfirmDialog(
    maxWidth: 520,
    title: 'Сменить автомобиль?',
    content:
        'Пробег автомобиля уже обновлён по показаниям заезда.\n\n'
        '${widget.car.model} · ${formatCarNumber(widget.car.number)}\n'
        'Текущий пробег: ${widget.car.currentMileage} км\n'
        'В этой доставке: ${widget.sheet.startMileage} → ${widget.sheet.endMileage} км.\n\n'
        'Перед заменой проверьте пробег этой машины. Укажите актуальный или оставьте поле пустым, чтобы не менять его.\n\n'
        'Для новой машины пробег заезда будет очищен. Изменения применятся при сохранении доставки.',
    confirmText: 'Продолжить замену',
    details: Form(
      key: form,
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Актуальный пробег прежнего автомобиля, км',
          hintText: 'Необязательно',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return null;
          if (mileage == null || !mileage!.isFinite || mileage! < 0) {
            return 'Введите корректный неотрицательный пробег';
          }
          return null;
        },
      ),
    ),
    validate: () {
      if (!(form.currentState?.validate() ?? false)) return false;
      widget.onConfirm(mileage);
      return true;
    },
  );
}
