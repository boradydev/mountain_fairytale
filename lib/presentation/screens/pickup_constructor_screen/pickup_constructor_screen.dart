import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/app_notify.dart';
import 'package:mountain_fairytale/presentation/providers/pickup_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/route_points_list.dart';
import 'package:provider/provider.dart';

class PickupConstructorScreen extends StatefulWidget {
  final int? existingPickupId;

  const PickupConstructorScreen({super.key, this.existingPickupId});

  @override
  State<PickupConstructorScreen> createState() =>
      _PickupConstructorScreenState();
}

class _PickupConstructorScreenState extends State<PickupConstructorScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PickupConstructorProvider>();

      if (widget.existingPickupId != null) {
        provider.loadExistingPickupById(widget.existingPickupId!);
      } else {
        provider.resetForm();
        provider.loadDirectories();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickupConstructorProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingPickupId != null ? 'Просмотр самовывоза' : 'Самовывоз',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Сохранить',
            onPressed: provider.isReadOnly
                ? null
                : () async {
                    final success = await provider.savePickup();

                    if (!context.mounted) {
                      return;
                    }

                    if (success) {
                      Navigator.of(context).pop(true);
                    } else {
                      AppNotify.show(
                        context,
                        'Не удалось сохранить самовывоз',
                        isError: true,
                      );
                    }
                  },
          ),
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
          : Row(
              children: [
                const _PickupMetaPanel(),
                Expanded(child: RoutePointsList(
                  provider: context.watch<PickupConstructorProvider>(),
                )),
              ],
            ),
    );
  }
}

class _PickupMetaPanel extends StatelessWidget {
  const _PickupMetaPanel();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickupConstructorProvider>();

    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 300,
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront_outlined),
                  const SizedBox(width: 8),
                  Text(
                    'Самовывоз',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Дата', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              InkWell(
                onTap: provider.isReadOnly
                    ? null
                    : () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: provider.selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (selected != null) {
                          provider.setDate(selected);
                        }
                      },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(_formatDate(provider.selectedDate)),
                ),
              ),
              const SizedBox(height: 24),
              Text('Клиентов: ${provider.points.length}'),
              const SizedBox(height: 8),
              Text(
                'Позиций: ${provider.points.fold<int>(0, (sum, point) => sum + point.items.length)}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}
