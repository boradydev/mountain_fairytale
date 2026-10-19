import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/datetime_extensions.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/cars/data/cars_number.dart';
import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/cars/ui/car_dialog.dart';
import 'package:mountain_fairytale/features/cars/ui/car_activation_dialog.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/car_replacement_dialog.dart';
import 'package:mountain_fairytale/features/drivers/ui/driver_dialog.dart';
import 'package:mountain_fairytale/features/drivers/ui/driver_activation_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/dropdown_widget.dart';
import 'package:provider/provider.dart';

class RouteMetaPanel extends StatefulWidget {
  final GlobalKey<FormState> formKey;

  const RouteMetaPanel({super.key, required this.formKey});

  @override
  State<RouteMetaPanel> createState() => _RouteMetaPanelState();
}

class _RouteMetaPanelState extends State<RouteMetaPanel> {
  int _driverSelectionVersion = 0;
  int _carSelectionVersion = 0;
  final _driverFocusNode = FocusNode();
  final _carFocusNode = FocusNode();
  RouteConstructorProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<RouteConstructorProvider>();
    _provider!.confirmCarReplacement = (car, sheet) =>
        showCarReplacementDialog(context, car, sheet);
  }

  @override
  void dispose() {
    _provider?.confirmCarReplacement = null;
    _driverFocusNode.dispose();
    _carFocusNode.dispose();
    super.dispose();
  }

  Future<void> _toggleInactiveDrivers(bool value) async {
    // Keep focus on the related field before the eye becomes unavailable.
    _driverFocusNode.requestFocus();
    await context.read<RouteConstructorProvider>().toggleInactiveDrivers(value);
  }

  Future<void> _toggleInactiveCars(bool value) async {
    _carFocusNode.requestFocus();
    await context.read<RouteConstructorProvider>().toggleInactiveCars(value);
  }

  Future<void> _selectDriver(Driver? driver) async {
    final provider = context.read<RouteConstructorProvider>();
    if (driver == null || driver.isActive) {
      provider.selectDriver(driver);
      return;
    }
    final confirmed = await showDriverActivationDialog(context, driver);
    if (!mounted) return;
    if (confirmed) {
      final success = await provider.activateAndSelectDriver(driver);
      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось активировать водителя. Повторите попытку.',
            ),
          ),
        );
      }
    }
    setState(() => _driverSelectionVersion++);
  }

  Future<void> _selectCar(Car? car) async {
    final provider = context.read<RouteConstructorProvider>();
    if (car == null || car.isActive) {
      await provider.selectCar(car);
      if (mounted) setState(() => _carSelectionVersion++);
      return;
    }
    final confirmed = await showCarActivationDialog(context, car);
    if (!mounted) return;
    if (confirmed) {
      final success = await provider.activateAndSelectCar(car);
      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось активировать автомобиль. Повторите попытку.',
            ),
          ),
        );
      }
    }
    setState(() => _carSelectionVersion++);
  }

  // Метод открытия диалога для водителя
  Future<void> _showDriverDialog(BuildContext context, {Driver? driver}) async {
    Driver? openAfter;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => DriverDialog(
        driver: driver,
        onOpenDriver: (duplicate) {
          openAfter = duplicate;
          Navigator.of(dialogContext).pop();
        },
      ),
    );
    if (openAfter != null && context.mounted) {
      await _showDriverDialog(context, driver: openAfter);
    }
  }

  // Метод открытия диалога для автомобиля
  Future<void> _showCarDialog(BuildContext context, {Car? car}) async {
    Car? openAfter;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => CarDialog(
        car: car,
        onOpenCar: (duplicate) {
          openAfter = duplicate;
          Navigator.of(dialogContext).pop();
        },
      ),
    );
    if (openAfter != null && context.mounted) {
      await _showCarDialog(context, car: openAfter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteConstructorProvider>();

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
                firstDate: DateTime(1900),
                lastDate: DateTime(2200),
              );
              if (picked != null) provider.setDate(picked);
            },
          ),
          const SizedBox(height: 12),

          // Водитель
          AppDropdown<Driver>(
            isLoading: provider.isLoadingDrivers,
            key: ValueKey('driver-$_driverSelectionVersion'),
            label: 'Водитель *',
            focusNode: _driverFocusNode,
            showEdit: true,
            showAdd: true,
            editBeforeAdd: true,
            showInactiveToggle: true,
            includeInactive: provider.showInactiveDrivers,
            onIncludeInactiveChanged: provider.isLoadingDrivers
                ? null
                : _toggleInactiveDrivers,
            items: provider.drivers,
            value: provider.selectedDriver,
            itemLabelBuilder: (driver) =>
                '${driver.name}${driver.isActive ? '' : ' — Неактивен'}',
            itemBuilder: (driver) => Text(
              driver.isActive ? driver.name : '${driver.name} — Неактивен',
              overflow: TextOverflow.ellipsis,
              style: driver.isActive
                  ? null
                  : TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
            ),
            onChanged: _selectDriver,
            validator: (value) => value == null
                ? 'Выберите водителя'
                : !value.isActive && !provider.assignmentUnchanged
                ? 'Назначенный водитель неактивен'
                : null,
            onAdd: () => _showDriverDialog(context),
            onEdit: provider.selectedDriver == null
                ? null
                : () => _showDriverDialog(
                    context,
                    driver: provider.selectedDriver,
                  ),
          ),

          if (provider.selectedDriver == null && provider.driverName.isNotEmpty)
            Text(
              'В маршрутном листе: ${provider.driverName}. Выберите активного водителя для продолжения.',
            ),
          if (provider.driverError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    provider.driverError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: provider.loadDrivers,
                  child: const Text('Повторить'),
                ),
              ],
            ),

          const SizedBox(height: 12),

          // Автомобиль
          AppDropdown<Car>(
            isLoading: provider.isLoadingCars,
            key: ValueKey(
              'car-$_carSelectionVersion-${provider.selectedCar?.id}',
            ),
            label: 'Автомобиль *',
            focusNode: _carFocusNode,
            showEdit: true,
            showAdd: true,
            editBeforeAdd: true,
            showInactiveToggle: true,
            includeInactive: provider.showInactiveCars,
            onIncludeInactiveChanged: provider.isLoadingCars
                ? null
                : _toggleInactiveCars,
            items: provider.cars,
            value: provider.selectedCar,
            itemLabelBuilder: (car) =>
                '${car.model} (${formatCarNumber(car.number)})${car.isActive ? '' : ' — Неактивен'}',
            itemBuilder: (car) => Text(
              car.isActive
                  ? '${car.model} (${formatCarNumber(car.number)})'
                  : '${car.model} (${formatCarNumber(car.number)}) — Неактивен',
              overflow: TextOverflow.ellipsis,
              style: car.isActive
                  ? null
                  : TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
            ),
            onChanged: _selectCar,
            validator: (value) => value == null
                ? 'Выберите автомобиль'
                : !value.isActive && !provider.assignmentUnchanged
                ? 'Назначенный автомобиль неактивен'
                : null,
            onAdd: () => _showCarDialog(context),
            onEdit: provider.selectedCar == null
                ? null
                : () => _showCarDialog(context, car: provider.selectedCar),
          ),

          if (provider.carError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    provider.carError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: provider.loadCars,
                  child: const Text('Повторить'),
                ),
              ],
            ),

          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('start-${provider.mileageRevision}'),
            decoration: const InputDecoration(
              labelText: 'Километраж выезда (км)',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            initialValue: provider.startMileage.toString(),
            onChanged: (value) {
              provider.startMileage =
                  double.tryParse(value.trim().replaceAll(',', '.')) ??
                  double.nan;
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите километраж выезда';
              }

              final mileage = double.tryParse(
                value.trim().replaceAll(',', '.'),
              );

              if (mileage == null || !mileage.isFinite) {
                return 'Введите корректный километраж';
              }

              if (mileage < 0) {
                return 'Километраж не может быть отрицательным';
              }

              return null;
            },
          ),

          if (provider.selectedCar != null &&
              provider.endMileage == null &&
              provider.startMileage != provider.selectedCar!.currentMileage)
            TextButton(
              onPressed: provider.useCurrentMileage,
              child: Text(
                'Подставить текущий пробег: ${provider.selectedCar!.currentMileage} км',
              ),
            ),

          const SizedBox(height: 12),

          TextFormField(
            key: ValueKey('end-${provider.mileageRevision}'),
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
                  : double.tryParse(text.replaceAll(',', '.'));
            },
            validator: (value) {
              // Поле необязательное.
              if (value == null || value.trim().isEmpty) {
                return null;
              }

              final mileage = double.tryParse(
                value.trim().replaceAll(',', '.'),
              );

              if (mileage == null || !mileage.isFinite) {
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
          const SizedBox(height: 12),
          Text(
            provider.distance == null
                ? 'Пробег доставки ещё не указан'
                : 'Пробег доставки: ${provider.distance} км',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
