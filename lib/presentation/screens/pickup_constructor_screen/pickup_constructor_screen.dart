import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/providers/pickup_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/common/clients_selection_panel.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/route_points_list.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';


class PickupConstructorScreen extends StatefulWidget {
  final int? existingPickupId;

  const PickupConstructorScreen({super.key, this.existingPickupId});

  @override
  State<PickupConstructorScreen> createState() =>
      _PickupConstructorScreenState();
}

class _PickupConstructorScreenState extends State<PickupConstructorScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pickupProvider = context.read<PickupConstructorProvider>();

      if (widget.existingPickupId != null) {
        // Режим редактирования существующего маршрута
        pickupProvider.loadExistingPickupById(widget.existingPickupId!);
      } else {
        // Режим создания нового маршрута
        pickupProvider.resetForm();
        pickupProvider.loadDirectories();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickupConstructorProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingPickupId != null
              ? 'Просмотр самовывоза'
              : 'Самовывоз',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Итого: '
                '${provider.grandTotal.toStringAsFixed(2)} ₽',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: provider.isLoadingDirectories
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: Row(
          children: [
            // Заменяем PickupMetaPanel на ClientSelectionPanel с фиксированной шириной и стилизацией
            Container(
              width: 360,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
              ),
              padding: const EdgeInsets.all(16),
              child: ClientSelectionPanel(provider: provider),
            ),
            Expanded(
              child: RoutePointsList(
                provider: provider,
              ),
            ),
          ],
        ),
      ),
      // Добавлена кнопка сохранения для экрана самовывоза
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          child: AppPrimaryButton(
            text: provider.isReadOnly
                ? 'Самовывоз заблокирован'
                : 'Сохранить самовывоз',
            // Если режим "Только для чтения", передаем null в onPressed, что автоматически делает кнопку неактивной
            onPressed: provider.isReadOnly
                ? null
                : () async {
              if (_formKey.currentState!.validate()) {
                final success = await provider.savePickup();

                if (!context.mounted) return;

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Самовывоз успешно обновлен'),
                    ),
                  );
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ошибка при сохранении самовывоза'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }
}
