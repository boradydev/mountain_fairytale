import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/providers/pickup_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/pickup_constructor_screen/pickup_meta_panel.dart';
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
            PickupMetaPanel(formKey: _formKey,),
            Expanded(
              child: RoutePointsList(
                provider: provider,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

