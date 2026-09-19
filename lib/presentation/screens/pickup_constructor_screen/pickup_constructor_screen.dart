import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/app_notify.dart';
import 'package:mountain_fairytale/presentation/providers/pickup_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/common/clients_selection_panel.dart';
import 'package:mountain_fairytale/presentation/screens/pickup_constructor_screen/pickup_meta_panel.dart';
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
                'Итого по самовывозу: ${provider.grandTotal.toStringAsFixed(
                    2)} ₽',
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ЛЕВАЯ ЧАСТЬ: Фиксированная колонка панелей
            SizedBox(
              width: 360,
              child: Column(
                children: [
                  PickupMetaPanel(formKey: _formKey),
                  const Divider(height: 1),
                  Expanded(
                    child: ClientSelectionPanel(
                      provider: context.watch<PickupConstructorProvider>(),
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),

            // ПРАВАЯ ЧАСТЬ: Полностью отведена под список точек маршрута
            Expanded(
              child: RoutePointsList(
                provider: context.watch<PickupConstructorProvider>(),
              ),
            ),
          ],
        ),
      ),
      // Кнопки управления теперь железно зафиксированы внизу экрана
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colorScheme
                .outlineVariant, width: 1),
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Padding(
          // Левый отступ 361px (360px ширина панели + 1px разделитель)
          // идеально центрирует кнопки относительно правого списка точек
          padding: const EdgeInsets.only(left: 361.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              // Кнопка Отмена
              AppSecondaryButton(
                text: 'Отмена',
                onPressed: () {
                  Navigator.pop(context, false);
                },
              ),
              const SizedBox(width: 16),
              // Кнопка Сохранить
              AppPrimaryButton(
                text: provider.isReadOnly
                    ? 'Самовывоз заблокирован'
                    : 'Сохранить самовывоз',
                onPressed: provider.isReadOnly
                    ? null
                    : () async {
                  if (_formKey.currentState!.validate()) {
                    final success = await provider.savePickup();

                    if (!context.mounted) return;

                    if (success) {
                      AppNotify.show(
                          context, 'Самовывоз успешно обновлен');
                      Navigator.pop(context, true);
                    } else {
                      AppNotify.show(
                          context, 'Ошибка при сохранении самовывоза',
                          isError: true);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
