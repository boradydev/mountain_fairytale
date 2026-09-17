import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/datetime_extensions.dart';
import 'package:mountain_fairytale/infra/app_notify.dart';
import 'package:mountain_fairytale/infra/repos/cars/models/car_model.dart';
import 'package:mountain_fairytale/infra/repos/drivers/models/driver_model.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/common/clients_selection_panel.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/car_dialog.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/driver_dialog.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class FlightMetaPanel extends StatefulWidget {
  final GlobalKey<FormState> formKey;

  const FlightMetaPanel({super.key, required this.formKey});

  @override
  State<FlightMetaPanel> createState() => _FlightMetaPanelState();
}

class _FlightMetaPanelState extends State<FlightMetaPanel> {
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
      width: 360,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
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
          // Водитель
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Водитель *',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showDriverDialog(context),
                icon: const Icon(Icons.add),
                tooltip: 'Добавить водителя',
              ),
              IconButton(
                // Кнопка активна только когда водитель выбран в дропдауне
                onPressed: provider.selectedDriver != null
                    ? () =>
                    _showDriverDialog(context, driver: provider.selectedDriver)
                    : null,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Редактировать выбранного водителя',
              ),
            ],
          ),

          DropdownButtonFormField<Driver>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            initialValue: provider.selectedDriver,
            // Меняем на value, чтобы сброс в null мгновенно очищал поле
            items: provider.drivers.map((driver) {
              return DropdownMenuItem<Driver>(
                value: driver,
                child: Text(driver.name),
              );
            }).toList(),
            onChanged: provider.selectDriver,
            validator: (value) =>
            value == null ? 'Выберите водителя' : null,
          ),

          const SizedBox(height: 12),

          // Автомобиль
          // Автомобиль
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Автомобиль *',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showCarDialog(context),
                icon: const Icon(Icons.add),
                tooltip: 'Добавить автомобиль',
              ),
              IconButton(
                // Активна только если машина выбрана
                onPressed: provider.selectedCar != null
                    ? () => _showCarDialog(context, car: provider.selectedCar)
                    : null,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Редактировать выбранный автомобиль',
              ),
            ],
          ),

          DropdownButtonFormField<Car>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            initialValue: provider.selectedCar,
            // Используем value для реактивного сброса
            items: provider.cars.map((car) {
              return DropdownMenuItem<Car>(
                value: car,
                child: Text('${car.model} (${car.number})'),
              );
            }).toList(),
            onChanged: provider.selectCar,
            validator: (value) =>
            value == null ? 'Выберите автомобиль' : null,
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
              if (value == null || value
                  .trim()
                  .isEmpty) {
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

              provider.endMileage = text.isEmpty
                  ? null
                  : double.tryParse(text);
            },
            validator: (value) {
              // Поле необязательное.
              if (value == null || value
                  .trim()
                  .isEmpty) {
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
          const Divider(height: 32),
          const SizedBox(height: 8),

          Expanded(
            child: ClientSelectionPanel(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppPrimaryButton(
              text: provider.isReadOnly
                  ? 'Маршрут заблокирован'
                  : 'Сохранить маршрут',
              // Если режим "Только для чтения", передаем null в onPressed, что автоматически делает кнопку неактивной
              onPressed: provider.isReadOnly
                  ? null
                  : () async {
                if (widget.formKey.currentState!.validate()) {
                  final success = await provider.saveRoute();

                  if (!context.mounted) return;

                  if (success) {
                    AppNotify.show(
                      context,
                      'Маршрутный лист успешно обновлен',
                    );
                    Navigator.pop(context, true);
                  } else {
                    AppNotify.show(
                      context,
                      'Ошибка при сохранении маршрута',
                      isError: true,
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
