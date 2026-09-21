import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/datetime_extensions.dart';
import 'package:mountain_fairytale/infra/repos/cars/models/car_model.dart';
import 'package:mountain_fairytale/infra/repos/drivers/models/driver_model.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/common/car_dialog.dart';
import 'package:mountain_fairytale/presentation/screens/common/driver_dialog.dart';
import 'package:mountain_fairytale/presentation/widgets/dropdown_widget.dart';
import 'package:provider/provider.dart';

class RouteMetaPanel extends StatefulWidget {
  final GlobalKey<FormState> formKey;

  const RouteMetaPanel({super.key, required this.formKey});

  @override
  State<RouteMetaPanel> createState() => _RouteMetaPanelState();
}

class _RouteMetaPanelState extends State<RouteMetaPanel> {
  // Метод открытия диалога для водителя
  Future<void> _showDriverDialog(BuildContext context, {Driver? driver}) async {
    await showDialog<void>(
      context: context,
      builder: (context) => DriverDialog(driver: driver),
    );
  }

  // Метод открытия диалога для автомобиля
  Future<void> _showCarDialog(BuildContext context, {Car? car}) async {
    await showDialog<void>(
      context: context,
      builder: (context) => CarDialog(car: car),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteConstructorProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Данные рейса',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text('Дата: ${provider.selectedDate.toFormattedString()}'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: provider.selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null) provider.setDate(picked);
            },
          ),
          const SizedBox(height: 12),

          // Водитель
          AppDropdown<Driver>(
            label: 'Водитель *',
            items: provider.drivers,
            value: provider.selectedDriver,
            itemLabelBuilder: (driver) => driver.name,
            onChanged: provider.selectDriver,
            validator: (value) => value == null ? 'Выберите водителя' : null,
            onAdd: () => _showDriverDialog(context),
            onEdit: provider.selectedDriver == null
                ? null
                : () => _showDriverDialog(
                    context,
                    driver: provider.selectedDriver,
                  ),
          ),

          const SizedBox(height: 12),

          // Автомобиль
          AppDropdown<Car>(
            label: 'Автомобиль *',
            items: provider.cars,
            value: provider.selectedCar,
            itemLabelBuilder: (car) => '${car.model} (${car.number})',
            onChanged: provider.selectCar,
            validator: (value) => value == null ? 'Выберите автомобиль' : null,
            onAdd: () => _showCarDialog(context),
            onEdit: provider.selectedCar == null
                ? null
                : () => _showCarDialog(context, car: provider.selectedCar),
          ),

          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Километраж выезда (км)',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            initialValue: provider.startMileage.toString(),
            onChanged: (value) {
              provider.startMileage = double.tryParse(value) ?? 0.0;
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите километраж выезда';
              }

              final mileage = double.tryParse(value);

              if (mileage == null) {
                return 'Введите корректный километраж';
              }

              if (mileage < 0) {
                return 'Километраж не может быть отрицательным';
              }

              return null;
            },
          ),

          const SizedBox(height: 12),

          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Километраж заезда (км)',
              hintText: 'Заполняется после возвращения',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            initialValue: provider.endMileage?.toString() ?? '',
            onChanged: (value) {
              final text = value.trim();

              provider.endMileage = text.isEmpty ? null : double.tryParse(text);
            },
            validator: (value) {
              // Поле необязательное.
              if (value == null || value.trim().isEmpty) {
                return null;
              }

              final mileage = double.tryParse(value);

              if (mileage == null) {
                return 'Введите корректный километраж';
              }

              if (mileage < 0) {
                return 'Километраж не может быть отрицательным';
              }

              if (mileage < provider.startMileage) {
                return 'Не может быть меньше километража выезда';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }
}
