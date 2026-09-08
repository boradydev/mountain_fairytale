import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/datetime_extensions.dart';
import 'package:mountain_fairytale/infrastructure/repos/cars/models/car_model.dart';
import 'package:mountain_fairytale/infrastructure/repos/drivers/models/driver_model.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class FlightMetaPanel extends StatefulWidget {
  final GlobalKey<FormState> formKey;

  const FlightMetaPanel({super.key, required this.formKey});

  @override
  State<FlightMetaPanel> createState() => _FlightMetaPanelState();
}

class _FlightMetaPanelState extends State<FlightMetaPanel> {
  final TextEditingController _clientSearchController =
  TextEditingController();

  @override
  void dispose() {
    _clientSearchController.dispose();
    super.dispose();
  }

  // Метод открытия диалога для водителя
  Future<void> _showAddDriverDialog(BuildContext context,
      RouteConstructorProvider provider,) async {
    final name = await showDialog<String>(
      context: context,
      // ВАЖНО: Если _AddDriverDialog лежит в другом файле,
      // уберите нижнее подчеркивание и импортируйте его.
      builder: (context) => const _AddDriverDialog(),
    );

    if (name == null || name
        .trim()
        .isEmpty) return;
    await provider.addDriver(name);
  }

  // Метод открытия диалога для автомобиля
  Future<void> _showAddCarDialog(BuildContext context,
      RouteConstructorProvider provider,) async {
    final result = await showDialog<({String model, String number})>(
      context: context,
      // ВАЖНО: Если _AddCarDialog лежит в другом файле,
      // уберите нижнее подчеркивание и импортируйте его.
      builder: (context) => const _AddCarDialog(),
    );

    if (result == null) return;
    await provider.addCar(
      model: result.model,
      number: result.number,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteConstructorProvider>();
    final clientProvider = context.watch<ClientsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final searchQuery = _clientSearchController.text.trim().toLowerCase();

    final filteredClients = clientProvider.clients.where((client) {
      if (searchQuery.isEmpty) return true;

      return client.name.toLowerCase().contains(searchQuery) ||
          client.address.toLowerCase().contains(searchQuery) ||
          client.phone.toLowerCase().contains(searchQuery);
    }).toList();

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
                onPressed: () => _showAddDriverDialog(context, provider),
                icon: const Icon(Icons.add),
                tooltip: 'Добавить водителя',
              ),
            ],
          ),

          DropdownButtonFormField<Driver>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            value: provider.selectedDriver,
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
                onPressed: () => _showAddCarDialog(context, provider),
                icon: const Icon(Icons.add),
                tooltip: 'Добавить автомобиль',
              ),
            ],
          ),

          DropdownButtonFormField<Car>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            value: provider.selectedCar,
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
            keyboardType: TextInputType.number,
            initialValue: provider.startMileage.toString(),
            onChanged: (v) => provider.startMileage = double.tryParse(v) ?? 0.0,
          ),
          const Divider(height: 32),
          const Text(
            '2. Быстрое добавление клиента',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _clientSearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Имя, адрес или телефон',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _clientSearchController.text.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _clientSearchController.clear();
                  setState(() {});
                },
              ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              itemCount: filteredClients.length,
              itemBuilder: (context, idx) {
                final client = filteredClients[idx];

                final isAlreadyAdded = provider.points.any(
                      (point) => point.clientId == client.id,
                );

                return ListTile(
                  title: Text(
                    client.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isAlreadyAdded
                          ? colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    client.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isAlreadyAdded
                          ? colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  trailing: isAlreadyAdded
                      ? const Icon(
                    Icons.check_circle,
                    color: Colors.grey,
                  )
                      : const Icon(
                    Icons.add_circle,
                    color: Colors.green,
                  ),
                  dense: true,
                  enabled: !isAlreadyAdded,
                  onTap: isAlreadyAdded
                      ? null
                      : () => provider.addClientPoint(client),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppPrimaryButton(
              text: 'Сохранить маршрут',
              onPressed: () async {
                if (widget.formKey.currentState!.validate()) {
                  final success = await provider.saveRoute();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Маршрутный лист сохранен!'
                              : 'Ошибка заполнения',
                        ),
                      ),
                    );
                    if (success) Navigator.pop(context);
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

class _AddDriverDialog extends StatefulWidget {
  const _AddDriverDialog();

  @override
  State<_AddDriverDialog> createState() => _AddDriverDialogState();
}

class _AddDriverDialogState extends State<_AddDriverDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить водителя'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'ФИО',
          hintText: 'Иванов Иван Иванович',
          border: OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}

class _AddCarDialog extends StatefulWidget {
  const _AddCarDialog();

  @override
  State<_AddCarDialog> createState() => _AddCarDialogState();
}

class _AddCarDialogState extends State<_AddCarDialog> {
  late final TextEditingController _modelController;
  late final TextEditingController _numberController;

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController();
    _numberController = TextEditingController();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить автомобиль'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _modelController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Модель',
              hintText: 'Газель',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _numberController,
            decoration: const InputDecoration(
              labelText: 'Номер',
              hintText: 'А123ББ',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              Navigator.of(context).pop((
              model: _modelController.text,
              number: _numberController.text,
              ));
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop((
            model: _modelController.text,
            number: _numberController.text,
            ));
          },
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}