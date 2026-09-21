import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/datetime_extensions.dart';
import 'package:mountain_fairytale/presentation/providers/pickup_constructor_provider.dart';
import 'package:provider/provider.dart';

class PickupMetaPanel extends StatefulWidget {
  final GlobalKey<FormState> formKey;

  const PickupMetaPanel({super.key, required this.formKey});

  @override
  State<PickupMetaPanel> createState() => _PickupMetaPanelState();
}

class _PickupMetaPanelState extends State<PickupMetaPanel> {
  final TextEditingController _clientSearchController = TextEditingController();

  @override
  void dispose() {
    _clientSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickupConstructorProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Данные самовывоза',
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
        ],
      ),
    );
  }
}
