import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_provider.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_meta_panel.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/delivery_document_editor.dart';

class PickupConstructorScreen extends StatelessWidget {
  final String? existingPickupId;
  const PickupConstructorScreen({super.key, this.existingPickupId});
  @override
  Widget build(BuildContext context) {
    final provider = context.read<PickupConstructorProvider>();
    return DeliveryDocumentEditor(
      provider: provider,
      title: 'Самовывоз',
      initialize: () async {
        if (existingPickupId == null) {
          provider.resetForm();
          await provider.loadDirectories();
        } else {
          await provider.loadExistingPickupById(existingPickupId!);
        }
      },
      save: provider.savePickup,
      changeActive: provider.changeDocumentActive,
      metaBuilder: (key) => PickupMetaPanel(formKey: key),
    );
  }
}
